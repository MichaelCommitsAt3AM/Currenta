// supabase/functions/ingest-news/index.ts
// Supabase Edge Function — ingests an RSS feed, summarizes with the configured
// LLM, deduplicates via pgvector cosine similarity, and persists to PostgreSQL.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ── Environment ───────────────────────────────────────────────────
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const LLM_PROVIDER = Deno.env.get("LLM_PROVIDER") ?? "local"; // local | gemini | groq
const RAW_LOCAL_LLM_BASE_URL =
  Deno.env.get("LOCAL_LLM_BASE_URL") ?? "http://localhost:11434/v1";

// Ensure the URL ends with /v1 for OpenAI compatibility
const LOCAL_LLM_BASE_URL = RAW_LOCAL_LLM_BASE_URL.replace(/\/+$/, "").endsWith("/v1")
  ? RAW_LOCAL_LLM_BASE_URL.replace(/\/+$/, "")
  : `${RAW_LOCAL_LLM_BASE_URL.replace(/\/+$/, "")}/v1`;

const LOCAL_LLM_MODEL = Deno.env.get("LOCAL_LLM_MODEL") ?? "llama3.1";
// Dedicated embedding model — smaller, faster, 768 dims (fits pgvector IVFFlat).
const LOCAL_EMBED_MODEL = Deno.env.get("LOCAL_EMBED_MODEL") ?? "nomic-embed-text";
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY") ?? "";
const SIMILARITY_THRESHOLD = 0.92;

// Headers for local Ollama requests — ngrok requires this to bypass its
// browser interstitial page for programmatic/API traffic.
const LOCAL_LLM_HEADERS: Record<string, string> = {
  "Content-Type": "application/json",
  "ngrok-skip-browser-warning": "true",
};

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// ── Shared Summarization Prompt ───────────────────────────────────
const SUMMARIZATION_PROMPT = `
You are a factual news summarizer. Generate a strict, non-clickbait title, a summary, and classify the category for the following article.

Follow this EXACT format:
TITLE: <A short, factual, objective title (max 10 words)>
SUMMARY: <A concise summary using the 5Ws framework (Who, What, Where, When, Why) in about 50-70 words. One tight paragraph, no markdown.>
CATEGORY: <Must be EXACTLY one of: politics, tech, science, business, sports, entertainment, health, world>

CRITICAL: Do NOT output any conversational preamble. Start immediately with TITLE:

Article:
`.trim();

