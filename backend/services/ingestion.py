import os
import re
import orjson
import asyncio
import hashlib
from typing import Optional, List
from datetime import datetime, timezone
from bs4 import BeautifulSoup
import httpx
from supabase import create_client, Client
from .scraper import scrape_article_sync, discover_techcrunch_articles
from dateutil import parser as date_parser

import logging
from google import genai
from google.genai import types as genai_types

logger = logging.getLogger(__name__)

SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

LLM_PROVIDER = os.environ.get("LLM_PROVIDER", "local")
RAW_LOCAL_LLM_BASE_URL = os.environ.get("LOCAL_LLM_BASE_URL", "http://localhost:11434/v1")
LOCAL_LLM_BASE_URL = RAW_LOCAL_LLM_BASE_URL.rstrip("/")
if not LOCAL_LLM_BASE_URL.endswith("/v1"):
    LOCAL_LLM_BASE_URL += "/v1"

LOCAL_LLM_MODEL = os.environ.get("LOCAL_LLM_MODEL")
LOCAL_EMBED_MODEL = os.environ.get("LOCAL_EMBED_MODEL", "nomic-embed-text")

# --- Google Gen-AI Clients (Unified SDK) ---
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")
_gemini_client: genai.Client | None = None
if GEMINI_API_KEY:
    _gemini_client = genai.Client(api_key=GEMINI_API_KEY)

VERTEX_PROJECT = os.environ.get("VERTEX_PROJECT")
VERTEX_LOCATION = os.environ.get("VERTEX_LOCATION", "us-central1")
_vertex_client: genai.Client | None = None
if VERTEX_PROJECT:
    _vertex_client = genai.Client(
        vertexai=True,
        project=VERTEX_PROJECT,
        location=VERTEX_LOCATION
    )

GROQ_API_KEY = os.environ.get("GROQ_API_KEY", "")

SIMILARITY_THRESHOLD = 0.92

VALID_CATEGORIES = ["politics", "tech", "science", "business", "sports", "entertainment", "health", "world", "environment"]

# Create a synchronous supabase client for storage uploads and RPC calls if needed
supabase_client: Client | None = None
if SUPABASE_URL and SUPABASE_SERVICE_KEY:
    try:
        supabase_client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
    except Exception as e:
        logger.error(f"Failed to initialize Supabase client: {e}")
else:
    logger.warning("SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY missing. Image uploads and some RPCs will fail.")

# ---------------------------------------------------------------------------
# Control signals for background tasks
# ---------------------------------------------------------------------------
SHOULD_STOP_INGESTION = False

