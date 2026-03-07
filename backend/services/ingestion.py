import os
import json
import asyncio
import hashlib
from datetime import datetime, timezone
from bs4 import BeautifulSoup
import httpx
from supabase import create_client, Client
from .scraper import scrape_article_sync
from dateutil import parser as date_parser

SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

LLM_PROVIDER = os.environ.get("LLM_PROVIDER", "local")
RAW_LOCAL_LLM_BASE_URL = os.environ.get("LOCAL_LLM_BASE_URL", "http://localhost:11434/v1")
LOCAL_LLM_BASE_URL = RAW_LOCAL_LLM_BASE_URL.rstrip("/")
if not LOCAL_LLM_BASE_URL.endswith("/v1"):
    LOCAL_LLM_BASE_URL += "/v1"

LOCAL_LLM_MODEL = os.environ.get("LOCAL_LLM_MODEL", "llama3.1")
LOCAL_EMBED_MODEL = os.environ.get("LOCAL_EMBED_MODEL", "nomic-embed-text")
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")
GROQ_API_KEY = os.environ.get("GROQ_API_KEY", "")

SIMILARITY_THRESHOLD = 0.92

VALID_CATEGORIES = ["politics", "tech", "science", "business", "sports", "entertainment", "health", "world"]

# Create a synchronous supabase client for storage uploads and RPC calls if needed
supabase_client: Client | None = None
if SUPABASE_URL and SUPABASE_SERVICE_KEY:
    try:
        supabase_client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
    except Exception as e:
        print(f"Failed to initialize Supabase client: {e}")
else:
    print("WARNING: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY missing. Image uploads and some RPCs will fail.")

# ---------------------------------------------------------------------------
# Control signals for background tasks
# ---------------------------------------------------------------------------
SHOULD_STOP_INGESTION = False

def cancel_ingestion():
    global SHOULD_STOP_INGESTION
    SHOULD_STOP_INGESTION = True
    print("[Ingestion] Cancellation signal received. Will stop at next opportunity.")

