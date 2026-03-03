import { decodeBase64 } from "https://deno.land/std@0.224.0/encoding/base64.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const LLM_PROVIDER = Deno.env.get("LLM_PROVIDER") ?? "local"; // local | gemini | groq
const RAW_LOCAL_LLM_BASE_URL = Deno.env.get("LOCAL_LLM_BASE_URL") ?? "http://localhost:11434/v1";

const LOCAL_LLM_BASE_URL = RAW_LOCAL_LLM_BASE_URL.replace(/\/+$/, "").endsWith("/v1")
  ? RAW_LOCAL_LLM_BASE_URL.replace(/\/+$/, "")
  : `${RAW_LOCAL_LLM_BASE_URL.replace(/\/+$/, "")}/v1`;

const LOCAL_LLM_MODEL = Deno.env.get("LOCAL_LLM_MODEL") ?? "llama3.1";
const LOCAL_EMBED_MODEL = Deno.env.get("LOCAL_EMBED_MODEL") ?? "nomic-embed-text";
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY") ?? "";
const SIMILARITY_THRESHOLD = 0.92;

const LOCAL_LLM_HEADERS: Record<string, string> = {
  "Content-Type": "application/json",
  "ngrok-skip-browser-warning": "true",
};

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

const VALID_CATEGORIES = ["politics", "tech", "science", "business", "sports", "entertainment", "health", "world"] as const;
type ValidCategory = typeof VALID_CATEGORIES[number];

const SUMMARIZATION_PROMPT = `
You are a factual news summarizer and multi-label classifier.
1. Generate a strict, non-clickbait title.
2. Generate a concise 5Ws summary of EXACTLY 64 words.
3. Identify ALL applicable categories for this article (an article can belong to more than one).
4. Determine the content "type" (hard_news, analysis, opinion, review, listicle, sponsored, irrelevant).

Return the result as a raw JSON object only (no preamble):
{
  "title": "...",
  "summary": "...",
  "categories": ["primary_category", "secondary_category"],
  "subcategory": "...",
  "type": "..."
}

Rules:
1. "summary" MUST be exactly 64 words. Count carefully. Use the example below as a guide for length.
2. "title" must be factual and non-clickbait.
3. "categories" MUST be a JSON array containing only values from: "politics", "tech", "science", "business", "sports", "entertainment", "health", "world". List the MOST relevant category first. Include all categories that genuinely apply (e.g., an AI regulation bill → ["tech", "politics"]).
4. "subcategory" should be a specific, granular topic string representing the article (e.g., 'AI', 'Game Dev', 'Elections', 'Startups', 'Space'). Keep it to 1-3 words.
5. "type" MUST be one of: "hard_news", "analysis", "opinion", "review", "listicle", "sponsored", "irrelevant".
   - hard_news: Breaking news, reports on current events.
   - analysis: Deep dives, context-heavy reporting.
   - opinion/review/listicle/sponsored/irrelevant: Low-signal fluff for a news app.

Example of a 64-word summary (Use this density as a template):
"Following a significant technological breakthrough, researchers at the leading national laboratory successfully demonstrated a new quantum computing architecture. This innovative approach utilizes stable silicon-based qubits, drastically reducing error rates compared to previous superconducting models. The team believes this advancement paves the logical path towards commercially viable quantum systems within five years, potentially revolutionizing cryptography, materials science, and complex financial modeling worldwide starting today."

Article to summarize and classify:
`.trim();