def cancel_ingestion():
    global SHOULD_STOP_INGESTION
    SHOULD_STOP_INGESTION = True
    logger.info("Ingestion cancellation signal received. Will stop at next opportunity.")

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
    { "feedUrl": "https://www.theguardian.com/world/rss", "defaultCategory": "world", "categoryBias": "neutral" },
    { "feedUrl": "https://apnews.com/hub/world-news.rss", "defaultCategory": "world", "categoryBias": "neutral" },
    { "feedUrl": "https://www.dw.com/xml/rss-en-all", "defaultCategory": "world", "categoryBias": "neutral" },
    { "feedUrl": "https://www.france24.com/en/rss", "defaultCategory": "world", "categoryBias": "neutral" },
    # Tech
    { "feedUrl": "https://www.techmeme.com/feed.xml", "defaultCategory": "tech", "categoryBias": "strong" },
    { "feedUrl": "https://www.theverge.com/rss/index.xml", "defaultCategory": "tech", "categoryBias": "neutral" },
    { "feedUrl": "https://techcrunch.com/latest/", "defaultCategory": "tech", "categoryBias": "strong", "method": "site_tc" },
    { "feedUrl": "https://www.wired.com/feed/rss", "defaultCategory": "tech", "categoryBias": "neutral" },
    { "feedUrl": "https://feeds.arstechnica.com/arstechnica/index", "defaultCategory": "tech", "categoryBias": "neutral" },
    { "feedUrl": "https://www.engadget.com/rss.xml", "defaultCategory": "tech", "categoryBias": "neutral" },
    { "feedUrl": "https://9to5mac.com/feed/", "defaultCategory": "tech", "categoryBias": "strong" },
    { "feedUrl": "https://www.gizmodo.com/rss", "defaultCategory": "tech", "categoryBias": "neutral" },
    { "feedUrl": "https://venturebeat.com/feed/", "defaultCategory": "tech", "categoryBias": "strong" },
    { "feedUrl": "https://www.technologyreview.com/feed/", "defaultCategory": "tech", "categoryBias": "strong" },
    # Politics
    { "feedUrl": "https://www.politico.com/rss/politicopicks.xml", "defaultCategory": "politics", "categoryBias": "strong" },
    { "feedUrl": "https://thehill.com/homenews/feed/", "defaultCategory": "politics", "categoryBias": "strong" },
    { "feedUrl": "https://api.axios.com/feed/politics", "defaultCategory": "politics", "categoryBias": "strong" },
    { "feedUrl": "https://apnews.com/hub/politics.rss", "defaultCategory": "politics", "categoryBias": "strong" },
    { "feedUrl": "https://www.theguardian.com/politics/rss", "defaultCategory": "politics", "categoryBias": "strong" },
    { "feedUrl": "https://www.cnbc.com/id/10000113/device/rss/rss.html", "defaultCategory": "politics", "categoryBias": "strong" },
    { "feedUrl": "https://feeds.npr.org/1014/rss.xml", "defaultCategory": "politics", "categoryBias": "strong" },
    { "feedUrl": "https://www.vox.com/rss/policy-and-politics/index.xml", "defaultCategory": "politics", "categoryBias": "strong" },
    { "feedUrl": "https://feeds.nbcnews.com/nbcnews/public/politics", "defaultCategory": "politics", "categoryBias": "strong" },
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
    { "feedUrl": "https://search.cnbc.com/rs/search/combinedcms/view.xml?partnerId=40&id=100011491", "defaultCategory": "business", "categoryBias": "strong" },
    { "feedUrl": "https://finance.yahoo.com/news/rssindex", "defaultCategory": "business", "categoryBias": "strong" },
    { "feedUrl": "https://fortune.com/feed/", "defaultCategory": "business", "categoryBias": "strong" },
    { "feedUrl": "http://feeds.marketwatch.com/marketwatch/topstories/", "defaultCategory": "business", "categoryBias": "strong" },
    { "feedUrl": "https://www.businessinsider.com/rss", "defaultCategory": "business", "categoryBias": "strong" },
    { "feedUrl": "https://www.fastcompany.com/latest/rss", "defaultCategory": "business", "categoryBias": "strong" },
    { "feedUrl": "https://economictimes.indiatimes.com/rssfeedstopstories.cms", "defaultCategory": "business", "categoryBias": "strong" },
    # Health
    { "feedUrl": "https://www.who.int/rss-feeds/news-english.xml", "defaultCategory": "health", "categoryBias": "strong" },
    { "feedUrl": "https://medicalxpress.com/rss-feed/health-news/", "defaultCategory": "health", "categoryBias": "strong" },
    { "feedUrl": "https://kffhealthnews.org/feed/", "defaultCategory": "health", "categoryBias": "strong" },
    { "feedUrl": "https://www.mayoclinic.org/rss/all-news-topics.xml", "defaultCategory": "health", "categoryBias": "strong" },
    # Google News
    { "feedUrl": "https://news.google.com/rss?hl=en-US&gl=US&ceid=US:en", "defaultCategory": "world", "categoryBias": "neutral" },
    { "feedUrl": "https://news.google.com/news/rss/headlines/section/topic/TECHNOLOGY", "defaultCategory": "tech", "categoryBias": "strong" },
    { "feedUrl": "https://news.google.com/news/rss/headlines/section/topic/BUSINESS", "defaultCategory": "business", "categoryBias": "strong" },
    { "feedUrl": "https://news.google.com/news/rss/headlines/section/topic/SCIENCE", "defaultCategory": "science", "categoryBias": "strong" },
    { "feedUrl": "https://news.google.com/news/rss/headlines/section/topic/HEALTH", "defaultCategory": "health", "categoryBias": "strong" },
    { "feedUrl": "https://news.google.com/news/rss/headlines/section/topic/ENTERTAINMENT", "defaultCategory": "entertainment", "categoryBias": "strong" },
    { "feedUrl": "https://news.google.com/news/rss/headlines/section/topic/POLITICS", "defaultCategory": "politics", "categoryBias": "strong" },
    { "feedUrl": "https://news.google.com/news/rss/headlines/section/topic/SPORTS", "defaultCategory": "sports", "categoryBias": "strong" },
]

# Supported regions for localized news ingestion
SUPPORTED_LOCAL_REGIONS = [
    {"code": "KE", "lang": "en"},  # Kenya
]

def build_google_news_rss_url(country_code: str = "US", language_code: str = "en") -> str:
    """
    Builds a localized Google News RSS URL.
    Example for Kenya: hl=en-KE, gl=KE, ceid=KE:en
    """
    cc = country_code.upper()
    lc = language_code.lower()
    return f"https://news.google.com/rss?hl={lc}-{cc}&gl={cc}&ceid={cc}:{lc}"

SUMMARIZATION_PROMPT = """You are a factual news summarizer and multi-label classifier.
1. Generate a strict, non-clickbait title.
2. Generate a concise 5Ws summary of strictly between 60 and 68 words in exactly 3–4 sentences, each sentence roughly 15–20 words.
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
1. "summary" MUST be EXACTLY 65 words (tolerance: 60-70 words), written in exactly 3-4 sentences, each roughly 15-20 words. Use the example below as a guide for length.
2. "title" must be factual and non-clickbait.
3. "categories" MUST be a JSON array containing only values from: "politics", "tech", "science", "business", "sports", "entertainment", "health", "world", "environment". List the MOST relevant category first. Include all categories that genuinely apply (e.g., an AI regulation bill -> ["tech", "politics"]).
4. "subcategory" should be a specific, granular topic string representing the article (e.g., 'AI', 'Gaming', 'Game Dev', 'Elections', 'Startups', 'Space'). Keep it to 1-3 words.
5. "type" MUST be one of: "hard_news", "analysis", "opinion", "review", "listicle", "sponsored", "irrelevant".
   - hard_news: Breaking news, reports on current events.
   - analysis: Deep dives, context-heavy reporting.
   - opinion/review/listicle/sponsored/irrelevant: Low-signal fluff for a news app.
     *IMPORTANT*: LIVE SPORTS SCORE UPDATES, DAILY NEWS ROUNDUPS, BOOK REVIEWS, "BOOKS IN BRIEF", BUYING GUIDES, SHOPPING GUIDES, PRODUCT ROUNDUPS (e.g., "The Best Bluetooth Trackers"), JOB VACANCIES, RECRUITMENT NOTICES, NOW HIRING ANNOUNCEMENTS, HISTORICAL RETROSPECTIVES (e.g., "On this day in history", "Chart Rewind"), and MULTI-TOPIC SUMMARIES (where several unrelated stories are presented together, e.g., "Tech news: Apple event, Blu-ray sales, and new LG TV") ARE CONSIDERED IRRELEVANT. We only want focused, single-topic articles.
6. **Single-Topic Focus**: If the text contains multiple unrelated news stories (e.g., a "daily roundup", "news in brief", "books in brief", "buying guide", or "what happened today"), you MUST classify the article as "type": "irrelevant". DO NOT attempt to summarize multiple unrelated topics into one summary.
7. **Historical Content**: Historical retrospectives, "today in history", or "chart rewinds" (looking back at old charts/events) MUST be classified as "type": "irrelevant".
8. **Negative Constraint**: Do NOT open with meta-phrases like "The article reports that...", "According to the article...", "This article covers...", or similar. Start directly with the news.

Example of a 64-word summary (Use this density as a template):
"Following a significant technological breakthrough, researchers at the leading national laboratory successfully demonstrated a new quantum computing architecture. This innovative approach utilizes stable silicon-based qubits, drastically reducing error rates compared to previous superconducting models. The team believes this advancement paves the logical path towards commercially viable quantum systems within five years, potentially revolutionizing cryptography, materials science, and complex financial modeling worldwide starting today."

Article to summarize and classify:
"""