# ---------------------------------------------------------------------------
# Feed registry — mirrors lib/core/config/news_sources.dart
# ---------------------------------------------------------------------------
FEEDS = [
    # World
    { "feedUrl": "http://feeds.bbci.co.uk/news/rss.xml", "defaultCategory": "world", "categoryBias": "neutral" },
    { "feedUrl": "http://feeds.bbci.co.uk/news/world/rss.xml", "defaultCategory": "world", "categoryBias": "neutral" },
    { "feedUrl": "https://www.reutersagency.com/feed/?best-topics=political-general&post_type=best", "defaultCategory": "world", "categoryBias": "neutral" },
    { "feedUrl": "https://www.aljazeera.com/xml/rss/all.xml", "defaultCategory": "world", "categoryBias": "neutral" },
    { "feedUrl": "https://rss.nytimes.com/services/xml/rss/nyt/World.xml", "defaultCategory": "world", "categoryBias": "neutral" },
    { "feedUrl": "https://feeds.a.dj.com/rss/RSSWorldNews.xml", "defaultCategory": "world", "categoryBias": "neutral" },
    { "feedUrl": "https://www.dw.com/xml/rss-en-all", "defaultCategory": "world", "categoryBias": "neutral" },
    { "feedUrl": "https://www.france24.com/en/rss", "defaultCategory": "world", "categoryBias": "neutral" },
    # Tech
    { "feedUrl": "https://www.techmeme.com/feed.xml", "defaultCategory": "tech", "categoryBias": "strong" },
    { "feedUrl": "https://www.theverge.com/rss/index.xml", "defaultCategory": "tech", "categoryBias": "strong" },
    { "feedUrl": "https://techcrunch.com/feed/", "defaultCategory": "tech", "categoryBias": "strong" },
    { "feedUrl": "https://www.wired.com/feed/rss", "defaultCategory": "tech", "categoryBias": "strong" },
    { "feedUrl": "https://feeds.arstechnica.com/arstechnica/index", "defaultCategory": "tech", "categoryBias": "strong" },
    { "feedUrl": "https://www.engadget.com/rss.xml", "defaultCategory": "tech", "categoryBias": "strong" },
    { "feedUrl": "https://9to5mac.com/feed/", "defaultCategory": "tech", "categoryBias": "strong" },
    { "feedUrl": "https://www.gizmodo.com/rss", "defaultCategory": "tech", "categoryBias": "strong" },
    { "feedUrl": "https://venturebeat.com/feed/", "defaultCategory": "tech", "categoryBias": "strong" },
    { "feedUrl": "https://www.technologyreview.com/feed/", "defaultCategory": "tech", "categoryBias": "strong" },
    # Politics
    { "feedUrl": "https://www.politico.com/rss/politicopicks.xml", "defaultCategory": "politics", "categoryBias": "strong" },
    { "feedUrl": "https://thehill.com/homenews/feed/", "defaultCategory": "politics", "categoryBias": "strong" },
    { "feedUrl": "https://rss.nytimes.com/services/xml/rss/nyt/Politics.xml", "defaultCategory": "politics", "categoryBias": "strong" },
    { "feedUrl": "https://www.huffpost.com/section/politics/feed", "defaultCategory": "politics", "categoryBias": "strong" },
    # Science
    { "feedUrl": "https://www.sciencedaily.com/rss/all.xml", "defaultCategory": "science", "categoryBias": "strong" },
    { "feedUrl": "https://www.sciencedaily.com/rss/top/science.xml", "defaultCategory": "science", "categoryBias": "strong" },
    { "feedUrl": "https://www.nature.com/nature.rss", "defaultCategory": "science", "categoryBias": "strong" },
    { "feedUrl": "https://www.nasa.gov/rss/dyn/breaking_news.rss", "defaultCategory": "science", "categoryBias": "strong" },
    { "feedUrl": "https://www.scientificamerican.com/section/all/feed/", "defaultCategory": "science", "categoryBias": "strong" },
    { "feedUrl": "https://www.newscientist.com/feed/home/", "defaultCategory": "science", "categoryBias": "strong" },
    # Sports
    { "feedUrl": "https://www.skysports.com/rss/12040", "defaultCategory": "sports", "categoryBias": "strong" },
    { "feedUrl": "https://feeds.bbci.co.uk/sport/rss.xml", "defaultCategory": "sports", "categoryBias": "strong" },
    { "feedUrl": "https://www.espn.com/espn/rss/news", "defaultCategory": "sports", "categoryBias": "strong" },
    { "feedUrl": "https://www.cbssports.com/rss/headlines/", "defaultCategory": "sports", "categoryBias": "strong" },
    # Entertainment
    { "feedUrl": "https://variety.com/feed/", "defaultCategory": "entertainment", "categoryBias": "strong" },
    { "feedUrl": "https://www.hollywoodreporter.com/feed/", "defaultCategory": "entertainment", "categoryBias": "strong" },
    { "feedUrl": "https://www.billboard.com/feed/", "defaultCategory": "entertainment", "categoryBias": "strong" },
    { "feedUrl": "https://www.rollingstone.com/feed/", "defaultCategory": "entertainment", "categoryBias": "strong" },
    # Business
    { "feedUrl": "https://www.ft.com/news-feed.rss", "defaultCategory": "business", "categoryBias": "strong" },
    { "feedUrl": "https://www.cnbc.com/id/100003114/device/rss/rss.html", "defaultCategory": "business", "categoryBias": "strong" },
    { "feedUrl": "https://feeds.a.dj.com/rss/WSJcomUSBusiness.xml", "defaultCategory": "business", "categoryBias": "strong" },
    # Health
    { "feedUrl": "https://www.who.int/rss-feeds/news-english.xml", "defaultCategory": "health", "categoryBias": "strong" },
    { "feedUrl": "https://www.healthline.com/rss/all-news.xml", "defaultCategory": "health", "categoryBias": "strong" },
    { "feedUrl": "https://www.mayoclinic.org/rss/all-news-topics.xml", "defaultCategory": "health", "categoryBias": "strong" },
]