// ── LLM: Summarize ────────────────────────────────────────────────
async function summarize(text: string): Promise<{ title: string; summary: string; category: string }> {
  let rawContent = "";

  if (LLM_PROVIDER === "gemini") {
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${GEMINI_API_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts: [{ text: `${SUMMARIZATION_PROMPT}\n${text}` }] }],
          generationConfig: { maxOutputTokens: 500, temperature: 0.2 },
        }),
      }
    );
    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`Gemini Summary failed (${res.status}): ${errText}`);
    }
    const json = await res.json();
    rawContent = json.candidates[0].content.parts[0].text.trim();
    console.log(`[LLM] Gemini received ${rawContent.length} chars.`);
  } else if (LLM_PROVIDER === "groq") {
    const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${GROQ_API_KEY}`,
      },
      body: JSON.stringify({
        model: "llama-3.3-70b-versatile",
        messages: [
          { role: "user", content: `${SUMMARIZATION_PROMPT}\n${text}` },
        ],
        max_tokens: 500,
        temperature: 0.2,
      }),
    });
    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`Groq Summary failed (${res.status}): ${errText}`);
    }
    const json = await res.json();
    rawContent = json.choices[0].message.content.trim();
    console.log(`[LLM] Groq received ${rawContent.length} chars.`);
  } else {
    // Default: local Ollama (OpenAI-compatible)
    const url = `${LOCAL_LLM_BASE_URL}/chat/completions`;
    console.log(`[LLM] Summarizing via: ${url} (Model: ${LOCAL_LLM_MODEL})`);
    const res = await fetch(url, {
      method: "POST",
      headers: LOCAL_LLM_HEADERS,
      body: JSON.stringify({
        model: LOCAL_LLM_MODEL,
        messages: [
          { role: "user", content: `${SUMMARIZATION_PROMPT}\n${text}` },
        ],
        max_tokens: 500,
        temperature: 0.2,
        stream: false,
      }),
    });
    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`Ollama Summary failed (${res.status}): ${errText}`);
    }
    const json = await res.json();
    rawContent = json.choices[0].message.content.trim();
    console.log(`[LLM] Local received ${rawContent.length} chars.`);
  }

  return parseTitleAndSummary(rawContent);
}

function parseTitleAndSummary(raw: string): { title: string; summary: string; category: string } {
  let title = "News Update";
  let summary = raw;
  let category = "world";

  const titleMatch = raw.match(/TITLE:\s*(.*)/i);
  const summaryMatch = raw.match(/SUMMARY:\s*([\s\S]*?)(?=CATEGORY:|\z)/i);
  const categoryMatch = raw.match(/CATEGORY:\s*(.*)/i);

  if (titleMatch) title = titleMatch[1].trim();

  if (summaryMatch) {
    summary = summaryMatch[1].trim();
  } else if (titleMatch) {
    // Fallback: if it has TITLE: but no SUMMARY: tag, take everything after the title line
    const afterTitle = raw.split(/TITLE:.*?\n/i)[1] || "";
    summary = afterTitle.trim() || raw.replace(/TITLE:.*?\n/i, "").trim();
  }

  if (categoryMatch) {
    let extractedCategory = categoryMatch[1].trim().toLowerCase();
    extractedCategory = extractedCategory.replace(/[^a-z]/g, ""); // remove non-alpha chars
    const validCategories = ["politics", "tech", "science", "business", "sports", "entertainment", "health", "world"];
    if (validCategories.includes(extractedCategory)) {
      category = extractedCategory;
    }
  }

  // Cleanup asterisks or quotes LLMs sometimes mistakenly add
  title = title.replace(/\*\*/g, "").replace(/^"|"$/g, "");
  summary = summary.replace(/\*\*/g, "");

  return { title, summary, category };
}

// ── LLM: Embed ────────────────────────────────────────────────────
async function embed(text: string): Promise<number[]> {
  if (LLM_PROVIDER === "gemini") {
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=${GEMINI_API_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          model: "models/text-embedding-004",
          content: { parts: [{ text }] },
        }),
      }
    );
    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`Gemini Embedding failed (${res.status}): ${errText}`);
    }
    const json = await res.json();
    return json.embedding.values;
  }

  // Local Ollama: OpenAI-compatible /v1/embeddings
  // Uses a dedicated embedding model (nomic-embed-text = 768 dims) rather than
  // the LLM itself — avoids the 4096-dim IVFFlat index limit in pgvector.
  const url = `${LOCAL_LLM_BASE_URL}/embeddings`;
  console.log(`[EMBED] URL: ${url} | Model: ${LOCAL_EMBED_MODEL}`);

  const res = await fetch(url, {
    method: "POST",
    headers: LOCAL_LLM_HEADERS,
    body: JSON.stringify({ model: LOCAL_EMBED_MODEL, input: text }),
  });

  console.log(`[EMBED DEBUG] Response status: ${res.status}`);
  const responseHeaders: Record<string, string> = {};
  res.headers.forEach((v, k) => { responseHeaders[k] = v; });
  console.log(`[EMBED DEBUG] Response headers: ${JSON.stringify(responseHeaders)}`);

  if (!res.ok) {
    const errText = await res.text();
    console.error(`[EMBED DEBUG] Error body: ${errText}`);
    throw new Error(`Ollama Embedding failed (${res.status}): ${errText}`);
  }

  const json = await res.json();
  return json.data[0].embedding;
}

// ── Jina-Reader text extraction ───────────────────────────────────
async function extractText(url: string): Promise<string> {
  // Uses Jina Reader (free, no key) for clean article text
  const res = await fetch(`https://r.jina.ai/${url}`, {
    headers: { Accept: "text/plain" },
  });
  if (!res.ok) throw new Error(`Jina Reader failed: ${res.status}`);
  const text = await res.text();

  const lowerText = text.toLowerCase();

  // If Jina hits Cloudflare, paywalls, or bot-protection
  if (
    lowerText.includes("403 forbidden") ||
    lowerText.includes("access denied") ||
    lowerText.includes("please enable cookies") ||
    lowerText.includes("security check") ||
    lowerText.includes("are you a robot") ||
    lowerText.includes("javascript is disabled") ||
    lowerText.includes("turn on javascript") ||
    lowerText.includes("attention required")
  ) {
    throw new Error("Jina Reader hit a bot-protection/paywall blockade.");
  }

  // Trim to ~3000 chars to stay within LLM context
  return text.slice(0, 3000);
}

// ── RSS Parser (regex-based, no DOMParser) ────────────────────────
// deno-dom does not support "text/xml" — parsing RSS with regex avoids
// that limitation entirely and works for RSS 2.0 and basic Atom feeds.
interface RssItem {
  title: string;
  link: string;
  pubDate: string;
  source: string;
}

/** Extract the text content of the FIRST occurrence of <tag>…</tag> in src. */
function extractTag(src: string, tag: string): string {
  const m = src.match(new RegExp(`<${tag}[^>]*><!\\[CDATA\\[([\\s\\S]*?)\\]\\]><\/${tag}>`, "i"))
    ?? src.match(new RegExp(`<${tag}[^>]*>([\\s\\S]*?)<\/${tag}>`, "i"));
  return m ? m[1].trim() : "";
}