def generate_content_hash(link: str, title: str) -> str:
    s = link + title
    return hashlib.sha256(s.encode('utf-8')).hexdigest()

PAYWALL_SIGNALS = [
    "subscribe to read",
    "subscribe to continue",
    "create a free account to read",
    "sign in to read",
    "this content is for subscribers",
    "get full access for",
    "ksh299/week",
    "uncover the stories others won",
    "subscribe now for exclusive access",
    "join thousands daily",
    "the standard e-paper",
    "register to read",
    "start your free trial",
    "only for subscribers",
    "premium content",
    "support quality journalism",
    "read the full story with a",
    "keep reading with a",
    "exclusive for members",
    "membership required",
    "start reading for free",
    "limited free articles",
    "reached your free article limit",
    "daily allowance of free articles",
]

TECHNICAL_ERROR_SIGNALS = [
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
    "cookie consent",
    "browser not supported",
    "upgrade your browser",
]

def detect_paywall(text: str) -> bool:
    if not text:
        return False
    lower = text.lower()
    return any(signal in lower for signal in PAYWALL_SIGNALS)

def count_words(text: str) -> int:
    """Utility to count space-separated words."""
    if not text:
        return 0
    return len(text.split())

def is_scraper_error_page(text: str) -> bool:
    if not text:
        return True
    # Relax length check; some valid summaries/titles are short.
    if len(text.strip()) < 10:
        return True
    lower = text.lower()
    return any(signal in lower for signal in (PAYWALL_SIGNALS + TECHNICAL_ERROR_SIGNALS))

def is_junk_content(text: str, title: str) -> Optional[str]:
    """Checks for promotional material, betting ads, and low-signal media like podcast summaries."""
    combined = " " + (title + " " + text).lower() + " "
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
        "archive page", "daily summary", "weekly roundup", "morning newsletter",
        "evening newsletter", "weekend edition", "today's headlines", "top stories of the week",
        "news roundup", "summary of the day", "what we're reading", "recap", "news in brief",
        "the morning download", "daily briefing", "around the web", "recommended reading",
        "score update", "live update", "game tracker", "live blog", "play-by-play",
        "half-time report", "halftime report", "mid-game", "scoring summary", "live scoring",
        "things to know", "stories you missed", "daily news digest", "today's top stories",
        "books in brief", "book review", "summaries of books", "best books of", "reading list",
        "now hiring", "job vacancy", "job opening", "recruitment notice", "career opportunity", "seeks applicants",
        "chart rewind", "historical chart", "this day in history", "on this day", "flashback", "throwback",
        "watch live", "streaming live", "video highlights", "video clip", "video-clips",
        "buying guide", "gift guide", "shopping guide", "the best gadgets", "best phone", "best laptop",
        "best tracker", "best earbud", "best headphone", "best camera", "we've tested", "our tests showed",
        "best smart", "best of 202",
        "winning numbers", "drawn in", "evening draw", "pick 3", "pick 4", "lottery result", "lotto result", "jackpot winner",
        "mega millions", "powerball", "lottery update", "prediction", "match preview", "game preview", "betting tips",
        "expert picks", "score prediction", "forecast", "injury report", "lineup update", "live scoreboard", 
        "real-time updates", "minute-by-minute", "live commentary", "full time results", "half-time score",
        " betting ", " sportsbook ", " oddsmaker ", " parlay ", " moneyline ", " point spread ", " spread ", " over/under ",
        " wagering ", " wagering ", " betting odds ", " free picks ", " expert predictions ", " game odds ", " v.s. ", " vs. ",
        "mock draft", "how to watch", "tv channel", "streaming options", "where to watch", "live stream",
        "quiz", "trivia", "test your knowledge", "test your skills", "how well do you know", "guess the ", "take our poll", "interactive poll"
    ]
    for signal in hard_signals:
        if signal in combined:
            return f"Matched hard signal: {signal}"

    # Check for multi-topic title patterns (too many unrelated items)
    # Titles like "Apple Event, LG TV, and Blu-ray Sales"
    if title.count(',') >= 2 and (" and " in title.lower() or " & " in title):
        # High probability of being a roundup
        return "Multi-topic title pattern (roundup)"

    soft_signals = [
        "promo", "sportsbook", "oddsmaker", "parlay", "moneyline", "point spread",
        "over/under", "wagering", "sweepstakes", "giveaway", "refer a friend",
        "loyalty points", "cash back offer", "podcast", "episode", " betting ", " odds "
    ]
    matches = [signal for signal in soft_signals if signal in combined]
    if len(matches) >= 2:
        return f"Matched soft signals: {', '.join(matches)}"

    # Basic English Detection (Heuristic)
    # If the text is long enough and lacks common English functional words, it's likely non-English.
    if len(combined.split()) > 5:
        # Common English stop words/function words
        common_en_words = [" the ", " and ", " was ", " for ", " with ", " that ", " this ", " from ", " were ", " their "]
        if not any(word in combined for word in common_en_words):
            return "Likely non-English content (heuristic)"

    return None