SUMMARIZATION_PROMPT = """You are a factual news summarizer and multi-label classifier.
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
3. "categories" MUST be a JSON array containing only values from: "politics", "tech", "science", "business", "sports", "entertainment", "health", "world". List the MOST relevant category first. Include all categories that genuinely apply (e.g., an AI regulation bill -> ["tech", "politics"]).
4. "subcategory" should be a specific, granular topic string representing the article (e.g., 'AI', 'Game Dev', 'Elections', 'Startups', 'Space'). Keep it to 1-3 words.
5. "type" MUST be one of: "hard_news", "analysis", "opinion", "review", "listicle", "sponsored", "irrelevant".
   - hard_news: Breaking news, reports on current events.
   - analysis: Deep dives, context-heavy reporting.
   - opinion/review/listicle/sponsored/irrelevant: Low-signal fluff for a news app.

Example of a 64-word summary (Use this density as a template):
"Following a significant technological breakthrough, researchers at the leading national laboratory successfully demonstrated a new quantum computing architecture. This innovative approach utilizes stable silicon-based qubits, drastically reducing error rates compared to previous superconducting models. The team believes this advancement paves the logical path towards commercially viable quantum systems within five years, potentially revolutionizing cryptography, materials science, and complex financial modeling worldwide starting today."

Article to summarize and classify:
"""

def generate_content_hash(link: str, title: str) -> str:
    s = link + title
    return hashlib.sha256(s.encode('utf-8')).hexdigest()

def is_scraper_error_page(text: str) -> bool:
    if not text:
        return True
    # Relax length check; some valid summaries/titles are short.
    if len(text.strip()) < 10:
        return True
    lower = text.lower()
    error_signals = [
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
    ]
    return any(signal in lower for signal in error_signals)

def is_junk_content(text: str, title: str) -> bool:
    """Checks for promotional material, betting ads, and low-signal media like podcast summaries."""
    combined = (title + " " + text).lower()
    hard_signals = [
        "promo code", "bonus bets", "bonus bet", "sign-up bonus", "sign up bonus",
        "signup bonus", "welcome bonus", "first deposit bonus", "draftkings",
        "fanduel", "betmgm", "caesars sportsbook", "pointsbet", "bet365", "bovada",
        "barstool sportsbook", "sports betting promo", "betting promo",
        "sportsbook promo", "gambling promo", "place a bet", "your first bet",
        "if your first bet", "bet $", "sponsored by", "this is a sponsored",
        "paid partnership", "affiliate disclosure", "advertiser disclosure",
        "affiliate link", "we may earn a commission", "we earn from qualifying purchases",
        "use our promo code", "use code ", "enter code ", "redeem code", "discount code",
        "coupon code", "please gamble responsibly", "responsible gambling",
        "problem gambling helpline", "1-800-gambler", "gambling helpline",
        "bet must be placed", "min. odds", "minimum odds", "-500 odds", "odds req",
        "token and bonus bets", "non-withdrawable",
        "podcast summary", "latest episode", "new episode", "listen to the podcast",
        "listen on apple", "listen on spotify", "subscribe on", "full episode of",
        "this episode of", "bonus episode", "transcript provided", "show notes",
    ]
    if any(signal in combined for signal in hard_signals):
        return True

    soft_signals = [
        "promo", "sportsbook", "oddsmaker", "parlay", "moneyline", "point spread",
        "over/under", "wagering", "sweepstakes", "giveaway", "refer a friend",
        "loyalty points", "cash back offer", "podcast", "episode"
    ]
    matches = sum(1 for signal in soft_signals if signal in combined)
    return matches >= 2

async def summarize_article(text: str, provider: str, category_hint: str = None, category_bias: str = "neutral") -> dict:
    category_context = ""
    if category_hint:
        if category_bias == "strong":
            category_context = f"\nThe source feed is strongly associated with '{category_hint}'. You MUST include '{category_hint}' as the first element of the categories array unless it is completely unrelated. Add other applicable categories after it."
        else:
            category_context = f"\nThe source feed is broadly tagged as '{category_hint}'. Include all categories that genuinely apply; '{category_hint}' should be listed first if applicable."

    full_prompt = f"{SUMMARIZATION_PROMPT}{category_context}\n\nArticle:\n{text}"
    raw_content = ""

    async with httpx.AsyncClient(timeout=30.0) as client:
        if provider == "gemini":
            res = await client.post(
                f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key={GEMINI_API_KEY}",
                json={
                    "contents": [{"parts": [{"text": full_prompt}]}],
                    "generationConfig": {"maxOutputTokens": 500, "temperature": 0.1, "responseMimeType": "application/json"}
                }
            )
            res.raise_for_status()
            data = res.json()
            raw_content = data["candidates"][0]["content"]["parts"][0]["text"].strip()
            
        elif provider == "groq":
            res = await client.post(
                "https://api.groq.com/openai/v1/chat/completions",
                headers={"Authorization": f"Bearer {GROQ_API_KEY}"},
                json={
                    "model": "llama-3.3-70b-versatile",
                    "messages": [{"role": "user", "content": full_prompt}],
                    "response_format": {"type": "json_object"},
                    "max_tokens": 500,
                    "temperature": 0.1
                }
            )
            res.raise_for_status()
            data = res.json()
            raw_content = data["choices"][0]["message"]["content"].strip()
            
        else:
            # Ollama
            res = await client.post(
                f"{LOCAL_LLM_BASE_URL}/chat/completions",
                headers={"Content-Type": "application/json", "ngrok-skip-browser-warning": "true"},
                json={
                    "model": LOCAL_LLM_MODEL,
                    "messages": [{"role": "user", "content": full_prompt}],
                    "format": "json",
                    "max_tokens": 500,
                    "temperature": 0.1,
                    "stream": False
                }
            )
            res.raise_for_status()
            data = res.json()
            raw_content = data["choices"][0]["message"]["content"].strip()

    return parse_llm_response(raw_content)