async function summarize(text: string, provider: string, geminiKey: string, categoryHint?: string, categoryBias: "strong" | "neutral" = "neutral"): Promise<{ title: string; summary: string; categories: string[]; type: string; subcategory: string }> {
  let rawContent = "";

  let categoryContext = "";
  if (categoryHint) {
    if (categoryBias === "strong") {
      categoryContext = `\nThe source feed is strongly associated with '${categoryHint}'. You MUST include '${categoryHint}' as the first element of the categories array unless it is completely unrelated. Add other applicable categories after it.`;
    } else {
      categoryContext = `\nThe source feed is broadly tagged as '${categoryHint}'. Include all categories that genuinely apply; '${categoryHint}' should be listed first if applicable.`;
    }
  }

  const fullPrompt = `${SUMMARIZATION_PROMPT}${categoryContext}\n\nArticle:\n${text}`;

  if (provider === "gemini") {
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=${geminiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts: [{ text: fullPrompt }] }],
          generationConfig: { maxOutputTokens: 500, temperature: 0.1, responseMimeType: "application/json" },
        }),
      }
    );
    if (!res.ok) throw new Error(`Gemini Summary failed (${res.status}): ${await res.text()}`);
    const json = await res.json();
    rawContent = json.candidates[0].content.parts[0].text.trim();
  } else if (provider === "groq") {
    const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${GROQ_API_KEY}` },
      body: JSON.stringify({
        model: "llama-3.3-70b-versatile",
        messages: [{ role: "user", content: fullPrompt }],
        response_format: { type: "json_object" },
        max_tokens: 500,
        temperature: 0.1,
      }),
    });
    if (!res.ok) throw new Error(`Groq Summary failed (${res.status}): ${await res.text()}`);
    const json = await res.json();
    rawContent = json.choices[0].message.content.trim();
  } else {
    const url = `${LOCAL_LLM_BASE_URL}/chat/completions`;
    const res = await fetch(url, {
      method: "POST",
      headers: LOCAL_LLM_HEADERS,
      body: JSON.stringify({
        model: LOCAL_LLM_MODEL,
        messages: [{ role: "user", content: fullPrompt }],
        format: "json",
        max_tokens: 500,
        temperature: 0.1,
        stream: false,
      }),
    });
    if (!res.ok) throw new Error(`Ollama Summary failed (${res.status}): ${await res.text()}`);
    const json = await res.json();
    rawContent = json.choices[0].message.content.trim();
  }
  return parseTitleAndSummary(rawContent);
}

function parseTitleAndSummary(raw: string): { title: string; summary: string; categories: string[]; type: string; subcategory: string } {
  try {
    const parsed = typeof raw === 'string' ? JSON.parse(raw) : raw;
    const title = (parsed.title || "News Update").replace(/\*\*/g, "").replace(/^"|"$/g, "");
    const summary = (parsed.summary || raw).replace(/\*\*/g, "").replace(/^"|"$/g, "");

    // Support both old `category` string and new `categories` array from LLM
    let rawCategories: string[] = [];
    if (Array.isArray(parsed.categories) && parsed.categories.length > 0) {
      rawCategories = parsed.categories;
    } else if (typeof parsed.category === 'string') {
      rawCategories = [parsed.category]; // backwards-compatible fallback
    }
    const categories: string[] = rawCategories
      .map((c: string) => c.toLowerCase().replace(/[^a-z]/g, ""))
      .filter((c: string) => (VALID_CATEGORIES as readonly string[]).includes(c));
    if (categories.length === 0) categories.push("world");

    const type = (parsed.type || "hard_news").toLowerCase();
    const subcategory = (parsed.subcategory || "").replace(/\*\*/g, "").replace(/^"|"$/g, "").trim();
    return { title, summary, categories, type, subcategory };
  } catch (err: any) {
    return { title: "News Update", summary: raw.slice(0, 300), categories: ["world"], type: "hard_news", subcategory: "" };
  }
}

async function embed(text: string): Promise<number[]> {
  const url = `${LOCAL_LLM_BASE_URL}/embeddings`;
  const res = await fetch(url, {
    method: "POST",
    headers: LOCAL_LLM_HEADERS,
    // num_gpu: 0 forces Ollama to run the embedding model on CPU only.
    // Remove this option to let Ollama use the GPU again.
    body: JSON.stringify({ model: LOCAL_EMBED_MODEL, input: text, options: { num_gpu: 0 } }),
  });
  if (!res.ok) throw new Error(`Ollama Embedding failed (${res.status}): ${await res.text()}`);
  const json = await res.json();
  return json.data[0].embedding;
}

async function extractText(url: string): Promise<{ text: string; imageUrl?: string; imageBase64?: string }> {
  const scraperUrl = Deno.env.get("SCRAPER_SERVICE_URL") ?? "http://localhost:8000/scrape";
  const res = await fetch(scraperUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ url }),
  });
  if (!res.ok) throw new Error(`Scraper Service failed (${res.status}): ${await res.text()}`);
  const json = await res.json();
  return { text: (json.text || "").slice(0, 3000), imageUrl: json.image_url, imageBase64: json.image_base64 };
}

async function uploadImage(base64Data: string, fileName: string): Promise<string | null> {
  try {
    const imageBytes = decodeBase64(base64Data);
    const { error } = await supabase.storage.from("article-images").upload(`covers/${fileName}.jpg`, imageBytes, { contentType: "image/jpeg", upsert: true });
    if (error) return null;
    const { data: { publicUrl } } = supabase.storage.from("article-images").getPublicUrl(`covers/${fileName}.jpg`);
    return publicUrl;
  } catch (err) {
    return null;
  }
}

function extractTag(src: string, tag: string): string {
  const m = src.match(new RegExp(`<${tag}[^>]*><!\\[CDATA\\[([\\s\\S]*?)\\]\\]><\/${tag}>`, "i")) ?? src.match(new RegExp(`<${tag}[^>]*>([\\s\\S]*?)<\/${tag}>`, "i"));
  return m ? m[1].trim() : "";
}

async function parseRss(feedUrl: string) {
  const res = await fetch(feedUrl, {
    headers: {
      // Mimic a real browser request — many RSS publishers block bare bot UAs
      "User-Agent": "Mozilla/5.0 (compatible; Currenta/1.0; +https://currenta.app/bot)",
      "Accept": "application/rss+xml, application/atom+xml, application/xml, text/xml, */*",
    },
  });
  if (!res.ok) throw new Error(`Failed to fetch feed (HTTP ${res.status}): ${feedUrl}`);
  const xml = await res.text();
  const channelTitle = extractTag(xml, "title") || "Unknown Source";
  const itemTag = xml.includes("<item") ? "item" : "entry";
  const itemRegex = new RegExp(`<${itemTag}[\\s>][\\s\\S]*?<\/${itemTag}>`, "gi");
  const rawItems = xml.match(itemRegex) ?? [];
  const JUNK_KEYWORDS = /\b(review|top \d+|best of|how to|deals?|deals|coupons?|gift guide|podcast|sponsored)\b/i;

  return rawItems.slice(0, 10).map((block) => {
    const title = extractTag(block, "title");
    const description = (extractTag(block, "description") || extractTag(block, "content") || extractTag(block, "summary") || "").replace(/<[^>]+>/g, "").trim();
    let link = extractTag(block, "link");
    if (!link) {
      const hrefMatch = block.match(/<link[^>]+href=["']([^"']+)["']/i);
      link = hrefMatch ? hrefMatch[1] : extractTag(block, "guid") || extractTag(block, "id");
    }
    const pubDate = extractTag(block, "pubDate") || extractTag(block, "published") || extractTag(block, "updated") || new Date().toISOString();
    return { title, link, pubDate, source: channelTitle, description };
  }).filter((item) => {
    if (!item.title || !item.link) return false;
    // Skip reviews, listicles, and other non-news fluff
    if (JUNK_KEYWORDS.test(item.title)) {
      console.log(`[parseRss] Filtering out junk article title: "${item.title}"`);
      return false;
    }
    return true;
  });
}

async function isDuplicate(embedding: number[]): Promise<boolean> {
  const { data, error } = await supabase.rpc("match_recent_articles", { query_embedding: embedding, similarity_threshold: SIMILARITY_THRESHOLD, match_count: 1 });
  if (error) return false;
  return (data?.length ?? 0) > 0;
}

async function sha256(str: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(str));
  return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, "0")).join("");
}

/** Returns a stable string identifying the LLM used for summarization. */
function modelName(provider: string): string {
  if (provider === "gemini") return "gemini-2.5-flash-lite";
  if (provider === "groq") return "llama-3.3-70b-versatile";
  return LOCAL_LLM_MODEL;
}

async function enforceRateLimit() {
  while (true) {
    const minuteAgo = new Date(Date.now() - 60000).toISOString();
    const { count, error } = await supabase.from("llm_usage").select("id", { count: "exact", head: true }).gte("created_at", minuteAgo);
    if (error) break;
    if (count !== null && count >= 15) {
      console.log(`[Rate Limit] Too many LLM calls (${count}). Waiting 10s...`);
      await new Promise(r => setTimeout(r, 10000));
    } else {
      await supabase.from("llm_usage").insert({});
      break;
    }
  }
}

// TEMPORARILY DISABLED: rate limiting bypassed for local Ollama use.
// Re-enable by restoring `await enforceRateLimit();` in processFeed().
function _enforceRateLimitDisabled() { /* no-op */ }

/**
 * Returns true if the scraped text looks like a browser error page rather than
 * real article content (JS-disabled screens, extension blocks, paywalls, etc.).
 * In that case the caller should fall back to the RSS item description.
 */
function isScraperErrorPage(text: string): boolean {
  if (!text || text.trim().length < 50) return true;
  const lower = text.toLowerCase();
  const errorSignals = [
    "javascript disabled",
    "javascript is disabled",
    "javascript must be enabled",
    "please enable javascript",
    "requires javascript",
    "browser extension blocking",
    "browser extension is preventing",
    "a required part of the site couldn",
    "this site requires javascript",
    "you need to enable javascript",
    "technical issue prevents",
    "site loading due to",
    "blocking video player",
    "disable the extension",
    "403 forbidden",
    "access denied",
    "subscribe to read",
    "subscribe to continue",
    "create a free account to read",
    "sign in to read",
    "this content is for subscribers",
    "cookie consent",
    "browser not supported",
    "upgrade your browser",
  ];
  return errorSignals.some((signal) => lower.includes(signal));
}

export async function processFeed(feedUrl: string, category: string, categoryBias: "strong" | "neutral" = "neutral") {
  const results = { ingested: 0, skipped: 0, errors: 0 };
  const allItems = await parseRss(feedUrl);
  const items = allItems.slice(0, 10);

  for (const item of items) {
    // ── Layer 1: URL-based idempotency (cheap, no scraping needed) ──────────
    const { data: existingByUrl } = await supabase
      .from("articles")
      .select("id")
      .eq("original_url", item.link)
      .maybeSingle();
    if (existingByUrl) {
      results.skipped++;
      continue;
    }

    // ── Layer 2: content_hash idempotency (URL+title fingerprint) ───────────
    const contentHash = await sha256(item.link + item.title);
    const { data: existingByHash } = await supabase
      .from("articles")
      .select("id")
      .eq("content_hash", contentHash)
      .maybeSingle();
    if (existingByHash) {
      results.skipped++;
      continue;
    }

    try {
      let articleText = "";
      let articleImageUrl: string | undefined = undefined;
      try {
        const result = await extractText(item.link);
        const scraperTextIsError = isScraperErrorPage(result.text);

        if (scraperTextIsError) {
          // If scraper failed/got gated, try the RSS description
          articleText = item.description || "";
          // If the fallback is also an error or too short, skip entirely
          if (isScraperErrorPage(articleText) || articleText.length < 450) {
            console.warn(`[processFeed] Skipping ${item.link}: Too short or invalid content (${articleText.length} chars)`);
            results.skipped++;
            continue;
          }
        } else {
          articleText = result.text;
        }

        if (!scraperTextIsError && result.imageBase64) {
          const imageFileName = await sha256(item.link);
          const persistentUrl = await uploadImage(result.imageBase64, imageFileName);
          articleImageUrl = persistentUrl || result.imageUrl;
        } else {
          articleImageUrl = result.imageUrl;
        }
      } catch (e) {
        articleText = item.description || "";
        if (isScraperErrorPage(articleText) || articleText.length < 450) {
          results.skipped++;
          continue;
        }
      }

      if (articleText.length < 100) articleText = `${item.title}\n\n${articleText}`;

      // Final check: if we're left with junk, don't summarize
      if (isScraperErrorPage(articleText) || articleText.length < 450) {
        results.skipped++;
        continue;
      }

      // RATE LIMIT BYPASSED (local Ollama mode) — restore the line below to re-enable:
      // await enforceRateLimit();

      const { title: llmTitle, summary: llmSummary, categories: llmCategories, type: llmType, subcategory: llmSubcategory } = await summarize(articleText, LLM_PROVIDER, GEMINI_API_KEY, category, categoryBias);

      // Post-Summarization Safety Check: If the AI summarized an error page despite our filters
      if (isScraperErrorPage(llmTitle) || isScraperErrorPage(llmSummary.slice(0, 100))) {
        console.warn(`[processFeed] AI summarized an error page for ${item.link} (Title: ${llmTitle}). Skipping.`);
        results.skipped++;
        continue;
      }

      // NOISE FILTER: Only allow high-signal news (ignore reviews, listicles, etc.)
      const allowedTypes = ["hard_news", "analysis"];
      if (!allowedTypes.includes(llmType)) {
        console.log(`[processFeed] Skipping low-signal content type "${llmType}" for ${item.link}`);
        results.skipped++;
        continue;
      }

      const embedding = await embed(llmTitle + " " + llmSummary);

      if (await isDuplicate(embedding)) {
        results.skipped++;
        continue;
      }

      const { error } = await supabase.from("articles").upsert(
        {
          title: llmTitle,
          summary: llmSummary,
          original_url: item.link,
          image_url: articleImageUrl,
          source_name: item.source,
          published_at: new Date(item.pubDate).toISOString(),
          categories: llmCategories,
          subcategory: llmSubcategory,
          embedding: `[${embedding.join(",")}]`,
          content_hash: contentHash,
          summary_model: modelName(LLM_PROVIDER),
        },
        { onConflict: "original_url", ignoreDuplicates: true }
      );
      if (error) results.errors++;
      else results.ingested++;
    } catch (itemErr) {
      results.errors++;
    }
  }
  return results;
}