async function parseRss(feedUrl: string): Promise<RssItem[]> {
  const res = await fetch(feedUrl);
  if (!res.ok) throw new Error(`Failed to fetch feed (${res.status}): ${feedUrl}`);
  const xml = await res.text();

  // Channel / feed title
  const channelTitle = extractTag(xml, "title") || "Unknown Source";

  // Split on <item> (RSS 2.0) or <entry> (Atom)
  const itemTag = xml.includes("<item") ? "item" : "entry";
  const itemRegex = new RegExp(`<${itemTag}[\\s>][\\s\\S]*?<\/${itemTag}>`, "gi");
  const rawItems = xml.match(itemRegex) ?? [];

  return rawItems.slice(0, 10).map((block) => {
    const title = extractTag(block, "title");

    // RSS 2.0 uses <link>, Atom uses <link href="…"/> or <id>
    let link = extractTag(block, "link");
    if (!link) {
      const hrefMatch = block.match(/<link[^>]+href=["']([^"']+)["']/i);
      link = hrefMatch ? hrefMatch[1] : extractTag(block, "guid") || extractTag(block, "id");
    }

    const pubDate =
      extractTag(block, "pubDate") ||
      extractTag(block, "published") ||
      extractTag(block, "updated") ||
      new Date().toISOString();

    return { title, link, pubDate, source: channelTitle };
  }).filter((item) => item.title && item.link);
}

// ── Deduplication ─────────────────────────────────────────────────
async function isDuplicate(embedding: number[]): Promise<boolean> {
  const { data, error } = await supabase.rpc("match_recent_articles", {
    query_embedding: embedding,
    similarity_threshold: SIMILARITY_THRESHOLD,
    match_count: 1,
  });
  if (error) {
    console.error("Dedup query error:", error.message);
    return false;
  }
  return (data?.length ?? 0) > 0;
}

// ── Main Handler ──────────────────────────────────────────────────
serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const { feedUrl } = await req.json();
  if (!feedUrl) {
    return new Response(JSON.stringify({ error: "feedUrl is required" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  console.log(`[Ingest] Starting request for: ${feedUrl}`);
  console.log(`[Ingest] Using LLM Provider: ${LLM_PROVIDER}`);
  console.log(`[Ingest] Local Base URL: ${LOCAL_LLM_BASE_URL}`);
  const results = { ingested: 0, skipped: 0, errors: 0 };

  // Process at most 3 articles per call — llama3.1 takes ~8-12s each;
  // 10 articles would exceed Supabase's WORKER_LIMIT (60s CPU budget).
  const BATCH_SIZE = 3;

  try {
    const allItems = await parseRss(feedUrl);
    const items = allItems.slice(0, BATCH_SIZE);
    console.log(`[Ingest] Processing ${items.length} of ${allItems.length} items (batch size: ${BATCH_SIZE}).`);

    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      if (i > 0) {
        console.log(`[Ingest] Throttling for 2.5s to prevent rate limits...`);
        await new Promise((resolve) => setTimeout(resolve, 2500));
      }
      console.log(`[Item] Processing: ${item.title.slice(0, 50)}...`);
      try {
        // 1. Extract clean text
        console.log(`[Item] Extracting text from: ${item.link}`);
        const articleText = await extractText(item.link);
        console.log(`[Item] Extracted ${articleText.length} characters.`);

        // 2. Generate embedding for deduplication
        console.log(`[Item] Generating embedding...`);
        const embedding = await embed(item.title + " " + articleText.slice(0, 200));

        // 3. Skip if duplicate
        if (await isDuplicate(embedding)) {
          console.log(`[Item] Skip: Duplicate detected.`);
          results.skipped++;
          continue;
        }

        // 4. Summarize (Title + Body + Category)
        console.log(`[Item] Summarizing...`);
        const { title: llmTitle, summary: llmSummary, category: llmCategory } = await summarize(articleText);

        console.log(`[Item] Clean Title: ${llmTitle}`);
        console.log(`[Item] Summary:     ${llmSummary.slice(0, 50)}...`);
        console.log(`[Item] Category:    ${llmCategory}`);

        // 5. Persist — upsert so re-running the same feed never throws a
        //    duplicate-key error on original_url; existing rows are left as-is.
        console.log(`[Item] Persisting to Supabase...`);
        const { error } = await supabase.from("articles").upsert(
          {
            title: llmTitle,
            summary: llmSummary,
            original_url: item.link,
            source_name: item.source,
            published_at: new Date(item.pubDate).toISOString(),
            category: llmCategory,
            embedding: `[${embedding.join(",")}]`,
          },
          { onConflict: "original_url", ignoreDuplicates: true }
        );

        if (error) {
          console.error("[Item] Insert error:", error.message);
          results.errors++;
        } else {
          console.log(`[Item] Successfully ingested.`);
          results.ingested++;
        }
      } catch (itemErr) {
        console.error(`[Item] Error processing ${item.link}:`, itemErr);
        results.errors++;
      }
    }
  } catch (feedErr) {
    return new Response(
      JSON.stringify({ error: String(feedErr), results }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }

  console.log(`[Ingest] Finished. Results:`, results);
  return new Response(JSON.stringify({ ok: true, results }), {
    headers: { "Content-Type": "application/json" },
  });
});