def parse_llm_response(raw_str: str) -> dict:
    import re
    # 4. LLM Failure Handling: Add robust parsing layer
    # Strip markdown fences and trailing commentary
    clean_str = re.sub(r"```(?:json)?\s*([\s\S]*?)```", r"\1", raw_str).strip()
    
    try:
        parsed = json.loads(clean_str)
    except json.JSONDecodeError:
        # Retry parse once by finding the first '{' and last '}'
        try:
            match = re.search(r"(\{.*\})", clean_str, re.DOTALL)
            if match:
                parsed = json.loads(match.group(1))
            else:
                raise
        except Exception:
            print(f"[LLM Parser] Failed to parse JSON even with cleanup: {raw_str[:100]}...")
            return {
                "title": "News Update",
                "summary": raw_str[:300],
                "categories": ["world"],
                "type": "irrelevant",
                "subcategory": ""
            }

    try:
        title = parsed.get("title", "News Update").replace("**", "").strip('"')
        summary = parsed.get("summary", raw_str).replace("**", "").strip('"')
        
        raw_categories = parsed.get("categories", [])
        if not raw_categories and isinstance(parsed.get("category"), str):
            raw_categories = [parsed.get("category")]
            
        categories = []
        for c in raw_categories:
            cl = ''.join(filter(str.isalpha, str(c).lower()))
            if cl in VALID_CATEGORIES:
                categories.append(cl)
        if not categories:
            categories.append("world")
            
        type_str = parsed.get("type", "hard_news").lower()
        subcat = parsed.get("subcategory", "").replace("**", "").strip('"').strip()
        
        return {
            "title": title,
            "summary": summary,
            "categories": categories,
            "type": type_str,
            "subcategory": subcat
        }
    except Exception as e:
        print(f"[LLM Parser] Logic error: {e}")
        return {
            "title": "News Update",
            "summary": raw_str[:300],
            "categories": ["world"],
            "type": "irrelevant",
            "subcategory": ""
        }

async def embed_text(text: str) -> list[float]:
    async with httpx.AsyncClient() as client:
        res = await client.post(
            f"{LOCAL_LLM_BASE_URL}/embeddings",
            headers={"Content-Type": "application/json", "ngrok-skip-browser-warning": "true"},
            json={"model": LOCAL_EMBED_MODEL, "input": text, "options": {"num_gpu": 0}}
        )
        res.raise_for_status()
        data = res.json()
        return data["data"][0]["embedding"]

async def upload_image_sync(base64_data: str, file_name: str) -> str | None:
    if not supabase_client:
        print("[Image-Storage] CRITICAL: Supabase client not initialized. Cannot upload.")
        return None
    try:
        import base64
        image_bytes = base64.b64decode(base64_data)
        file_path = f"covers/{file_name}.jpg"
        # print(f"[Image-Storage] Attempting upload of {file_path} ({len(image_bytes)/1024:.1f}KB)...")
        
        # Check bucket before upload? Minimal approach: just attempt
        res = supabase_client.storage.from_("article-images").upload(
            file_path,
            image_bytes,
            file_options={"content-type": "image/jpeg", "upsert": "true"}
        )
        
        # Supabase Python client returns the response object or raises an exception
        # We need to see what's inside.
        # print(f"[Image-Storage] Upload result: {res}")
        
        public_url = supabase_client.storage.from_("article-images").get_public_url(file_path)
        # print(f"[Image-Storage] Generated Public URL: {public_url}")
        
        return public_url
    except Exception as e:
        print(f"[Image-Storage] ERROR during upload to Supabase: {type(e).__name__} - {e}")
        import traceback
        traceback.print_exc()
        return None

