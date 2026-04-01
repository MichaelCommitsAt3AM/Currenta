import os
import re
import orjson
import asyncio
import hashlib
from typing import Optional, List
from datetime import datetime, timezone
from urllib.parse import quote_plus
from bs4 import BeautifulSoup
import httpx
import asyncpg
from supabase import create_client, Client
from .scraper import scrape_article_sync, discover_techcrunch_articles
from dateutil import parser as date_parser
import random
import uuid
from uuid import UUID

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
VOYAGE_API_KEY = os.environ.get("VOYAGE_API_KEY", "")
VOYAGE_EMBED_MODEL = os.environ.get("VOYAGE_EMBED_MODEL", "voyage-3.5-lite")
EMBEDDING_PROVIDER = os.environ.get("EMBEDDING_PROVIDER", "voyage").strip().lower()
OLLAMA_EMBED_MODEL = os.environ.get("OLLAMA_EMBED_MODEL", "nomic-embed-text")

# --- Google Gen-AI Clients (Unified SDK) ---
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")
_gemini_client: genai.Client | None = None
if GEMINI_API_KEY:
    _gemini_client = genai.Client(api_key=GEMINI_API_KEY)

VERTEX_PROJECT = os.environ.get("VERTEX_PROJECT")
VERTEX_LOCATION = os.environ.get("VERTEX_LOCATION", "us-central1")
_vertex_client: genai.Client | None = None
if LLM_PROVIDER == "vertex" or VERTEX_PROJECT:
    try:
        _vertex_client = genai.Client(
            vertexai=True,
            project=VERTEX_PROJECT,  # Can be None when running on GCP with ADC
            location=VERTEX_LOCATION
        )
        logger.info("Vertex AI client initialized for ingestion.")
    except Exception as e:
        logger.warning("Could not initialize Vertex AI client for ingestion: %s", e)

GROQ_API_KEY = os.environ.get("GROQ_API_KEY", "")

SIMILARITY_THRESHOLD = float(os.environ.get("DUPLICATE_SIMILARITY_THRESHOLD", "0.80"))
DUPLICATE_LOOKBACK_DAYS = int(os.environ.get("DUPLICATE_LOOKBACK_DAYS", "7"))

VALID_CATEGORIES = ["politics", "tech", "science", "business", "sports", "entertainment", "health", "world", "environment"]
VALID_LOCAL_RELEVANCE = {"local", "non_local", "uncertain"}

LOCALITY_FILTER_ENABLED = os.environ.get("LOCALITY_FILTER_ENABLED", "1").strip().lower() in {
    "1", "true", "yes", "on"
}
LOCALITY_STRICT_MODE = os.environ.get("LOCALITY_STRICT_MODE", "0").strip().lower() in {
    "1", "true", "yes", "on"
}
LOCALITY_NON_LOCAL_THRESHOLD = float(os.environ.get("LOCALITY_NON_LOCAL_THRESHOLD", "0.70"))
LOCALITY_LOCAL_MIN_CONFIDENCE = float(os.environ.get("LOCALITY_LOCAL_MIN_CONFIDENCE", "0.55"))

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
    { "feedUrl": "https://www.investing.com/rss/news_11.rss", "defaultCategory": "business", "categoryBias": "strong" },
    { "feedUrl": "https://www.businessinsider.com/rss", "defaultCategory": "business", "categoryBias": "strong" },
    { "feedUrl": "https://www.fastcompany.com/latest/rss", "defaultCategory": "business", "categoryBias": "strong" },
    { "feedUrl": "https://economictimes.indiatimes.com/rssfeedstopstories.cms", "defaultCategory": "business", "categoryBias": "strong" },
    # Health
    { "feedUrl": "https://www.who.int/rss-feeds/news-english.xml", "defaultCategory": "health", "categoryBias": "strong" },
    { "feedUrl": "https://medicalxpress.com/feeds/health/", "defaultCategory": "health", "categoryBias": "strong" },
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
    {
        "code": "KE", 
        "lang": "en", 
        "locations": ["Kenya", "Nairobi"]
    },
]

def build_google_news_rss_url(
    country_code: str = "US", 
    language_code: str = "en",
    location: Optional[str] = None
) -> str:
    """
    Builds a localized Google News RSS URL.
    If location is provided, uses the geo-headlines endpoint.
    Example for Kenya: hl=en-KE, gl=KE, ceid=KE:en
    """
    cc = country_code.upper()
    lc = language_code.lower()
    locale_params = f"hl={lc}-{cc}&gl={cc}&ceid={cc}:{lc}"
    
    if location:
        loc = quote_plus(location)
        return f"https://news.google.com/rss/headlines/section/geo/{loc}?{locale_params}"
        
    return f"https://news.google.com/rss?{locale_params}"

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
     *IMPORTANT*: LIVE SPORTS SCORE UPDATES, DAILY NEWS ROUNDUPS, BOOK REVIEWS, "BOOKS IN BRIEF", BUYING GUIDES, SHOPPING GUIDES, PRODUCT ROUNDUPS (e.g., "The Best Bluetooth Trackers"), JOB VACANCIES, RECRUITMENT NOTICES, NOW HIRING ANNOUNCEMENTS, HISTORICAL RETROSPECTIVES (e.g., "On this day in history", "Chart Rewind"), and MULTI-TOPIC SUMMARIES (where several unrelated stories are presented together, e.g., "Tech news: Apple event, Blu-ray sales, and new LG TV") ARE CONSIDERED IRRELEVANT. We only want focused, single-topic, real-world factual articles.
6. **Single-Topic Focus**: If the text contains multiple unrelated news stories (e.g., a "daily roundup", "news in brief", "books in brief", "buying guide", or "what happened today"), you MUST classify the article as "type": "irrelevant". DO NOT attempt to summarize multiple unrelated topics into one summary.
7. **Historical Content**: Historical retrospectives, "today in history", or "chart rewinds" (looking back at old charts/events) MUST be classified as "type": "irrelevant".
8. **Negative Constraint**: Do NOT open with meta-phrases like "The article reports that...", "According to the article...", "This article covers...", or similar. Start directly with the news.

Example of a 64-word summary (Use this density as a template):
"Following a significant technological breakthrough, researchers at the leading national laboratory successfully demonstrated a new quantum computing architecture. This innovative approach utilizes stable silicon-based qubits, drastically reducing error rates compared to previous superconducting models. The team believes this advancement paves the logical path towards commercially viable quantum systems within five years, potentially revolutionizing cryptography, materials science, and complex financial modeling worldwide starting today."