async def summarize_article(text: str, provider: str, category_hint: str = None, category_bias: str = "neutral") -> dict:
    category_context = ""
    if category_hint:
        if category_bias == "strong":
            category_context = f"\nThe source feed is strongly associated with '{category_hint}'. You MUST include '{category_hint}' as the first element of the categories array unless it is completely unrelated. Add other applicable categories after it."
        else:
            category_context = f"\nThe source feed is broadly tagged as '{category_hint}'. Include all categories that genuinely apply; '{category_hint}' should be listed first if applicable."

    full_prompt = f"{SUMMARIZATION_PROMPT}{category_context}\n\nArticle:\n{text}"
    raw_content = ""

    async with httpx.AsyncClient(timeout=90.0) as client:
        if provider in ("gemini", "vertex"):
            # Use unified SDK for both Gemini (API Studio) and Vertex
            gen_client = _vertex_client if provider == "vertex" else _gemini_client
            if not gen_client:
                raise ValueError(f"Provider '{provider}' is not configured.")

            response = await gen_client.aio.models.generate_content(
                model="gemini-2.5-flash-lite",
                contents=full_prompt,
                config=genai_types.GenerateContentConfig(
                    max_output_tokens=500,
                    temperature=0.1,
                    response_mime_type="application/json"
                )
            )
            raw_content = response.text.strip()
            
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
                    "temperature": 0.3,
                    "stream": False
                }
            )
            res.raise_for_status()
            data = res.json()
            raw_content = data["choices"][0]["message"]["content"].strip()

    return parse_llm_response(raw_content)

def _trim_to_word_limit(text: str, limit: int) -> str:
    """Trim summary to at most `limit` words, cutting at the last complete sentence."""
    words = text.split()
    if len(words) <= limit:
        return text
    truncated = " ".join(words[:limit])
    # Try to cut at the last sentence boundary within the truncated text
    for punct in (".", "!", "?"):
        last = truncated.rfind(punct)
        if last != -1:
            return truncated[:last + 1]
    return truncated

def parse_llm_response(raw_str: str) -> dict:
    # 4. LLM Failure Handling: Add robust parsing layer
    # Strip markdown fences and trailing commentary
    clean_str = re.sub(r"```(?:json)?\s*([\s\S]*?)```", r"\1", raw_str).strip()
    
    parsed = None
    try:
        # Try full parse first
        parsed = orjson.loads(clean_str)
    except orjson.JSONDecodeError:
        # If that fails, try to find the main JSON block using balanced braces or first/last markers
        try:
            start_idx = clean_str.find('{')
            end_idx = clean_str.rfind('}')
            if start_idx != -1 and end_idx != -1 and end_idx > start_idx:
                json_text = clean_str[start_idx:end_idx+1]
                parsed = orjson.loads(json_text)
        except Exception:
            pass

    if not parsed:
        content_snippet = str(raw_str)[:120]
        print(f"[LLM Parser] Failed to parse JSON even with cleanup: {content_snippet}...")
        return {
            "title": "News Update",
            "summary": str(raw_str)[:300],
            "categories": ["world"],
            "type": "irrelevant",
            "subcategory": ""
        }

    try:
        title = parsed.get("title", "News Update").replace("**", "").strip('"')
        summary = parsed.get("summary", raw_str).replace("**", "").strip('"')
        summary = _trim_to_word_limit(summary, 68)
        
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
    async with httpx.AsyncClient(timeout=60.0) as client:
        res = await client.post(
            f"{LOCAL_LLM_BASE_URL}/embeddings",
            headers={"Content-Type": "application/json", "ngrok-skip-browser-warning": "true"},
            json={"model": LOCAL_EMBED_MODEL, "input": text, "options": {"num_gpu": 0}}
        )
        res.raise_for_status()
        data = res.json()
        embedding = data["data"][0]["embedding"]
        return [float(x) for x in embedding]