async def parse_rss(feed_url: str) -> list[dict]:
    async with httpx.AsyncClient(follow_redirects=True) as client:
        res = await client.get(
            feed_url,
            headers={
                "User-Agent": "Mozilla/5.0 (compatible; Currenta/1.0; +https://currenta.app/bot)",
                "Accept": "application/rss+xml, application/atom+xml, application/xml, text/xml, */*"
            },
            timeout=15.0
        )
        res.raise_for_status()
        xml = res.text
        
    soup = BeautifulSoup(xml, 'xml')
    # Try RSS channel title, then Atom feed title
    channel = soup.find('channel')
    feed = soup.find('feed')
    
    if channel and channel.title:
        channel_title = channel.title.text
    elif feed and feed.title:
        channel_title = feed.title.text
    elif soup.title:
        channel_title = soup.title.text
    else:
        channel_title = "Unknown Source"
    
    # Clean up source names
    source_mapping = {
        "WSJ.com: World News": "The Wall Street Journal",
        "WSJ.com: US Business News": "The Wall Street Journal",
        "WSJ.com: Markets News": "The Wall Street Journal",
        "Al Jazeera": "Al Jazeera",
        "The Verge -  All Posts": "The Verge",
        "BBC News - World": "BBC",
        "Source: Techmeme": "Techmeme",
        "Techmeme": "Techmeme",
        "BBC News": "BBC",
        "Reuters: Top News": "Reuters",
    }
    channel_display_name = source_mapping.get(channel_title, channel_title)
    
    items = soup.find_all(['item', 'entry'])[:10]
    
    junk_keywords = [
        "review", "top 10", "best of", "how to", "deals", "coupon", "gift guide", "podcast",
        "sponsored", "promo code", "bonus offer", "sign up bonus", "betting odds", "sportsbook",
        "draftkings", "fanduel", "pointsbet", "caesars sportsbook", "mgm bet", "prize picks",
        "parlay", "sports betting", "gambling", "wager", "sweepstakes", "giveaway", "affiliate",
        "discount code", "voucher"
    ]
    
    parsed_items = []
    for item in items:
        # Use clean channel name
        source_name = channel_display_name
        title = item.title.text if item.title else ""
        link = ""
        if item.link:
            link = item.link.get_text(strip=True)
            if not link:
                # Handle atom-style <link href="..."/>
                link = item.link.get('href', '')
        
        if not link and item.guid:
            link = item.guid.get_text(strip=True)
        
        description = item.description.text if item.description else (item.summary.text if item.summary else "")
        description = BeautifulSoup(description, "html.parser").get_text(strip=True)
        
        pub_date_str = item.pubDate.text if item.pubDate else (item.published.text if item.published else (item.updated.text if item.updated else ""))
        try:
            # Parse to a timezone-aware datetime object (asyncpg requires datetime, not str)
            pub_date = date_parser.parse(pub_date_str, ignoretz=False)
            if pub_date.tzinfo is None:
                pub_date = pub_date.replace(tzinfo=timezone.utc)
        except Exception:
            pub_date = datetime.now(timezone.utc)

        if not title or not link:
            continue
            
        check_text = (title + " " + description).lower()
        is_junk = any(kw in check_text for kw in junk_keywords)
        if is_junk:
            print(f"[parseRss] Filtering out junk article: {title}")
            continue
            
        # Extract image from RSS if available
        image_url_rss = None
        # 1. Enclosure tag
        enclosure = item.find('enclosure', url=True)
        if enclosure and enclosure.get('type', '').startswith('image/'):
            image_url_rss = enclosure.get('url')
        
        # 2. Media:content or content tag
        if not image_url_rss:
            media_content = item.find(['media:content', 'content'], url=True)
            if media_content:
                image_url_rss = media_content.get('url')
        
        # 3. Media:thumbnail tag
        if not image_url_rss:
            media_thumbnail = item.find(['media:thumbnail', 'thumbnail'], url=True)
            if media_thumbnail:
                image_url_rss = media_thumbnail.get('url')

        # if image_url_rss:
        #     print(f"[parseRss] Found image in RSS for '{title[:30]}...': {image_url_rss}")

        parsed_items.append({
            "title": title,
            "link": link,
            "pubDate": pub_date,
            "source": channel_title,
            "description": description,
            "imageUrl": image_url_rss
        })
        
    return parsed_items