Article to summarize and classify:
"""


def _build_locality_context(country_code: Optional[str]) -> str:
    if not country_code:
        return ""

    cc = country_code.upper().strip()
    region_info = next((r for r in SUPPORTED_LOCAL_REGIONS if r["code"] == cc), None)
    if region_info:
        locs = region_info.get("locations") or []
        loc_hint = ", ".join(locs) if locs else cc
    else:
        loc_hint = cc

    return (
        "\n\nLocal relevance classification is REQUIRED for this run. "
        f"Target country: {cc}. Location hints: {loc_hint}.\n"
        "Add these JSON fields:\n"
        '"local_relevance": "local" | "non_local" | "uncertain",\n'
        '"local_confidence": number from 0.0 to 1.0,\n'
        '"local_reason": brief evidence-based reason (max 20 words).\n'
        "Definitions:\n"
        "- local: the main event happened in the target country OR directly affects residents/institutions there.\n"
        "- non_local: mostly about another country/region with no meaningful local impact.\n"
        "- uncertain: mixed or insufficient evidence."
    )


def _parse_local_confidence(value: Optional[float | int | str]) -> float:
    try:
        conf = float(value)
    except (TypeError, ValueError):
        return 0.0
    if conf < 0.0:
        return 0.0
    if conf > 1.0:
        return 1.0
    return conf


def _passes_locality_gate(llm_res: dict, country_code: Optional[str]) -> tuple[bool, Optional[str]]:
    if not LOCALITY_FILTER_ENABLED or not country_code:
        return True, None

    relevance = str(llm_res.get("local_relevance", "uncertain")).strip().lower()
    confidence = _parse_local_confidence(llm_res.get("local_confidence", 0.0))

    if relevance not in VALID_LOCAL_RELEVANCE:
        relevance = "uncertain"

    if relevance == "non_local" and confidence >= LOCALITY_NON_LOCAL_THRESHOLD:
        return False, (
            f"Locality gate rejected article as non-local "
            f"(confidence={confidence:.2f}, threshold={LOCALITY_NON_LOCAL_THRESHOLD:.2f})."
        )

    if LOCALITY_STRICT_MODE:
        if relevance != "local" or confidence < LOCALITY_LOCAL_MIN_CONFIDENCE:
            return False, (
                f"Strict locality mode rejected article "
                f"(relevance={relevance}, confidence={confidence:.2f}, "
                f"minimum_local_confidence={LOCALITY_LOCAL_MIN_CONFIDENCE:.2f})."
            )

    return True, None

def generate_content_hash(link: str, title: str) -> str:
    s = link + title
    return hashlib.sha256(s.encode('utf-8')).hexdigest()

def calculate_ranking_score(published_at: datetime, trend_score: float = 0.0) -> float:
    """
    Calculates the ranking score based on trend score and time decay.
    Formula: (1.0 + trend_score) * exp(-0.05 * hours_old)
    """
    import math
    now = datetime.now(timezone.utc)
    # Ensure published_at is timezone-aware
    if published_at.tzinfo is None:
        published_at = published_at.replace(tzinfo=timezone.utc)
    
    delta = now - published_at
    hours_old = delta.total_seconds() / 3600.0
    
    # We cap hours_old at 0 to avoid boost for future articles (if any)
    hours_old = max(0.0, hours_old)
    
    return (1.0 + trend_score) * math.exp(-0.05 * hours_old)

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


BETTING_STRONG_SIGNALS = [
    "odds", "bet now", "free bet", "bookmaker", "wager", "parlay", "betting tips",
    "sportsbook", "moneyline", "over/under", "point spread", "best bets", "expert picks",
    "bonus bets", "promo code", "sports betting promo", "betting promo"
]

BETTING_WEAK_SIGNALS = [
    "prediction", "forecast", "stake", "tips"
]

SAFE_CONTEXT_SIGNALS = [
    "oil", "stocks", "gdp", "inflation", "weather", "economy", "market", "analysis", "report", "research",
    "health", "disease", "medical", "treatment", "outbreak", "vaccine", "clinical", "governance", "policy"
]

SPORTS_TERMS = [
    "vs", "match", "fixture", "team", "league", "playoff", "kickoff", "season", "club"
]

BAD_DOMAIN_HINTS = [
    "draftkings", "fanduel", "betmgm", "pointsbet", "bet365", "bovada", "sportsbook", "oddschecker"
]

BETTING_URL_HARD_SIGNALS = [
    "/odds", "-odds-", "/betting", "/sportsbook", "/parlay", "/moneyline",
    "/point-spread", "/wager", "/free-bet", "/bonus-bet", "/promo-code",
    "/expert-picks", "/best-bets"
]

PREDICTION_URL_SIGNALS = [
    "/prediction", "/predictions", "-prediction-", "-predictions-", "/tips", "-tips-", "/picks", "-picks-"
]

SPORTS_URL_CONTEXT_HINTS = [
    "/football/", "/soccer/", "/nba/", "/nfl/", "/mlb/", "/nhl/", "/tennis/", "/cricket/",
    "-vs-", "/vs/", " fixture", "fixtures", "match"
]

SPORTS_PREMATCH_SIGNALS = [
    "/preview", "-preview-", "match-preview", "team-news", "predicted-lineup",
    "starting-xi", "lineups", "kickoff", "kick-off", "how-to-watch", "where-to-watch",
    "live-stream", "head-to-head", "h2h", "fans-attending", "tickets", "clash", "fixture"
]

SPORTS_POSTMATCH_ALLOW_SIGNALS = [
    "result", "results", "wins", "win over", "defeats", "beat", "beaten",
    "recap", "match report", "post-match", "highlights", "reaction"
]

GOOD_DOMAIN_HINTS = [
    "reuters", "bloomberg", "ft.com", "wsj.com", "cnbc.com", "economist", "marketwatch", "apnews",
    "who.int", "cdc.gov", "nih.gov", "un.org", "nature.com", "thelancet.com", "mayoclinic.org", "sciencedaily.com"
]

BETTING_PATTERNS = [
    r"\bvs\b.*\bodds\b",
    r"\bbest bets\b",
    r"\bbetting tips\b",
    r"\bodds\b.*\bprediction\b",
    r"\bmatch\b.*\bprediction\b",
    r"\bgame\b.*\bodds\b"
]

AFFILIATE_DISCLOSURE_SIGNALS = [
    "affiliate link",
    "affiliate disclosure",
    "advertiser disclosure",
    "we may earn a commission",
    "we earn from qualifying purchases"
]

COMMERCIAL_INTENT_SIGNALS = [
    "deal", "deals", "buy now", "shop now", "buying guide", "gift guide",
    "coupon", "promo code", "discount", "best price", "sale", "offers"
]


def _domain_from_url(url: Optional[str]) -> str:
    if not url:
        return ""
    m = re.search(r"https?://([^/]+)", url.lower())
    return m.group(1) if m else ""


def is_sports_prematch_preview_url(url: str, title: str = "", context_text: str = "") -> Optional[str]:
    if not url:
        return None

    url_lc = url.lower()
    title_lc = (title or "").lower()
    context_lc = (context_text or "").lower()
    combined = f" {url_lc} {title_lc} {context_lc} "

    has_prematch_signal = any(sig in combined for sig in SPORTS_PREMATCH_SIGNALS)
    if not has_prematch_signal:
        return None

    has_sports_context = any(sig in combined for sig in [
        " football ", " soccer ", " nba ", " nfl ", " mlb ", " nhl ", " cricket ", " tennis ",
        " match ", " fixture ", " vs ", " club ", " afc ", " fc "
    ])
    has_vs_pattern = bool(re.search(r"\b[a-z0-9][a-z0-9\s\-]{0,30}\bvs\b[a-z0-9][a-z0-9\s\-]{0,30}", combined)) or "-vs-" in url_lc
    has_postmatch_allow = any(sig in combined for sig in SPORTS_POSTMATCH_ALLOW_SIGNALS)

    if (has_sports_context or has_vs_pattern) and not has_postmatch_allow:
        return "Blocked sports pre-match preview URL"

    return None


def is_junk_url(url: str, title: str = "", context_text: str = "") -> Optional[str]:
    """Fast pre-scrape URL filter for betting/prediction junk.

    Keeps this check conservative to avoid false positives on non-sports
    prediction content like weather/economic forecasts.
    """
    if not url:
        return None

    url_lc = url.lower()
    title_lc = (title or "").lower()
    context_lc = (context_text or "").lower()
    domain = _domain_from_url(url_lc)

    if domain and any(bad in domain for bad in BAD_DOMAIN_HINTS):
        return f"Blocked betting domain hint: {domain}"

    for signal in BETTING_URL_HARD_SIGNALS:
        if signal in url_lc:
            return f"Blocked betting URL signal: {signal}"

    has_prediction_signal = any(signal in url_lc for signal in PREDICTION_URL_SIGNALS)
    if has_prediction_signal:
        has_sports_context = (
            any(h in url_lc for h in SPORTS_URL_CONTEXT_HINTS)
            or any(h in title_lc for h in [" vs ", "match", "fixture", "odds", "bet", "picks"])
            or any(h in context_lc for h in [" vs ", "match", "fixture", "odds", "bet", "picks"])
        )
        if has_sports_context:
            return "Blocked sports prediction URL"

    if re.search(r"/[a-z0-9\-]+-vs-[a-z0-9\-]+", url_lc) and any(
        token in url_lc for token in ("odds", "prediction", "predictions", "picks", "tips")
    ):
        return "Blocked head-to-head betting URL pattern"

    prematch_reason = is_sports_prematch_preview_url(url, title, context_text)
    if prematch_reason:
        return prematch_reason

    return None

# ---------------------------------------------------------------------------
# Stage 1: Ingest-time Blocklists (Managed via Supabase)
# ---------------------------------------------------------------------------
class IngestBlocklist:
    def __init__(self):
        self._blocks = []
        self._last_refresh = datetime.min.replace(tzinfo=timezone.utc)
        self._refresh_lock = asyncio.Lock()

    async def _maybe_refresh(self, conn=None):
        now = datetime.now(timezone.utc)
        # Refresh every 10 minutes
        if (now - self._last_refresh).total_seconds() < 600:
            return

        async with self._refresh_lock:
            # Double-check inside lock
            if (datetime.now(timezone.utc) - self._last_refresh).total_seconds() < 600:
                return
            
            try:
                # We use the provided connection if available, otherwise we can't refresh
                if conn:
                    records = await conn.fetch("SELECT pattern, type FROM ingestion_blocks WHERE is_active = true")
                    self._blocks = [dict(r) for r in records]
                    self._last_refresh = datetime.now(timezone.utc)
                    logger.info(f"[Blocklist] Refreshed {len(self._blocks)} active rules.")
            except Exception as e:
                logger.error(f"[Blocklist] Refresh failed: {e}")

    async def is_blocked(self, url: str, conn=None) -> Optional[str]:
        await self._maybe_refresh(conn)
        
        url_lc = url.lower()
        domain = _domain_from_url(url_lc)
        
        for block in self._blocks:
            pattern = block["pattern"].lower()
            btype = block["type"]
            
            if btype == "domain" and (domain == pattern or domain.endswith("." + pattern)):
                return f"Blocked Domain: {pattern}"
            elif btype == "path" and pattern in url_lc:
                return f"Blocked Path Pattern: {pattern}"
            elif btype == "regex":
                try:
                    if re.search(pattern, url_lc):
                        return f"Blocked Regex Pattern: {pattern}"
                except Exception:
                    continue
        return None

BLOCKLIST_MANAGER = IngestBlocklist()

# ---------------------------------------------------------------------------
# Stage 2: Deterministic Feature Extraction (Pre-fetch)
# ---------------------------------------------------------------------------
def is_metadata_junk(item: dict) -> Optional[str]:
    """Checks RSS metadata before fetching content."""
    url = item.get("link", "").lower()
    title = item.get("title", "").lower()
    summary = item.get("description", "").lower()
    
    # URL Slug Patterns (Obvious commercial/junk slugs)
    bad_slugs = [
        "-deals-", "-coupon-", "-promo-", "-giveaway-", "/shop/", "/buy/",
        "/promotions/", "/sponsored-", "-best-of-202", "/best-", "-cheap-",
        "/reviews/buying-guide", "/odds/", "/betting/"
    ]
    for slug in bad_slugs:
        if slug in url:
            return f"Metadata junk slug: {slug}"

    # RSS Category Filtering
    categories = [str(c).lower() for c in item.get("categories", [])]
    junk_categories = ["sponsored", "advertisement", "betting", "gambling", "promo", "deals", "shopping"]
    for cat in categories:
        if any(j in cat for j in junk_categories):
            return f"Metadata junk category: {cat}"

    # Title Patterns (Clickbait/Roundup)
    bad_titles = [
        "best deals", "gift guide", "buying guide", "how to watch", "streaming options",
        "live updates", "live scores", "winners and losers", "today's top stories",
        "news roundup", "morning briefing", "daily digest"
    ]
    for pattern in bad_titles:
        if pattern in title:
            return f"Metadata junk title pattern: {pattern}"

    return None

def _live_blog_reason(title: str, source_url: Optional[str]) -> Optional[str]:
    if not source_url:
        return None

    url = source_url.lower()
    title_lc = (title or "").lower()

    if "skysports.com" in url and "/live-blog/" in url:
        return "Sky Sports live-blog format"

    # Generic fallback for minute-by-minute pages from sports sites.
    sports_site_hints = [
        "skysports.com", "espn.com", "cbssports.com", "goal.com", "90min.com", "talksport.com"
    ]
    if "/live-blog/" in url and any(site in url for site in sports_site_hints):
        return "Sports live-blog URL"

    if "live-blog" in title_lc and any(word in title_lc for word in ["live", "scores", "updates"]):
        return "Live-blog title pattern"

    return None


def _junk_score(text: str, source_url: Optional[str] = None) -> tuple[int, list[str]]:
    score = 0
    reasons: list[str] = []

    # Strong signals
    for phrase in BETTING_STRONG_SIGNALS:
        if phrase in text:
            score += 3
            reasons.append(f"strong:{phrase}")

    # Weak ambiguous signals
    for phrase in BETTING_WEAK_SIGNALS:
        if phrase in text:
            score += 1
            reasons.append(f"weak:{phrase}")

    # Context cancellation for legitimate analytical content
    for phrase in SAFE_CONTEXT_SIGNALS:
        if phrase in text:
            score -= 2
            reasons.append(f"safe:{phrase}")

    # Sports + betting co-occurrence is a strong junk indicator
    has_sports_context = any(term in text for term in SPORTS_TERMS)
    has_betting_context = any(term in text for term in BETTING_STRONG_SIGNALS + ["bet", "odds"])
    if has_sports_context and has_betting_context:
        score += 3
        reasons.append("cooccurrence:sports+betting")

    # Domain reputation
    domain = _domain_from_url(source_url)
    if domain:
        if any(bad in domain for bad in BAD_DOMAIN_HINTS):
            score += 3
            reasons.append(f"bad_domain:{domain}")
        elif any(good in domain for good in GOOD_DOMAIN_HINTS):
            score -= 1
            reasons.append(f"good_domain:{domain}")

    # Pattern-based high precision rules
    for pattern in BETTING_PATTERNS:
        if re.search(pattern, text):
            score += 3
            reasons.append(f"pattern:{pattern}")

    # Generic affiliate disclosures are common site boilerplate. Only score them
    # as junk when commercial intent is also present.
    has_affiliate_disclosure = any(sig in text for sig in AFFILIATE_DISCLOSURE_SIGNALS)
    has_commercial_intent = any(sig in text for sig in COMMERCIAL_INTENT_SIGNALS)
    if has_affiliate_disclosure and has_commercial_intent:
        score += 3
        reasons.append("affiliate+commercial")

    return score, reasons


def _first_matching_phrase(text: str, phrases: list[str]) -> Optional[str]:
    for phrase in phrases:
        if phrase in text:
            return phrase
    return None


def _contextual_betting_reason(text: str) -> Optional[str]:
    tokens = set(re.findall(r"[a-z0-9']+", text))

    betting_core = {
        "bet", "bets", "betting", "sportsbook", "parlay", "moneyline",
        "wager", "wagering", "odds", "bookmaker", "bookmakers", "spread"
    }
    promo_terms = {
        "promo", "bonus", "code", "coupon", "deposit", "freebet", "free", "offer"
    }
    sports_terms = {
        "match", "game", "games", "team", "teams", "player", "players",
        "nfl", "nba", "mlb", "nhl", "soccer", "football", "baseball", "basketball"
    }

    matched_core = sorted([t for t in betting_core if t in tokens])
    has_promo = any(t in tokens for t in promo_terms)
    has_sports = any(t in tokens for t in sports_terms)

    # Promotional betting language is almost always junk for this app.
    if matched_core and has_promo:
        return f"Contextual betting promo: core={matched_core}"

    # Sports + multiple betting terms indicates odds/picks style content.
    if len(matched_core) >= 1 and has_sports and has_promo:
        return f"Contextual betting promo: core={matched_core}"
    
    if len(matched_core) >= 2 and has_sports:
        return f"Contextual betting article: core={matched_core}"
    
    if "vs" in tokens and any(t in tokens for t in ["odds", "spread", "parlay", "moneyline", "wager", "picks"]):
         return f"Sports comparison with betting context: {matched_core}"

    return None

def is_junk_content(text: str, title: str, source_url: Optional[str] = None, published_at: Optional[datetime] = None) -> Optional[str]:
    """Checks for promotional material, betting ads, and low-signal media like podcast summaries."""
    combined = " " + (title + " " + text).lower() + " "

    live_blog_reason = _live_blog_reason(title, source_url)
    if live_blog_reason:
        return f"Matched hard signal: {live_blog_reason}"

    hard_signals = [
        "promo code", "bonus bets", "bonus bet", "sign-up bonus", "sign up bonus",
        "signup bonus", "welcome bonus", "first deposit bonus", "draftkings",
        "fanduel", "betmgm", "caesars sportsbook", "pointsbet", "bet365", "bovada",
        "barstool sportsbook", "sports betting promo", "betting promo",
        "sportsbook promo", "gambling promo", "place a bet", "your first bet",
        "if your first bet", "bet $", "sponsored by", "this is a sponsored",
        "paid partnership",
        "use our promo code", "use code ", "enter code ", "redeem code", "discount code",
        "coupon code", "please gamble responsibly", "responsible gambling",
        "problem gambling helpline", "1-800-gambler", "gambling helpline",
        "bet must be placed", "min. odds", "minimum odds", "-500 odds", "odds req",
        "token and bonus bets", "non-withdrawable",
        "podcast summary", "latest episode", "new episode", "listen to the podcast",
        "listen on apple", "listen on spotify", "subscribe on", "full episode of",
        "this episode of", "bonus episode", "transcript provided",
        "archive page", "daily summary", "weekly roundup", "morning newsletter",
        "evening newsletter", "weekend edition", "today's headlines", "top stories of the week",
        "news roundup", "summary of the day", "what we're reading", "recap", "news in brief",
        "the morning download", "daily briefing", "around the web", "recommended reading",
        "score update", "live update", "game tracker", "live blog", "play-by-play",
        "live scores", "match updates", "live scores and match updates", "live scores match updates",
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
        "mega millions", "powerball", "lottery update", "injury report", "lineup update", "live scoreboard",
        "real-time updates", "minute-by-minute", "live commentary", "full time results", "half-time score",
        " wagering ", " betting odds ", " free picks ", " expert predictions ", " game odds ",
        "mock draft", "how to watch", "tv channel", "streaming options", "where to watch", "live stream",
        "quiz", "trivia", "test your knowledge", "test your skills", "how well do you know", "guess the ", "take our poll", "interactive poll"
    ]
    
    # April Fool's Safeguard: only apply for articles published on April 1st
    if published_at:
        try:
            # Handle both string (if any) and datetime objects
            if isinstance(published_at, str):
                pub_dt = date_parser.parse(published_at)
            else:
                pub_dt = published_at
            
            if pub_dt.month == 4 and pub_dt.day == 1:
                april_signals = ["april fool", "april fools", "april fool's", "this was an april fool", "this is an april fool", " satire ", " satirical "]
                matched_april_signal = _first_matching_phrase(combined, april_signals)
                if matched_april_signal:
                    return f"Matched April Fool's signal: {matched_april_signal}"
        except Exception:
            pass
            
    matched_hard_signal = _first_matching_phrase(combined, hard_signals)
    if matched_hard_signal:
        return f"Matched hard signal: {matched_hard_signal}"

    # Contextual check for betting/sports promo
    betting_reason = _contextual_betting_reason(combined)
    if betting_reason:
        return betting_reason

    # Tiered scoring for betting-like content with context cancellation.
    score, score_reasons = _junk_score(combined, source_url)
    if score >= 3:
        return f"Junk score {score} ({'; '.join(score_reasons[:6])})"

    # Check for multi-topic title patterns (too many unrelated items)
    # Titles like "Apple Event, LG TV, and Blu-ray Sales"
    if title.count(',') >= 2 and (" and " in title.lower() or " & " in title):
        # High probability of being a roundup
        return "Multi-topic title pattern (roundup)"

    soft_signals = [
        "promo", "sweepstakes", "giveaway", "refer a friend",
        "loyalty points", "cash back offer", "podcast summary", "listen on"
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

async def summarize_article(
    text: str,
    provider: str,
    category_hint: Optional[str] = None,
    category_bias: str = "neutral",
    http_client: Optional[httpx.AsyncClient] = None,
    country_code: Optional[str] = None,
    published_at: Optional[datetime] = None,
) -> dict:
    category_context = ""
    if category_hint:
        if category_bias == "strong":
            category_context = f"\nThe source feed is strongly associated with '{category_hint}'. You MUST include '{category_hint}' as the first element of the categories array unless it is completely unrelated. Add other applicable categories after it."
        else:
            category_context = f"\nThe source feed is broadly tagged as '{category_hint}'. Include all categories that genuinely apply; '{category_hint}' should be listed first if applicable."

    locality_context = _build_locality_context(country_code)
    
    full_prompt = f"{SUMMARIZATION_PROMPT}{category_context}{locality_context}\n\nArticle:\n{text}"
    raw_content = ""

    # Recommendation 3: Use shared http_client if provided to reduce connection overhead
    client_ctx = None
    if not http_client:
        client_ctx = httpx.AsyncClient(timeout=90.0)
    
    client = http_client or client_ctx
    try:
        if provider in ("gemini", "vertex"):
            # Use unified SDK for both Gemini (API Studio) and Vertex
            gen_client = _vertex_client if provider == "vertex" else _gemini_client
            if not gen_client:
                raise ValueError(f"Provider '{provider}' is not configured.")

            max_retries = 3
            base_delay = 2.0  # seconds
            
            for attempt in range(max_retries + 1):
                try:
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
                    break
                except Exception as e:
                    err_msg = str(e)
                    # Handle "503 UNAVAILABLE" or "high demand" which is usually transient
                    if attempt < max_retries and ("503" in err_msg or "UNAVAILABLE" in err_msg or "high demand" in err_msg.lower()):
                        delay = base_delay * (2 ** attempt)
                        logger.warning(f"[summarize_article] Gemini API {provider} busy (attempt {attempt+1}/{max_retries}). Retrying in {delay}s...")
                        await asyncio.sleep(delay)
                        continue
                    # Re-raise if we're out of retries or it's a different error
                    raise e

            
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
            
    finally:
        if client_ctx:
            await client_ctx.aclose()

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
        local_relevance = str(parsed.get("local_relevance", "uncertain")).strip().lower()
        if local_relevance not in VALID_LOCAL_RELEVANCE:
            local_relevance = "uncertain"
        local_confidence = _parse_local_confidence(parsed.get("local_confidence", 0.0))
        local_reason = str(parsed.get("local_reason", "")).replace("**", "").strip('"').strip()
        
        return {
            "title": title,
            "summary": summary,
            "categories": categories,
            "type": type_str,
            "subcategory": subcat,
            "local_relevance": local_relevance,
            "local_confidence": local_confidence,
            "local_reason": local_reason,
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

async def embed_text(text: str, http_client: Optional[httpx.AsyncClient] = None) -> list[float]:
    provider = EMBEDDING_PROVIDER
    max_retries = 5
    base_delay = 2.0

    client_ctx = None
    if not http_client:
        client_ctx = httpx.AsyncClient(timeout=60.0)
        
    client = http_client or client_ctx
    try:
        if provider == "voyage":
            if not VOYAGE_API_KEY:
                raise ValueError("VOYAGE_API_KEY is required when EMBEDDING_PROVIDER=voyage.")
            
            for attempt in range(max_retries + 1):
                try:
                    res = await client.post(
                        "https://api.voyageai.com/v1/embeddings",
                        headers={
                            "Authorization": f"Bearer {VOYAGE_API_KEY}",
                            "Content-Type": "application/json",
                        },
                        json={"model": VOYAGE_EMBED_MODEL, "input": [text], "input_type": "document"}
                    )
                    
                    if res.status_code == 429:
                        if attempt < max_retries:
                            import random
                            delay = base_delay * (2 ** attempt) + random.uniform(0, 1)
                            logger.warning(f"[embed_text] Voyage AI rate limit hit (429). Retrying in {delay:.2f}s... (Attempt {attempt+1}/{max_retries})")
                            await asyncio.sleep(delay)
                            continue
                        else:
                            logger.error(f"[embed_text] Voyage AI rate limit hit (429) and exhausted retries.")
                            res.raise_for_status()
                    
                    res.raise_for_status()
                    data = res.json()
                    embedding = data["data"][0]["embedding"]
                    return [float(x) for x in embedding]
                    
                except httpx.HTTPStatusError as e:
                    if e.response.status_code == 429:
                        # Handled above, but just in case raise_for_status was called
                        if attempt < max_retries:
                            continue
                        raise e
                    raise e
                except (httpx.ConnectError, httpx.TimeoutException) as e:
                    if attempt < max_retries:
                        delay = base_delay * (2 ** attempt)
                        logger.warning(f"[embed_text] Connection/Timeout error: {e}. Retrying in {delay:.2f}s...")
                        await asyncio.sleep(delay)
                        continue
                    raise e


            raise ValueError(f"Unsupported EMBEDDING_PROVIDER: {provider}")

        elif provider == "local":
            # Ollama / Local Embedding
            for attempt in range(max_retries + 1):
                try:
                    # Note: Using the base endpoint and appending /embeddings or /v1/embeddings.
                    # Ollama's /v1/embeddings is OpenAI-compatible if LOCAL_LLM_BASE_URL points to /v1.
                    res = await client.post(
                        f"{LOCAL_LLM_BASE_URL}/embeddings",
                        headers={"Content-Type": "application/json", "ngrok-skip-browser-warning": "true"},
                        json={
                            "model": OLLAMA_EMBED_MODEL,
                            "input": text
                        }
                    )
                    res.raise_for_status()
                    data = res.json()
                    # OpenAI /v1 format: {"data": [{"embedding": [...]}]}
                    embedding = data["data"][0]["embedding"]
                    return [float(x) for x in embedding]
                except (httpx.ConnectError, httpx.TimeoutException, httpx.HTTPStatusError) as e:
                    if attempt < max_retries:
                        delay = base_delay * (2 ** attempt)
                        logger.warning(f"[embed_text] Local (Ollama) error: {e}. Retrying in {delay:.2f}s...")
                        await asyncio.sleep(delay)
                        continue
                    raise e

        raise ValueError(f"Unsupported EMBEDDING_PROVIDER: {provider}")
    
    finally:
        if client_ctx:
            await client_ctx.aclose()

async def upload_image_sync(image_bytes: bytes, file_name: str) -> str | None:
    if not supabase_client:
        print("[Image-Storage] CRITICAL: Supabase client not initialized. Cannot upload.")
        return None
        
    file_path = f"covers/{file_name}.jpg"
    max_retries = 3
    base_delay = 2.0

    def _is_transient_upload_error(exc: Exception) -> bool:
        err_msg = str(exc).lower()
        transient_signatures = [
            "544",
            "504",
            "502",
            "503",
            "429",
            "timeout",
            "time out",
            "databasetimeout",
            "server disconnected",
            "connection reset",
            "temporarily unavailable",
            "remoteprotocolerror",
        ]
        if any(sig in err_msg for sig in transient_signatures):
            return True

        return isinstance(
            exc,
            (
                httpx.RemoteProtocolError,
                httpx.ReadError,
                httpx.ConnectError,
                httpx.TimeoutException,
            ),
        )
    
    for attempt in range(max_retries + 1):
        try:
            # Use asyncio.to_thread to avoid blocking the event loop — the SDK's storage calls are synchronous.
            def _do_upload():
                return supabase_client.storage.from_("article-images").upload(
                    file_path,
                    image_bytes,
                    file_options={"content-type": "image/jpeg", "upsert": "true"}
                )
            
            await asyncio.to_thread(_do_upload)
            
            # Generated locally by the SDK based on base URL and path
            public_url = supabase_client.storage.from_("article-images").get_public_url(file_path)
            return public_url
            
        except Exception as e:
            err_msg = str(e)
            # Handle transient edge/network/platform errors with retry.
            is_transient = _is_transient_upload_error(e)
            
            if attempt < max_retries and is_transient:
                delay = base_delay * (2 ** attempt) + random.uniform(0, 1)
                logger.warning(f"[Image-Storage] Upload transient error (attempt {attempt+1}/{max_retries}): {err_msg}. Retrying in {delay:.2f}s...")
                await asyncio.sleep(delay)
                continue

            logger.error(f"[Image-Storage] Error during upload to Supabase: {type(e).__name__} - {e}")
            if not is_transient:
                 # For non-transient errors (like bucket not found, auth error), don't retry and just stop.
                 break
    
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
        non_article_paths = ["/tag/", "/category/", "/author/", "/archives/", "/labels/", "/search/", "/video-clips/", "/video/quotable/", "/video/", "/live-blog/"]
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

async def find_cluster_match(conn, embedding: list[float]) -> tuple[Optional[UUID], Optional[float], Optional[UUID]]:
    """
    Finds the best recent semantic candidate and applies the configured threshold.
    Returns (matched_cluster_id, best_similarity, best_match_article_id).
    matched_cluster_id is None when best_similarity is below threshold.
    """
    try:
        records = await conn.fetch(
            """
            SELECT
                id,
                cluster_id,
                1 - (embedding <=> $1::float8[]::vector) AS similarity
            FROM articles
            WHERE published_at > (now() - make_interval(days => $2::int))
            ORDER BY embedding <=> $1::float8[]::vector
            LIMIT 1
            """,
            embedding, DUPLICATE_LOOKBACK_DAYS
        )
        if records:
            best_match_id = records[0]["id"]
            best_cluster_id = records[0]["cluster_id"]
            best_similarity = float(records[0]["similarity"])
            if best_similarity >= SIMILARITY_THRESHOLD:
                # If the matching article has no cluster_id yet, use its own ID as the cluster root.
                return best_cluster_id or best_match_id, best_similarity, best_match_id
            return None, best_similarity, best_match_id
        return None, None, None
    except Exception as e:
        logger.error("[Cluster Match] error: %s", e)
        return None, None, None

def get_model_name(provider: str) -> str:
    if provider in ("gemini", "vertex"): return "gemini-2.5-flash-lite"
    if provider == "groq": return "llama-3.3-70b-versatile"
    return LOCAL_LLM_MODEL

async def log_ingestion_event(
    conn,
    url,
    status,
    trigger_source=None,
    source_name=None,
    error_type=None,
    error_message=None,
    has_text=False,
    has_image=False,
    extracted_image_url=None,
    content_preview=None,
    resolved_url=None,
    dedup_stage=None,
    dedup_decision=None,
    semantic_similarity=None,
    similarity_threshold=None,
    matched_article_id=None,
    matched_cluster_id=None,
):
    try:
        await conn.execute('''
            INSERT INTO ingestion_logs (
                original_url, status, trigger_source, source_name, dedup_stage, dedup_decision,
                semantic_similarity, similarity_threshold, matched_article_id, matched_cluster_id,
                error_type, error_message, has_text, has_image,
                extracted_image_url, content_preview, resolved_url
            ) VALUES (
                $1, $2, $3, $4, $5, $6,
                $7, $8, $9, $10,
                $11, $12, $13, $14,
                $15, $16, $17
            )
        ''',
        url,
        status,
        trigger_source,
        source_name,
        dedup_stage,
        dedup_decision,
        semantic_similarity,
        similarity_threshold,
        matched_article_id,
        matched_cluster_id,
        error_type,
        error_message,
        has_text,
        has_image,
        extracted_image_url,
        content_preview[:500] if content_preview else None,
        resolved_url,
    )
    except Exception as e:
        logger.warning("Failed to write to ingestion_logs: %s", e)

async def process_feed(feed_url: str, category: str, category_bias: str = "neutral", db_pool=None, country_code: Optional[str] = None, method: str = "rss", http_client: Optional[httpx.AsyncClient] = None):
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
                await log_ingestion_event(
                    conn,
                    item["link"],
                    "SKIPPED",
                    source_name=item.get("source"),
                    error_type="DUPLICATE_URL_OR_HASH",
                    error_message="Skipped because URL or content hash already exists in articles table."
                )
                results["skipped"] += 1
                continue

            # Stage 1: Blocklist Check (Pre-fetch)
            block_reason = await BLOCKLIST_MANAGER.is_blocked(item["link"], conn=conn)
            if block_reason:
                await log_ingestion_event(conn, item["link"], "SKIPPED", source_name=item.get("source"), error_type="BLOCKLISTED", error_message=block_reason)
                results["skipped"] += 1
                continue

            # Stage 2: Metadata Junk Check (Pre-fetch)
            meta_junk_reason = is_metadata_junk(item)
            if meta_junk_reason:
                await log_ingestion_event(conn, item["link"], "SKIPPED", source_name=item.get("source"), error_type="METADATA_JUNK", error_message=meta_junk_reason)
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

                junk_reason = is_junk_content(article_text, item["title"], item["link"], published_at=item.get("pubDate"))
                if junk_reason:
                    await log_ingestion_event(conn, item["link"], "FAILED", source_name=item["source"], error_type="SKIPPED_JUNK", error_message=junk_reason)
                    results["skipped"] += 1
                    continue

                # Summarize
                try:
                    llm_res = await summarize_article(
                        article_text,
                        LLM_PROVIDER,
                        category,
                        category_bias,
                        http_client=http_client,
                        country_code=country_code,
                        published_at=item.get("pubDate"),
                    )
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
                    await log_ingestion_event(
                        conn,
                        item["link"],
                        "SKIPPED",
                        source_name=item.get("source"),
                        error_type="LOW_SIGNAL_TITLE",
                        error_message="LLM returned generic fallback title 'News Update'."
                    )
                    results["skipped"] += 1
                    continue

                allowed_types = ["hard_news", "analysis"]
                if llm_res["type"] not in allowed_types:
                    await log_ingestion_event(
                        conn,
                        item["link"],
                        "SKIPPED",
                        source_name=item.get("source"),
                        error_type="LOW_SIGNAL_TYPE",
                        error_message=f"LLM type '{llm_res['type']}' is not allowed."
                    )
                    results["skipped"] += 1
                    continue

                locality_ok, locality_message = _passes_locality_gate(llm_res, country_code)
                if not locality_ok:
                    await log_ingestion_event(
                        conn,
                        item["link"],
                        "SKIPPED",
                        source_name=item.get("source"),
                        error_type="LOW_LOCAL_RELEVANCE",
                        error_message=locality_message,
                    )
                    results["skipped"] += 1
                    continue

                embedding = await embed_text(llm_res["title"] + " " + llm_res["summary"], http_client=http_client)
                
                # Check for semantic duplicate using the same connection
                # --- Clustering & Deduplication ---
                matched_cluster_id, best_similarity, best_match_id = await find_cluster_match(conn, embedding)
                if matched_cluster_id:
                    # In this robust implementation, we skip duplicates to keep the primary feed high-signal.
                    # We could also save them with the same cluster_id if we wanted to show 'Other Sources'.
                    logger.info(
                        "[Ingest] Skipping duplicate: Article similar to cluster %s (similarity=%.4f, threshold=%.2f, best_match=%s)",
                        matched_cluster_id,
                        best_similarity if best_similarity is not None else 0.0,
                        SIMILARITY_THRESHOLD,
                        best_match_id,
                    )
                    await log_ingestion_event(
                        conn,
                        item["link"],
                        "SKIPPED",
                        source_name=item.get("source"),
                        dedup_stage="semantic",
                        dedup_decision="skipped",
                        semantic_similarity=best_similarity,
                        similarity_threshold=SIMILARITY_THRESHOLD,
                        matched_article_id=best_match_id,
                        matched_cluster_id=matched_cluster_id,
                        error_type="DUPLICATE_EMBEDDING",
                        error_message=(
                            f"Skipped because semantic similarity exceeded threshold ({SIMILARITY_THRESHOLD}). "
                            f"Matched cluster {matched_cluster_id}. Matched article {best_match_id}. "
                            f"Best similarity: {best_similarity:.4f}"
                        ) if best_similarity is not None else (
                            f"Skipped because semantic similarity exceeded threshold ({SIMILARITY_THRESHOLD}). "
                            f"Matched cluster {matched_cluster_id}. Matched article {best_match_id}."
                        )
                    )
                    results["skipped"] += 1
                    continue
                if best_similarity is not None:
                    logger.info(
                        "[Ingest] Kept article after semantic check: best recent similarity=%.4f below threshold=%.2f (best_match=%s)",
                        best_similarity,
                        SIMILARITY_THRESHOLD,
                        best_match_id,
                    )
                
                # New story: assign a fresh cluster_id (using the article's own ID as root)
                article_id = uuid.uuid4() # Generate a new UUID for the article
                target_cluster_id = article_id # Primary article is its own cluster root

                # Insert using the same connection
                try:
                    # Determine ingestion method for analysis
                    ingestion_method = "scraper" if scraper_status == "SUCCESS" else "rss"
                    ranking_score = calculate_ranking_score(item["pubDate"], 0.0)
                    
                    # Extract variables for clarity and new insert statement
                    link = item["link"]
                    image = article_image_url
                    source_name = item["source"]
                    # Assuming source_favicon_url might be available in item or derived
                    favicon_url = item.get("source_favicon_url") # Placeholder, adjust as needed
                    item_pub_date = item["pubDate"]
                    categories = llm_res["categories"]
                    subcategory = llm_res["subcategory"]

                    await conn.execute(
                    '''
                    INSERT INTO articles (
                        id, title, summary, original_url, image_url, source_name, source_favicon_url,
                        published_at, categories, subcategory, embedding, content_hash, 
                        summary_model, country_code, is_paywalled, ingestion_method, cluster_id
                    )
                    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11::float8[]::vector, $12, $13, $14, $15, $16, $17)
                    ON CONFLICT (original_url) DO NOTHING
                    ''',
                    article_id, llm_res["title"], llm_res["summary"], link, image, source_name, favicon_url,
                    item_pub_date, categories, subcategory, embedding, content_hash, 
                    get_model_name(LLM_PROVIDER), country_code, is_paywalled, ingestion_method, target_cluster_id
                )
                    
                    # Log successful ingestion with details
                    final_status = scraper_status
                    if final_status == "SUCCESS" and not article_image_url:
                        final_status = "SUCCESS_NO_IMAGE"
                    await log_ingestion_event(
                        conn, item["link"], final_status, 
                        source_name=item["source"], 
                        dedup_stage="semantic",
                        dedup_decision="kept",
                        semantic_similarity=best_similarity,
                        similarity_threshold=SIMILARITY_THRESHOLD if best_similarity is not None else None,
                        matched_article_id=best_match_id,
                        matched_cluster_id=None,
                        error_type="SCRAPER_DEG" if final_status == "DEGRADED" else None,
                        error_message=scraper_error_msg if final_status == "DEGRADED" else None,
                        has_text=True, 
                        has_image=article_image_url is not None,
                        extracted_image_url=article_image_url,
                        content_preview=article_text[:500],
                        resolved_url=scraper_result.get("url")
                    )

                    # Keep in-memory dedupe state current for this same ingestion run.
                    existing_urls.add(link)
                    existing_hashes.add(content_hash)

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
            query = f"SELECT {ARTICLE_COLUMNS} FROM articles {where_sql} ORDER BY ranking_score DESC LIMIT 150"
            
            records = await conn.fetch(query, *params)
            result = []
            for record in records:
                r = dict(record)
                r['published_at'] = r['published_at'].isoformat() if r.get('published_at') else None
                r['created_at'] = r['created_at'].isoformat() if r.get('created_at') else None
                r['id'] = str(r['id']) if r.get('id') else None
                r['cluster_id'] = str(r['cluster_id']) if r.get('cluster_id') else None
                result.append(r)

            # Use shared Redis client if provided, else create a short-lived one
            if redis_client:
                await redis_client.set(f"feed:v4:{country_key}:{category}", orjson.dumps(result), ex=10800)
            else:
                import redis.asyncio as redis_lib
                r_client = redis_lib.from_url(redis_url, decode_responses=True)
                await r_client.set(f"feed:v4:{country_key}:{category}", orjson.dumps(result), ex=10800)
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
    
    # 5. Orchestration Concurrency: Increased to 8 (Audit Recommendation)
    semaphore = asyncio.Semaphore(8) 

    async def safe_process(url, cat, bias, country=None, method="rss", client=None):
        if SHOULD_STOP_INGESTION:
            return
        async with semaphore:
            logger.info(f"Orchestrator: Processing: {url} (Method: {method})")
            try:
                await process_feed(url, cat, bias, db_pool, country_code=country, method=method, http_client=client)
            except Exception as e:
                logger.error(f"Orchestrator: Error processing feed {url}: {e}")

    # Recommendation 3: Use a single shared client for the entire run
    async with httpx.AsyncClient(timeout=90.0) as shared_client:
        # Create tasks for all global feeds
        tasks = [safe_process(f["feedUrl"], f["defaultCategory"], f["categoryBias"], method=f.get("method", "rss"), client=shared_client) for f in FEEDS]
        
        # Add tasks for supported local regions
        for region in SUPPORTED_LOCAL_REGIONS:
            locations = region.get("locations", [None])
            lang = region.get("lang", "en")
            for loc in locations:
                rss_url = build_google_news_rss_url(region["code"], lang, location=loc)
                tasks.append(safe_process(rss_url, "local", "strong", country=region["code"], client=shared_client))
        
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
        
    # Default category to 'world' if not provided
    cat = category_hint or 'world'
    await process_feed(feed_url, cat, "neutral", db_pool)

async def flush_view_buffer(db_pool: asyncpg.Pool, redis_client):
    """
    Audit Recommendation: Persist article views from Redis buffer in batches.
    Runs every 60 seconds via scheduler.
    """
    if not redis_client or not db_pool:
        return

    # Pop up to 1000 items from the buffer
    views = []
    try:
        # Format: "user_id:article_id"
        raw_views = await redis_client.lpop("pending_view_buffer", 1000)
        if not raw_views:
            return
        
        # aioredis/redis-py might return a list or a single string depending on version and count param
        if isinstance(raw_views, str):
            views = [raw_views]
        else:
            views = raw_views
            
    except Exception as e:
        logger.warning("[View-Flush] Failed to pop views from Redis: %s", e)
        return

    if not views:
        return

    # De-duplicate views in this batch to reduce DB work further
    unique_views = set(views)
    
    from uuid import UUID
    parsed_views = []
    for v in unique_views:
        try:
            uid_str, aid_str = v.split(":", 1)
            parsed_views.append((UUID(uid_str), UUID(aid_str)))
        except (ValueError, AttributeError):
            continue

    if not parsed_views:
        return

    logger.info("[View-Flush] Flushing %d article views to database", len(parsed_views))
    
    try:
        async with db_pool.acquire() as conn:
            # Batch insert using executemany. We use a subquery to ensure the article exists,
            # preventing foreign key violations from failing the entire batch.
            await conn.executemany(
                """
                INSERT INTO article_views (user_id, article_id)
                SELECT v.uid, v.aid 
                FROM (SELECT $1::uuid AS uid, $2::uuid AS aid) v
                WHERE EXISTS (SELECT 1 FROM articles WHERE id = v.aid)
                ON CONFLICT (user_id, article_id) DO NOTHING
                """,
                parsed_views
            )
    except Exception as e:
        logger.error("[View-Flush] Failed to flush views to database: %s", e)

async def fetch_local_news_on_demand(country_code: str, db_pool):
    """
    Fetches local news for a specific country if not updated recently.
    Called by the feed API.
    """
    country_code = country_code.upper()
    if len(country_code) != 2:
        logger.warning(f"LocalIngest: Invalid country_code '{country_code}' for on-demand fetch. Skipping.")
        return

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
        
        region_info = next((r for r in SUPPORTED_LOCAL_REGIONS if r["code"] == country_code), None)
        locations = region_info.get("locations", [None]) if region_info else [None]
        lang = region_info.get("lang", "en") if region_info else "en"

        try:
            # Upsert sync status
            await conn.execute('''
                INSERT INTO local_news_sync (country_code, last_fetched_at)
                VALUES ($1, CURRENT_TIMESTAMP)
                ON CONFLICT (country_code) DO UPDATE SET last_fetched_at = EXCLUDED.last_fetched_at
            ''', country_code)
            
            # Use BackgroundTasks if possible, but for simplicity here we just wait or start task
            # Actually we'll call this in a way that doesn't block the UI.
            for loc in locations:
                rss_url = build_google_news_rss_url(country_code, lang, location=loc)
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
            await log_ingestion_event(
                conn,
                url,
                "SKIPPED",
                error_type="DUPLICATE_URL",
                error_message="Skipped because URL already exists in articles table."
            )
            return None

        # Fast URL-level junk gate before any network-heavy scraping.
        junk_url_reason = is_junk_url(url)
        if junk_url_reason:
            await log_ingestion_event(conn, url, "SKIPPED", error_type="SKIPPED_JUNK_URL", error_message=junk_url_reason)
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
        pub_date = scraper_result.get("published_at")
        junk_reason = is_junk_content(scraped_text, title, url, published_at=pub_date)
        if junk_reason:
            await log_ingestion_event(conn, url, "FAILED", error_type="SKIPPED_JUNK", error_message=junk_reason)
            return None

        # Summarize
        try:
            # We don't have a category hint here, so we let the LLM decide
            llm_res = await summarize_article(
                scraped_text, LLM_PROVIDER, country_code=country_code, published_at=pub_date
            )
        except Exception as e:
            await log_ingestion_event(conn, url, "FAILED", error_type="LLM_ERROR", error_message=str(e))
            return None

        if llm_res["type"] not in ["hard_news", "analysis"]:
            await log_ingestion_event(
                conn,
                url,
                "SKIPPED",
                error_type="LOW_SIGNAL_TYPE",
                error_message=f"LLM type '{llm_res['type']}' is not allowed."
            )
            return None

        locality_ok, locality_message = _passes_locality_gate(llm_res, country_code)
        if not locality_ok:
            await log_ingestion_event(
                conn,
                url,
                "SKIPPED",
                error_type="LOW_LOCAL_RELEVANCE",
                error_message=locality_message,
            )
            return None

        # Embed
        embedding = await embed_text(llm_res["title"] + " " + llm_res["summary"])
        matched_cluster_id, best_similarity, best_match_id = await find_cluster_match(conn, embedding)
        if matched_cluster_id:
            await log_ingestion_event(
                conn,
                url,
                "SKIPPED",
                dedup_stage="semantic",
                dedup_decision="skipped",
                semantic_similarity=best_similarity,
                similarity_threshold=SIMILARITY_THRESHOLD,
                matched_article_id=best_match_id,
                matched_cluster_id=matched_cluster_id,
                error_type="DUPLICATE_EMBEDDING",
                error_message=(
                    f"Skipped because semantic similarity exceeded threshold ({SIMILARITY_THRESHOLD}). "
                    f"Matched cluster {matched_cluster_id}. Matched article {best_match_id}. "
                    f"Best similarity: {best_similarity:.4f}"
                ) if best_similarity is not None else (
                    f"Skipped because semantic similarity exceeded threshold ({SIMILARITY_THRESHOLD}). "
                    f"Matched cluster {matched_cluster_id}. Matched article {best_match_id}."
                )
            )
            return None
        if best_similarity is not None:
            logger.info(
                "[Ingest URL] Kept article after semantic check: best recent similarity=%.4f below threshold=%.2f (best_match=%s)",
                best_similarity,
                SIMILARITY_THRESHOLD,
                best_match_id,
            )
        
        # New cluster root
        article_id = uuid.uuid4()
        target_cluster_id = article_id

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
            ranking_score = calculate_ranking_score(datetime.now(timezone.utc), 0.0)

            # We use a CTE to ensure we get the ID even if it exists.
            result = await conn.fetchrow('''
                INSERT INTO articles (
                    title, summary, original_url, image_url, source_name,
                    published_at, categories, subcategory, embedding, content_hash, 
                    summary_model, country_code, is_paywalled, ingestion_method, created_at,
                    ranking_score
                ) VALUES ($1, $2, $3, $4, $5, NOW(), $6, $7, $8::float8[]::vector, $9, $10, $11, $12, $13, NOW(), $14)
                ON CONFLICT (original_url) DO UPDATE SET last_trend_update = NOW() -- Dummy update to trigger RETURNING
                RETURNING id
            ''', 
            llm_res["title"], llm_res["summary"], url, article_image_url, source_name,
            llm_res["categories"], llm_res["subcategory"],
            embedding, content_hash, get_model_name(LLM_PROVIDER), country_code, 
            scraper_result.get("is_paywalled", False), "scraper", ranking_score)
            
            article_id = result["id"] if result else None

            await log_ingestion_event(
                conn,
                url,
                "SUCCESS",
                source_name=source_name,
                dedup_stage="semantic",
                dedup_decision="kept",
                semantic_similarity=best_similarity,
                similarity_threshold=SIMILARITY_THRESHOLD if best_similarity is not None else None,
                matched_article_id=best_match_id,
                has_text=True,
                has_image=article_image_url is not None,
            )
            return article_id
        except Exception as db_err:
            await log_ingestion_event(conn, url, "FAILED", error_type="DB_INSERT_ERROR", error_message=str(db_err))
            return None