async def upload_image_sync(image_bytes: bytes, file_name: str) -> str | None:
    if not supabase_client:
        print("[Image-Storage] CRITICAL: Supabase client not initialized. Cannot upload.")
        return None
    try:
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
        channel_title = channel.title.text.strip()
    elif feed and feed.title:
        channel_title = feed.title.text.strip()
    elif soup.title:
        channel_title = soup.title.text.strip()
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
        "Google News": "Google News",
        "Medical Xpress - Health News": "Medical Xpress",
        "Medical Xpress": "Medical Xpress",
        "KFF Health News": "KFF Health News",
        "CBS Sports Headlines": "CBS Sports",
        "The Guardian": "The Guardian",
        "Associated Press": "AP News",
        "AP": "AP News",
        "CNBC": "CNBC",
    }
    channel_display_name = source_mapping.get(channel_title, channel_title)
    
    items = soup.find_all(['item', 'entry'])[:10]
    
    junk_keywords = [
        "review", "top 10", "best of", "how to", "deals", "coupon", "gift guide", "podcast",
        "sponsored", "promo code", "bonus offer", "sign up bonus", "betting odds", "sportsbook",
        "draftkings", "fanduel", "pointsbet", "caesars sportsbook", "mgm bet", "prize picks",
        "parlay", "sports betting", "gambling", "wager", "sweepstakes", "giveaway", "affiliate",
        "discount code", "voucher", "archive page", "daily summary", "roundup", "newsletter",
        "score update", "game tracker", "live blog", "play-by-play", "score summary",
        "news in brief", "daily briefing", "around the web", "what we're reading", "recap",
        "books in brief", "book review", "summaries of books", "now hiring", "job vacancy", "recruitment", "career opportunity",
        "chart rewind", "historical chart", "this day in history", "on this day",
        "watch live", "streaming live", "video-clips", "video highlights",
        "buying guide", "shopping guide", "the best ", "best gadgets", "best phones", "best laptops",
        "quiz", "trivia", "test your knowledge", "how well do you know", "take our poll"
    ]
    
    parsed_items = []
    for item in items:
        # Initial source name from the channel/source mapping
        source_name = channel_display_name
        
        # Check for item-level source (common in Google News)
        item_source = item.find('source')
        if item_source and item_source.text:
            source_name = item_source.text.strip()

        title = item.title.text.strip() if item.title else ""
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
            
        # ── URL-level filtering ──
        # Skip homepage-only links or common non-article paths
        parsed_url = link.lower().split("://")[-1]
        path = parsed_url.split("/", 1)[1] if "/" in parsed_url else ""
        
        # 1. Skip homepages (empty path or just slash)
        if not path or path == "/":
            print(f"[parseRss] Skipping homepage Link: {link}")
            continue
            
        # 2. Techmeme archive pattern: techmeme.com/YYMMDD/ (e.g., techmeme.com/260309/)
        if "techmeme.com" in parsed_url:
            # Matches /260309/ or /260309/p1 etc.
            if re.search(r'/\d{6}(/|$)', link):
                print(f"[parseRss] Skipping Techmeme Archive: {link}")
                continue
        
        # 3. Common non-article paths
        non_article_paths = ["/tag/", "/category/", "/author/", "/archives/", "/labels/", "/search/", "/video-clips/", "/video/quotable/", "/video/"]
        if any(p in link.lower() for p in non_article_paths):
            print(f"[parseRss] Skipping Non-article Path: {link}")
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

        parsed_items.append({
            "title": title,
            "link": link,
            "pubDate": pub_date,
            "source": source_name,
            "description": description,
            "imageUrl": image_url_rss
        })
        
    return parsed_items

async def is_duplicate(conn, embedding: list[float]) -> bool:
    # Recommendation 3: Pass embedding list directly instead of stringifying.
    # We use $1::vector in the query or ensure the function handles the cast.
    try:
        # Check similarity match (...)
        # The match_recent_articles function expects a vector(768).
        # We cast the list (which asyncpg sends as float8[]) to ::vector.
        records = await conn.fetch(
            "SELECT id FROM match_recent_articles($1::float8[]::vector, $2, $3)",
            embedding, SIMILARITY_THRESHOLD, 1
        )
        return len(records) > 0
    except Exception as e:
        # Fallback log
        print(f"[Duplicate Check] error: {e}")
        return False

def get_model_name(provider: str) -> str:
    if provider in ("gemini", "vertex"): return "gemini-2.5-flash-lite"
    if provider == "groq": return "llama-3.3-70b-versatile"
    return LOCAL_LLM_MODEL

async def log_ingestion_event(conn, url, status, source_name=None, error_type=None, error_message=None, has_text=False, has_image=False, extracted_image_url=None, content_preview=None, resolved_url=None):
    try:
        await conn.execute('''
            INSERT INTO ingestion_logs (
                original_url, status, source_name, error_type, error_message, 
                has_text, has_image, extracted_image_url, content_preview, resolved_url
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
        ''', url, status, source_name, error_type, error_message, has_text, has_image, extracted_image_url, content_preview[:500] if content_preview else None, resolved_url)
    except Exception as e:
        print(f"[Logger] Failed to write to ingestion_logs: {e}")