async def is_duplicate(conn, embedding: list[float]) -> bool:
    # 3. Duplicate Detection Logic optimization: Reduces latency by passing the connection
    # 2. Embedding Conversion Bug Risk: If PostgreSQL + pgvector is used, pass as list (driver handles serialization) or string if needed.
    # We attempt passing the list directly.
    try:
        # Check similarity match (...)
        records = await conn.fetch(
            "SELECT id FROM match_recent_articles($1, $2, $3)",
            embedding, SIMILARITY_THRESHOLD, 1
        )
        return len(records) > 0
    except Exception as e:
        # Fallback to string if the driver doesn't handle list->vector automatically
        # though modern asyncpg + pgvector usually prefers list or specialized type.
        try:
            embedding_str = f"[{','.join(map(str, embedding))}]"
            records = await conn.fetch(
                "SELECT id FROM match_recent_articles($1, $2, $3)",
                embedding_str, SIMILARITY_THRESHOLD, 1
            )
            return len(records) > 0
        except Exception as inner_e:
            print(f"[Duplicate Check] error: {inner_e}")
            return False

def get_model_name(provider: str) -> str:
    if provider == "gemini": return "gemini-2.5-flash-lite"
    if provider == "groq": return "llama-3.3-70b-versatile"
    return LOCAL_LLM_MODEL

import json

async def process_feed(feed_url: str, category: str, category_bias: str = "neutral", db_pool=None):
    results = {"ingested": 0, "skipped": 0, "errors": 0}
    try:
        items = await parse_rss(feed_url)
    except Exception as e:
        print(f"[processFeed] RSS parse error for {feed_url}: {e}")
        return results

    if not items:
        return results

    # 1. Database Pool Race Condition Risk: Acquire once and batch check
    async with db_pool.acquire() as conn:
        # Initialize sets to ensure they are available even if the query fails
        existing_urls = set()
        existing_hashes = set()

        # Batch URL + hash checks using ANY($1) queries (similar to IN)
        urls = [item["link"] for item in items]
        hashes = [generate_content_hash(item["link"], item["title"]) for item in items]
        
        try:
            existing = await conn.fetch("""
                SELECT original_url, content_hash FROM articles 
                WHERE original_url = ANY($1) OR content_hash = ANY($2)
            """, urls, hashes)
            existing_urls = {r["original_url"] for r in existing}
            existing_hashes = {r["content_hash"] for r in existing}
        except Exception as e:
            print(f"[processFeed] Batch dedupe query failed: {e}")

        for item in items:
            # Combined duplicate detection logic optimization
            content_hash = generate_content_hash(item["link"], item["title"])
            if item["link"] in existing_urls or content_hash in existing_hashes:
                results["skipped"] += 1
                continue

            try:
                article_text = ""
                article_image_url = None
                
                try:
                    # Scrape internally
                    scraper_result = scrape_article_sync(item["link"])
                    if "error" in scraper_result:
                        print(f"[processFeed] Scraper Error for {item['link']}: {scraper_result['error']}")
                        scraper_text_is_error = True
                        result_text = item.get("description", "")
                    else:
                        scraper_text_is_error = is_scraper_error_page(scraper_result.get("text", ""))
                        result_text = scraper_result.get("text", "")

                    if scraper_text_is_error:
                        print(f"[processFeed] Content blocked/invalid. Falling back to RSS context.")
                        fallback = f"{item['title']}\n\n{item.get('description', '')}".strip()
                        if is_scraper_error_page(fallback) or len(fallback) < 100:
                            results["skipped"] += 1
                            continue
                        article_text = fallback
                    else:
                        article_text = result_text

                    if not scraper_text_is_error and scraper_result.get("image_base64"):
                        image_file_name = hashlib.sha256(item["link"].encode()).hexdigest()
                        persistent_url = await upload_image_sync(scraper_result["image_base64"], image_file_name)
                        article_image_url = persistent_url or scraper_result.get("image_url")
                    else:
                        article_image_url = scraper_result.get("image_url") if "error" not in scraper_result else None
                    
                    # Secondary fallback
                    if not article_image_url and item.get("imageUrl"):
                        article_image_url = item.get("imageUrl")
                        from .scraper import process_image
                        image_base64 = process_image(article_image_url)
                        if image_base64:
                            image_file_name = hashlib.sha256(item["link"].encode()).hexdigest()
                            persistent_url = await upload_image_sync(image_base64, image_file_name)
                            if persistent_url:
                                article_image_url = persistent_url

                except Exception:
                    fallback = f"{item['title']}\n\n{item.get('description', '')}".strip()
                    if is_scraper_error_page(fallback) or len(fallback) < 100:
                        results["skipped"] += 1
                        continue
                    article_text = fallback

                if len(article_text) < 100:
                    article_text = f"{item['title']}\n\n{article_text}"

                if is_scraper_error_page(article_text) or len(article_text) < 100:
                    results["skipped"] += 1
                    continue

                if is_junk_content(article_text, item["title"]):
                    results["skipped"] += 1
                    continue

                # Summarize
                llm_res = await summarize_article(article_text, LLM_PROVIDER, category, category_bias)
                
                if is_scraper_error_page(llm_res["title"]) or is_scraper_error_page(llm_res["summary"][:100]):
                    results["skipped"] += 1
                    continue

                if llm_res["title"].strip().lower() == "news update":
                    results["skipped"] += 1
                    continue

                allowed_types = ["hard_news", "analysis"]
                if llm_res["type"] not in allowed_types:
                    results["skipped"] += 1
                    continue

                embedding = await embed_text(llm_res["title"] + " " + llm_res["summary"])
                
                # Check for semantic duplicate using the same connection
                if await is_duplicate(conn, embedding):
                    results["skipped"] += 1
                    continue

                # Insert using the same connection
                try:
                    await conn.execute('''
                        INSERT INTO articles (
                            title, summary, original_url, image_url, source_name,
                            published_at, categories, subcategory, embedding, content_hash, summary_model
                        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
                        ON CONFLICT (original_url) DO NOTHING
                    ''', 
                    llm_res["title"], llm_res["summary"], item["link"], article_image_url, item["source"],
                    item["pubDate"], llm_res["categories"], llm_res["subcategory"],
                    embedding, content_hash, get_model_name(LLM_PROVIDER))
                    
                    results["ingested"] += 1
                    print(f"[processFeed] Success! {llm_res['title'][:40]}...")
                except Exception as db_err:
                    print(f"[processFeed] DB Insert Error: {db_err}")
                    results["errors"] += 1

            except Exception as item_err:
                print(f"[processFeed] Item processing error: {item_err}")
                results["errors"] += 1

    return results

