/// <reference lib="deno.ns" />
import { decodeBase64 } from "https://deno.land/std@0.224.0/encoding/base64.ts";
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
You are a factual news summarizer and classifier. Generate a strict, non-clickbait title, a 5Ws summary, and classify the article category.

Return the result as a raw JSON object only (no preamble):
{
  "title": "...",
  "summary": "...",
  "category": "..."
}

"category" MUST be one of:
- "politics" (elections, laws, government, diplomacy)
- "tech" (consumer gadgets, software apps, companies, AI products)
- "science" (research papers, space exploration, physics, biology, academic archeology)
- "business" (markets, finance, corporate news, trade)
- "sports" (games, matches, teams, athletes)
- "entertainment" (movies, music, celebrities, arts)
- "health" (medicine, wellness, public health, diseases)
- "world" (general news, humanitarian, crime, transit)

NOTE: Distinguish carefully between "tech" (consumer/business software/hardware) and "science" (deep fundamental research or academic discovery).

Article to summarize and classify:
`.trim();

// ── LLM: Summarize ────────────────────────────────────────────────
async function summarize(text: string, provider: string, geminiKey: string, categoryHint?: string): Promise<{ title: string; summary: string; category: string }> {
  let rawContent = "";
  const categoryContext = categoryHint ? `\nThe source feed is tagged as '${categoryHint}'. Use this as a guide for classification.` : "";
  const fullPrompt = `${SUMMARIZATION_PROMPT}${categoryContext}\n\nArticle:\n${text}`;

  if (provider === "gemini") {
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=${geminiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts: [{ text: fullPrompt }] }],
          generationConfig: {
            maxOutputTokens: 500,
            temperature: 0.1,
            responseMimeType: "application/json"
          },
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
  } else if (provider === "groq") {
    const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${GROQ_API_KEY}`,
      },
      body: JSON.stringify({
        model: "llama-3.3-70b-versatile",
        messages: [
          { role: "user", content: fullPrompt },
        ],
        response_format: { type: "json_object" },
        max_tokens: 500,
        temperature: 0.1,
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
    console.log(`[LLM] Summarizing via: ${url} (Model: ${LOCAL_LLM_MODEL})At base url ${LOCAL_LLM_BASE_URL}`);
    const res = await fetch(url, {
      method: "POST",
      headers: LOCAL_LLM_HEADERS,
      body: JSON.stringify({
        model: LOCAL_LLM_MODEL,
        messages: [
          { role: "user", content: fullPrompt },
        ],
        format: "json",
        max_tokens: 500,
        temperature: 0.1,
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
  try {
    const parsed = typeof raw === 'string' ? JSON.parse(raw) : raw;
    const title = (parsed.title || "News Update").replace(/\*\*/g, "").replace(/^"|"$/g, "");
    const summary = (parsed.summary || raw).replace(/\*\*/g, "").replace(/^"|"$/g, "");
    let category = (parsed.category || "world").toLowerCase().replace(/[^a-z]/g, "");

    const validCategories = ["politics", "tech", "science", "business", "sports", "entertainment", "health", "world"];
    if (!validCategories.includes(category)) category = "world";

    return { title, summary, category };
  } catch (err: any) {
    console.error(`[Parse] Failed to parse JSON: ${err.message}. Raw: ${raw}`);
    // Fallback: simple text cleanup
    return {
      title: "News Update",
      summary: raw.slice(0, 300),
      category: "world"
    };
  }
}

// ── LLM: Embed ────────────────────────────────────────────────────
async function embed(text: string): Promise<number[]> {
  // Always use local Ollama: OpenAI-compatible /v1/embeddings
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

// ── Scraper Service text extraction ─────────────────────────────────
async function extractText(url: string): Promise<{ text: string; imageUrl?: string; imageBase64?: string }> {
  const scraperUrl = Deno.env.get("SCRAPER_SERVICE_URL") ?? "http://localhost:8000/scrape";
  console.log(`[Item] Calling Scraper Service at ${scraperUrl} for ${url}`);

  const res = await fetch(scraperUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ url }),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Scraper Service failed (${res.status}): ${errText}`);
  }

  const json = await res.json();
  const text = (json.text || "").slice(0, 3000);
  return {
    text,
    imageUrl: json.image_url || undefined,
    imageBase64: json.image_base64 || undefined
  };
}

// ── Supabase Storage: Persistent Image Hosting ─────────────────────
async function uploadImage(base64Data: string, fileName: string): Promise<string | null> {
  try {
    const imageBytes = decodeBase64(base64Data);
    const bucketName = "article-images";
    const filePath = `covers/${fileName}.jpg`;

    const { data, error } = await supabase.storage
      .from(bucketName)
      .upload(filePath, imageBytes, {
        contentType: "image/jpeg",
        upsert: true,
      });

    if (error) {
      console.error(`[Storage] Upload failed: ${error.message}`);
      return null;
    }

    // Get public URL
    const { data: { publicUrl } } = supabase.storage
      .from(bucketName)
      .getPublicUrl(filePath);

    return publicUrl;
  } catch (err) {
    console.error(`[Storage] Unexpected error: ${err}`);
    return null;
  }
}

// ── RSS Parser (regex-based, no DOMParser) ────────────────────────
// deno-dom does not support "text/xml" — parsing RSS with regex avoids
// that limitation entirely and works for RSS 2.0 and basic Atom feeds.
interface RssItem {
  title: string;
  link: string;
  pubDate: string;
  source: string;
  description: string;
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
    const description = (extractTag(block, "description") || extractTag(block, "content") || extractTag(block, "summary") || "").replace(/<[^>]+>/g, "").trim();

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

    return { title, link, pubDate, source: channelTitle, description };
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

  const body = await req.json();
  const { feedUrl, llmProvider, geminiApiKey } = body;
  if (!feedUrl) {
    return new Response(JSON.stringify({ error: "feedUrl is required" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const currentProvider = llmProvider || LLM_PROVIDER;
  const currentGeminiKey = geminiApiKey || GEMINI_API_KEY;

  console.log(`[Ingest] Starting request for: ${feedUrl}`);
  console.log(`[Ingest] Using LLM Provider: ${currentProvider}`);
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
      if (currentProvider === "gemini") {
        console.log(`[Ingest] Throttling for 5s to respect Gemini Free Tier (15 RPM)...`);
        await new Promise((resolve) => setTimeout(resolve, 5000));
      }
      console.log(`[Item] Processing: ${item.title.slice(0, 50)}...`);
      try {
        // 1. Extract clean text & Images
        console.log(`[Item] Extracting content from: ${item.link}`);
        let articleText = "";
        let articleImageUrl: string | undefined = undefined;
        try {
          const result = await extractText(item.link);
          articleText = result.text;

          if (result.imageBase64) {
            console.log(`[Item] Image captured. Uploading to Supabase Storage...`);
            const persistentUrl = await uploadImage(result.imageBase64, crypto.randomUUID());
            articleImageUrl = persistentUrl || result.imageUrl; // Fallback to original if upload fails
          } else {
            articleImageUrl = result.imageUrl;
          }
        } catch (e: any) {
          console.warn(`[Item] Scraper Service failed for ${item.link}, falling back to RSS description. Error: ${e.message}`);
          articleText = item.description || "";
        }

        if (articleText.length < 100) {
          // If description is also too short, combine with title
          articleText = `${item.title}\n\n${articleText}`;
        }

        // 2. Summarize (Title + Body + Category)
        console.log(`[Item] Summarizing...`);
        const { title: llmTitle, summary: llmSummary, category: llmCategory } = await summarize(articleText, currentProvider, currentGeminiKey, body.categoryHint);

        // 3. Generate embedding for deduplication based on SUMMARY and TITLE
        console.log(`[Item] Generating embedding...`);
        const embedding = await embed(llmTitle + " " + llmSummary);

        // 4. Skip if duplicate
        if (await isDuplicate(embedding)) {
          console.log(`[Item] Skip: Duplicate detected.`);
          results.skipped++;
          continue;
        }

        console.log(`[Item] Clean Title: ${llmTitle}`);
        console.log(`[Item] Summary:     ${llmSummary.slice(0, 50)}...`);
        console.log(`[Item] Category:    ${llmCategory}`);
        if (articleImageUrl) console.log(`[Item] Image:       ${articleImageUrl}`);

        // 5. Persist — upsert so re-running the same feed never throws a
        //    duplicate-key error on original_url; existing rows are left as-is.
        console.log(`[Item] Persisting to Supabase...`);
        const { error } = await supabase.from("articles").upsert(
          {
            title: llmTitle,
            summary: llmSummary,
            original_url: item.link,
            image_url: articleImageUrl,
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