async def process_feed(feed_url: str, category: str, category_bias: str = "neutral", db_pool=None, country_code: Optional[str] = None, method: str = "rss"):
    results = {"ingested": 0, "skipped": 0, "errors": 0}
    try:
        if method == "site_tc":
            # Run the synchronous discovery in a thread pool
            items = await asyncio.to_thread(discover_techcrunch_articles, 10)
        else:
            items = await parse_rss(feed_url)
    except Exception as e:
        print(f"[processFeed] Discovery error for {feed_url} ({method}): {e}")
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
            # Ensure pubDate is a datetime object for DB compatibility
            if isinstance(item.get("pubDate"), str):
                try:
                    item["pubDate"] = date_parser.parse(item["pubDate"])
                except Exception:
                    item["pubDate"] = datetime.now(timezone.utc)
            elif not item.get("pubDate"):
                item["pubDate"] = datetime.now(timezone.utc)

            # Combined duplicate detection logic optimization
            content_hash = generate_content_hash(item["link"], item["title"])
            if item["link"] in existing_urls or content_hash in existing_hashes:
                results["skipped"] += 1
                continue

            try:
                article_text = ""
                article_image_url = None
                
                try:
                    # Run the synchronous scraper in a thread pool to avoid blocking
                    # the async event loop — curl_cffi.requests.get() is blocking I/O.
                    scraper_result = await asyncio.to_thread(scrape_article_sync, item["link"])
                    scraper_error_msg = scraper_result.get("error")
                    scraper_text_is_error = False
                    is_paywalled = False

                    if scraper_error_msg:
                        print(f"[processFeed] Scraper Error for {item['link']}: {scraper_error_msg}")
                        scraper_text_is_error = True
                        result_text = item.get("description", "")
                    else:
                        scraped_text = scraper_result.get("text", "")
                        # Use the flag from scraper (HTML-based) OR our text-based detection
                        is_paywalled = scraper_result.get("is_paywalled", False) or detect_paywall(scraped_text)
                        scraper_text_is_error = is_scraper_error_page(scraped_text)
                        result_text = scraped_text

                    if scraper_text_is_error:
                        print(f"[processFeed] Content blocked/invalid. Falling back to RSS context.")
                        fallback_text = f"{item['title']}\n\n{item.get('description', '')}".strip()
                        if is_scraper_error_page(fallback_text) or count_words(fallback_text) < 75:
                            await log_ingestion_event(conn, item["link"], "FAILED", source_name=item["source"], error_type="SCRAPER_FAIL", error_message=scraper_error_msg or "Blocked/Invalid Content", resolved_url=scraper_result.get("url"))
                            results["skipped"] += 1
                            continue
                        article_text = fallback_text
                        scraper_status = "DEGRADED"
                    else:
                        article_text = result_text
                        scraper_status = "SUCCESS"

                    if not scraper_text_is_error and scraper_result.get("image_bytes"):
                        image_file_name = hashlib.sha256(item["link"].encode()).hexdigest()
                        persistent_url = await upload_image_sync(scraper_result["image_bytes"], image_file_name)
                        article_image_url = persistent_url or scraper_result.get("image_url")
                    else:
                        article_image_url = scraper_result.get("image_url") if not scraper_error_msg else None
                    
                    # Secondary fallback
                    if not article_image_url and item.get("imageUrl"):
                        article_image_url = item.get("imageUrl")
                        from .scraper import process_image
                        image_bytes_fallback = process_image(article_image_url)
                        if image_bytes_fallback:
                            image_file_name = hashlib.sha256(item["link"].encode()).hexdigest()
                            persistent_url = await upload_image_sync(image_bytes_fallback, image_file_name)
                            if persistent_url:
                                article_image_url = persistent_url

                except Exception as e:
                    await log_ingestion_event(conn, item["link"], "FAILED", source_name=item["source"], error_type="INTERNAL_ERROR", error_message=str(e))
                    fallback_text = f"{item['title']}\n\n{item.get('description', '')}".strip()
                    if is_scraper_error_page(fallback_text) or count_words(fallback_text) < 75:
                        results["skipped"] += 1
                        continue
                    article_text = fallback_text
                    scraper_status = "DEGRADED"

                if count_words(article_text) < 120:
                    article_text = f"{item['title']}\n\n{article_text}"

                # Strict validation: require at least 75 words for a meaningful summary.
                if is_scraper_error_page(article_text) or count_words(article_text) < 75:
                    await log_ingestion_event(conn, item["link"], "FAILED", source_name=item["source"], error_type="CONTENT_TOO_SHORT", error_message=f"Content too short: {count_words(article_text)} words")
                    results["skipped"] += 1
                    continue

                junk_reason = is_junk_content(article_text, item["title"])
                if junk_reason:
                    await log_ingestion_event(conn, item["link"], "FAILED", source_name=item["source"], error_type="SKIPPED_JUNK", error_message=junk_reason)
                    results["skipped"] += 1
                    continue

                # Summarize
                try:
                    llm_res = await summarize_article(article_text, LLM_PROVIDER, category, category_bias)
                except Exception as llm_err:
                    print(f"[processFeed] LLM ERROR for {item['link']}: {llm_err}")
                    await log_ingestion_event(conn, item["link"], "FAILED", source_name=item["source"], error_type="LLM_ERROR", error_message=str(llm_err))
                    results["skipped"] += 1
                    continue
                
                if is_scraper_error_page(llm_res["title"]) or is_scraper_error_page(llm_res["summary"][:100]):
                    await log_ingestion_event(conn, item["link"], "FAILED", source_name=item["source"], error_type="LLM_REJECT_CONTENT", error_message="LLM output contains error patterns")
                    results["skipped"] += 1
                    continue

                if llm_res["title"].strip().lower() == "news update":
                    results["skipped"] += 1
                    continue

                allowed_types = ["hard_news", "analysis"]
                if llm_res["type"] not in allowed_types:
                    # Skip silently or log as LOW_SIGNAL
                    results["skipped"] += 1
                    continue

                embedding = await embed_text(llm_res["title"] + " " + llm_res["summary"])
                
                # Check for semantic duplicate using the same connection
                if await is_duplicate(conn, embedding):
                    # We don't always need to log duplicates as they are noisy, but let's do it for tracking
                    # await log_ingestion_event(conn, item["link"], "SKIPPED", source_name=item["source"], error_type="DUPLICATE")
                    results["skipped"] += 1
                    continue

                # Insert using the same connection
                try:
                    # Determine ingestion method for analysis
                    ingestion_method = "scraper" if scraper_status == "SUCCESS" else "rss"
                    
                    await conn.execute('''
                        INSERT INTO articles (
                            title, summary, original_url, image_url, source_name,
                            published_at, categories, subcategory, embedding, content_hash, 
                            summary_model, country_code, is_paywalled, ingestion_method, created_at
                        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9::float8[]::vector, $10, $11, $12, $13, $14, NOW())
                        ON CONFLICT (original_url) DO NOTHING
                    ''', 
                    llm_res["title"], llm_res["summary"], item["link"], article_image_url, item["source"],
                    item["pubDate"], llm_res["categories"], llm_res["subcategory"],
                    embedding, content_hash, get_model_name(LLM_PROVIDER), country_code, is_paywalled, ingestion_method)
                    
                    # Log successful ingestion with details
                    final_status = scraper_status
                    if final_status == "SUCCESS" and not article_image_url:
                        final_status = "SUCCESS_NO_IMAGE"
                    await log_ingestion_event(
                        conn, item["link"], final_status, 
                        source_name=item["source"], 
                        error_type="SCRAPER_DEG" if final_status == "DEGRADED" else None,
                        error_message=scraper_error_msg if final_status == "DEGRADED" else None,
                        has_text=True, 
                        has_image=article_image_url is not None,
                        extracted_image_url=article_image_url,
                        content_preview=article_text[:500],
                        resolved_url=scraper_result.get("url")
                    )

                    results["ingested"] += 1
                    logger.info(f"processFeed: Success! {llm_res['title'][:40]}... (Paywalled: {is_paywalled})")
                except Exception as db_err:
                    logger.error(f"processFeed: DB Insert Error: {db_err}")
                    await log_ingestion_event(conn, item["link"], "FAILED", source_name=item["source"], error_type="DB_INSERT_ERROR", error_message=str(db_err))

            except Exception as item_err:
                logger.error(f"processFeed: Item processing error: {item_err}")
                results["errors"] += 1

        # --- Cache Warming ---
        # After successfully ingesting items, we proactively refresh the category caches.
        if results["ingested"] > 0:
            # We don't block ingestion on warming, just spawn it
            # Try to get redis_client from app state or global
            redis_client = None
            try:
                from ..main import app, redis_client as global_redis
                redis_client = getattr(app.state, "redis_client", global_redis)
            except (ImportError, AttributeError):
                pass
            
            asyncio.create_task(warm_category_cache(category, country_code, db_pool, redis_client))

    return results