async def orchestrate():
    """
    Background task to orchestrate the ingestion of all feeds.
    """
    from ..main import db_pool
    if not db_pool:
        print("[Orchestrator] Database pool not ready.")
        return

    print(f"[Orchestrator] Starting orchestration for {len(FEEDS)} feeds")
    
    global SHOULD_STOP_INGESTION
    SHOULD_STOP_INGESTION = False
    
    # 5. Orchestration Sequential Bottleneck: Use controlled concurrency
    semaphore = asyncio.Semaphore(4) # Limit to 4 concurrent feeds to avoid overloading LLM/DB

    async def safe_process(feed):
        if SHOULD_STOP_INGESTION:
            return
        async with semaphore:
            print(f"[Orchestrator] Processing: {feed['feedUrl']}")
            try:
                await process_feed(feed["feedUrl"], feed["defaultCategory"], feed["categoryBias"], db_pool)
            except Exception as e:
                print(f"[Orchestrator] Error processing feed {feed['feedUrl']}: {e}")

    # Create tasks for all feeds
    tasks = [safe_process(feed) for feed in FEEDS]
    await asyncio.gather(*tasks)

    print("[Orchestrator] Orchestration complete")

# Used by the scheduler which runs run_coroutine_threadsafe. 
async def orchestrate_sync_wrapper():
    await orchestrate()

async def add_source_feed_to_queue(feed_url: str, category_hint: str = None):
    from ..main import db_pool
    if not db_pool:
        print("[ManualTrigger] Database pool not ready.")
        return
        
    print(f"[ManualTrigger] Processing feed: {feed_url}")
    # Default category to 'world' if not provided
    cat = category_hint or 'world'
    await process_feed(feed_url, cat, "neutral", db_pool)

