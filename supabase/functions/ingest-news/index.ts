// supabase/functions/ingest-news/index.ts
// Supabase Edge Function — ingests an RSS feed, summarizes with the configured
// LLM, deduplicates via pgvector cosine similarity, and persists to PostgreSQL.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { DOMParser } from "https://deno.land/x/deno_dom@v0.1.43/deno-dom-wasm.ts";

// ── Environment ───────────────────────────────────────────────────
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const LLM_PROVIDER = Deno.env.get("LLM_PROVIDER") ?? "local"; // local | gemini | groq
const LOCAL_LLM_BASE_URL =
  Deno.env.get("LOCAL_LLM_BASE_URL") ?? "http://localhost:11434/v1";
const LOCAL_LLM_MODEL = Deno.env.get("LOCAL_LLM_MODEL") ?? "mistral";
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY") ?? "";
const SIMILARITY_THRESHOLD = 0.92;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// ── Shared Summarization Prompt ───────────────────────────────────
const SUMMARIZATION_PROMPT = `
Summarize the following news article in EXACTLY 64 words or fewer using the 5Ws framework.
Cover: Who is involved, What happened, Where it occurred, When it happened, and Why it matters.
Write as one tight, factual paragraph. Do NOT use bullet points or markdown formatting.

Article:
`.trim();

// ── LLM: Summarize ────────────────────────────────────────────────
async function summarize(text: string): Promise<string> {
  if (LLM_PROVIDER === "gemini") {
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${GEMINI_API_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts: [{ text: `${SUMMARIZATION_PROMPT}\n${text}` }] }],
          generationConfig: { maxOutputTokens: 120, temperature: 0.3 },
        }),
      }
    );
    const json = await res.json();
    return json.candidates[0].content.parts[0].text.trim();
  }

  if (LLM_PROVIDER === "groq") {
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
        max_tokens: 120,
        temperature: 0.3,
      }),
    });
    const json = await res.json();
    return json.choices[0].message.content.trim();
  }

  // Default: local Ollama (OpenAI-compatible)
  const res = await fetch(`${LOCAL_LLM_BASE_URL}/chat/completions`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model: LOCAL_LLM_MODEL,
      messages: [
        { role: "user", content: `${SUMMARIZATION_PROMPT}\n${text}` },
      ],
      max_tokens: 120,
      temperature: 0.3,
    }),
  });
  const json = await res.json();
  return json.choices[0].message.content.trim();
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
    const json = await res.json();
    return json.embedding.values;
  }

  // Local Ollama embeddings (works with nomic-embed-text, mistral, etc.)
  const res = await fetch(`${LOCAL_LLM_BASE_URL}/embeddings`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ model: LOCAL_LLM_MODEL, input: text }),
  });
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
  // Trim to ~3000 chars to stay within LLM context
  return text.slice(0, 3000);
}

// ── RSS Parser ────────────────────────────────────────────────────
interface RssItem {
  title: string;
  link: string;
  pubDate: string;
  source: string;
}

async function parseRss(feedUrl: string): Promise<RssItem[]> {
  const res = await fetch(feedUrl);
  const xml = await res.text();
  const doc = new DOMParser().parseFromString(xml, "text/xml");
  if (!doc) throw new Error("Failed to parse RSS XML.");

  const channelTitle =
    doc.querySelector("channel > title")?.textContent ?? "Unknown Source";
  const items = Array.from(doc.querySelectorAll("item")).slice(0, 10);

  return items.map((item) => ({
    title: item.querySelector("title")?.textContent ?? "",
    link:
      item.querySelector("link")?.textContent ??
      item.querySelector("guid")?.textContent ??
      "",
    pubDate: item.querySelector("pubDate")?.textContent ?? new Date().toISOString(),
    source: channelTitle,
  }));
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

  const results = { ingested: 0, skipped: 0, errors: 0 };

  try {
    const items = await parseRss(feedUrl);

    for (const item of items) {
      try {
        // 1. Extract clean text
        const articleText = await extractText(item.link);

        // 2. Generate embedding for deduplication
        const embedding = await embed(item.title + " " + articleText.slice(0, 200));

        // 3. Skip if duplicate
        if (await isDuplicate(embedding)) {
          results.skipped++;
          continue;
        }

        // 4. Summarize
        const summary = await summarize(articleText);

        // 5. Persist
        const { error } = await supabase.from("articles").insert({
          title: item.title,
          summary,
          original_url: item.link,
          source_name: item.source,
          published_at: new Date(item.pubDate).toISOString(),
          category: "world", // TODO: LLM-classified category
          embedding: `[${embedding.join(",")}]`,
        });

        if (error) {
          console.error("Insert error:", error.message);
          results.errors++;
        } else {
          results.ingested++;
        }
      } catch (itemErr) {
        console.error(`Error processing ${item.link}:`, itemErr);
        results.errors++;
      }
    }
  } catch (feedErr) {
    return new Response(
      JSON.stringify({ error: String(feedErr), results }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }

  return new Response(JSON.stringify({ ok: true, results }), {
    headers: { "Content-Type": "application/json" },
  });
});