async def warm_category_cache(category: str, country_code: Optional[str], db_pool, redis_client=None):
    """
    Proactively fetches the latest articles for a category and updates Redis.
    This ensures the 'first user' always hits a warm cache.
    """
    from ..api.feed import ARTICLE_COLUMNS
    
    country_key = country_code or 'all'
    redis_url = os.environ.get("REDIS_URL", "redis://localhost:6379")
    
    try:
        async with db_pool.acquire() as conn:
            where_clauses = []
            params = []
            if category != "all":
                if category == "local" and country_key != 'all':
                    where_clauses.append("country_code = $1")
                    params.append(country_key)
                else:
                    where_clauses.append(f"$1 = ANY(categories)")
                    params.append(category)
            
            where_sql = " WHERE " + " AND ".join(where_clauses) if where_clauses else ""
            query = f"SELECT {ARTICLE_COLUMNS} FROM articles {where_sql} ORDER BY published_at DESC LIMIT 200"
            
            records = await conn.fetch(query, *params)
            result = []
            for record in records:
                r = dict(record)
                r['published_at'] = r['published_at'].isoformat() if r.get('published_at') else None
                r['created_at'] = r['created_at'].isoformat() if r.get('created_at') else None
                r['id'] = str(r['id']) if r.get('id') else None
                result.append(r)

            # Use shared Redis client if provided, else create a short-lived one
            if redis_client:
                await redis_client.set(f"feed:v2:{country_key}:{category}", orjson.dumps(result), ex=10800)
            else:
                import redis.asyncio as redis_lib
                r_client = redis_lib.from_url(redis_url, decode_responses=True)
                await r_client.set(f"feed:v2:{country_key}:{category}", orjson.dumps(result), ex=10800)
                await r_client.close()
            # print(f"[Cache-Warming] Updated cache for {country_key}:{category}")
            
    except Exception as e:
        print(f"[Cache-Warming] Failed for {category}: {e}")

async def orchestrate():
    """
    Background task to orchestrate the ingestion of all feeds.
    """
    from ..main import db_pool
    if not db_pool:
        logger.error("Orchestrator: Database pool not ready.")
        return

    logger.info(f"Orchestrator: Starting orchestration for {len(FEEDS)} feeds")
    
    global SHOULD_STOP_INGESTION
    SHOULD_STOP_INGESTION = False
    
    # 5. Orchestration Sequential Bottleneck: Use controlled concurrency
    semaphore = asyncio.Semaphore(4) # Limit to 4 concurrent feeds to avoid overloading LLM/DB

    async def safe_process(url, cat, bias, country=None, method="rss"):
        if SHOULD_STOP_INGESTION:
            return
        async with semaphore:
            logger.info(f"Orchestrator: Processing: {url} (Method: {method})")
            try:
                await process_feed(url, cat, bias, db_pool, country_code=country, method=method)
            except Exception as e:
                logger.error(f"Orchestrator: Error processing feed {url}: {e}")

    # Create tasks for all global feeds
    tasks = [safe_process(f["feedUrl"], f["defaultCategory"], f["categoryBias"], method=f.get("method", "rss")) for f in FEEDS]
    
    # Add tasks for supported local regions
    for region in SUPPORTED_LOCAL_REGIONS:
        rss_url = build_google_news_rss_url(region["code"], region["lang"])
        tasks.append(safe_process(rss_url, "local", "strong", country=region["code"]))
    
    await asyncio.gather(*tasks)

    logger.info("Orchestrator: Orchestration complete")

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

async def fetch_local_news_on_demand(country_code: str, db_pool):
    """
    Fetches local news for a specific country if not updated recently.
    Called by the feed API.
    """
    country_code = country_code.upper()
    async with db_pool.acquire() as conn:
        # Check if we fetched recently (within last 1 hour)
        last_sync = await conn.fetchrow(
            "SELECT last_fetched_at FROM local_news_sync WHERE country_code = $1", 
            country_code
        )
        
        should_fetch = True
        if last_sync:
            # Check elapsed time
            elapsed = datetime.now(timezone.utc) - last_sync["last_fetched_at"]
            if elapsed.total_seconds() < 3600:
                should_fetch = False
        
        if not should_fetch:
            return
            
        logger.info(f"LocalIngest: Triggering on-demand fetch for {country_code}...")
        rss_url = build_google_news_rss_url(country_code)
        
        # Limit to 10 items for local news to avoid bloat
        # We handle this inside process_feed or parse_rss? parse_rss already limits to 10.
        try:
            # Upsert sync status
            await conn.execute('''
                INSERT INTO local_news_sync (country_code, last_fetched_at)
                VALUES ($1, CURRENT_TIMESTAMP)
                ON CONFLICT (country_code) DO UPDATE SET last_fetched_at = EXCLUDED.last_fetched_at
            ''', country_code)
            
            # Use BackgroundTasks if possible, but for simplicity here we just wait or start task
            # Actually we'll call this in a way that doesn't block the UI.
            await process_feed(rss_url, "local", "strong", db_pool, country_code=country_code)
        except Exception as e:
            logger.error(f"LocalIngest: Error during on-demand fetch for {country_code}: {e}")

async def ingest_from_url(url: str, db_pool, country_code: Optional[str] = None):
    """
    Ingests a single article from a raw URL.
    Useful for 'On-Demand Ingest' from trending signals.
    """
    async with db_pool.acquire() as conn:
        # Check duplicate
        existing = await conn.fetchval("SELECT 1 FROM articles WHERE original_url = $1", url)
        if existing:
            # await log_ingestion_event(conn, url, "SKIPPED", error_type="DUPLICATE_URL")
            return None

        scraper_result = await asyncio.to_thread(scrape_article_sync, url)
        if scraper_result.get("error"):
            await log_ingestion_event(conn, url, "FAILED", error_type="SCRAPER_ERROR", error_message=scraper_result.get("error"))
            return None

        scraped_text = scraper_result.get("text", "")
        if is_scraper_error_page(scraped_text) or count_words(scraped_text) < 75:
            await log_ingestion_event(conn, url, "FAILED", error_type="CONTENT_TOO_SHORT", error_message=f"Content too short: {count_words(scraped_text)} words")
            return None

        # Determine if it's junk
        title = scraper_result.get("title", "News Update")
        junk_reason = is_junk_content(scraped_text, title)
        if junk_reason:
            await log_ingestion_event(conn, url, "FAILED", error_type="SKIPPED_JUNK", error_message=junk_reason)
            return None

        # Summarize
        try:
            # We don't have a category hint here, so we let the LLM decide
            llm_res = await summarize_article(scraped_text, LLM_PROVIDER)
        except Exception as e:
            await log_ingestion_event(conn, url, "FAILED", error_type="LLM_ERROR", error_message=str(e))
            return None

        if llm_res["type"] not in ["hard_news", "analysis"]:
            await log_ingestion_event(conn, url, "FAILED", error_type="LOW_SIGNAL_TYPE")
            return None

        # Embed
        embedding = await embed_text(llm_res["title"] + " " + llm_res["summary"])
        if await is_duplicate(conn, embedding):
            await log_ingestion_event(conn, url, "FAILED", error_type="DUPLICATE_EMBEDDING")
            return None

        # Image
        article_image_url = scraper_result.get("image_url")
        if scraper_result.get("image_bytes"):
            image_file_name = hashlib.sha256(url.encode()).hexdigest()
            persistent_url = await upload_image_sync(scraper_result["image_bytes"], image_file_name)
            if persistent_url:
                article_image_url = persistent_url

        # Since this might be from a trending signal, use the domain as source if unknown
        source_name = scraper_result.get("source") or (re.search(r'https?://([^/]+)', url).group(1) if re.search(r'https?://([^/]+)', url) else "Unknown")
        content_hash = generate_content_hash(url, llm_res["title"])
        
        try:
            # We use a CTE to ensure we get the ID even if it exists.
            result = await conn.fetchrow('''
                INSERT INTO articles (
                    title, summary, original_url, image_url, source_name,
                    published_at, categories, subcategory, embedding, content_hash, 
                    summary_model, country_code, is_paywalled, ingestion_method, created_at
                ) VALUES ($1, $2, $3, $4, $5, NOW(), $6, $7, $8::float8[]::vector, $9, $10, $11, $12, $13, NOW())
                ON CONFLICT (original_url) DO UPDATE SET last_trend_update = NOW() -- Dummy update to trigger RETURNING
                RETURNING id
            ''', 
            llm_res["title"], llm_res["summary"], url, article_image_url, source_name,
            llm_res["categories"], llm_res["subcategory"],
            embedding, content_hash, get_model_name(LLM_PROVIDER), country_code, 
            scraper_result.get("is_paywalled", False), "scraper")
            
            article_id = result["id"] if result else None

            await log_ingestion_event(conn, url, "SUCCESS", source_name=source_name, has_text=True, has_image=article_image_url is not None)
            return article_id
        except Exception as db_err:
            await log_ingestion_event(conn, url, "FAILED", error_type="DB_INSERT_ERROR", error_message=str(db_err))
            return None

