import asyncio
from dataclasses import dataclass, field
from typing import Optional
from datetime import datetime

from backend.services import ingestion
from backend.services.scraper import scrape_article_sync


ARTICLE_URL = (
    "https://news.google.com/rss/articles/"
    "CBMizwFBVV95cUxOLTRwNkh4aGNRT2JSRnVOR004Z185VVJObEt0Y0J4UTBzbmZ4VDVGdm5k"
    "WndXaWRpR1lxOUJkWUY1N1NtU2VzSmx6RDVhZ0VDVW5JczI2dlFacGtRWVJzTVM4cnRMU2RwaXFS"
    "WmNlWkFQVy1SRC1HdkFaMXlyZkJTMG91S3VZYi1kX21SNDNDZXNxYTFQSzh1aFRaNzE5azZFS3cy"
    "NUJZQzkxSFFhVXpaTmt1U3RPWHdTdHdKMWhBM3NJQTlYTV80SC1EYmtrdFnSAbsBQVVfeXFMTmVW"
    "a1FJVG4wR1NvbEtPTUdnbTdJMFE1UzNRQmhGdm1Vd1NOTFBmNVpPZTZibmc3ZmpnSlFuc1FQNEVo"
    "SGlTQUtmWU9jdGpCdTFzOTl3MGNVVDhvWkRTb0xnZ3RWcEtOek9iZWQ4TVlScWx6YUpPRnlNZVAy"
    "bzBJeFpDMjNDZWtGaFRWaTlTM1h5N0dhWmtTRXdsSUhFMHdocXk1UzF0ZGNOcmcwTmtUVEYzTDhJ"
    "Z0Y1S0xBSQ?oc=5"
)


def test_google_news_scraping_smoke():
    """Validates that the provided Google News URL can be scraped end-to-end."""
    result = scrape_article_sync(ARTICLE_URL)

    assert "error" not in result, f"Scraper failed: {result.get('error')}"
    assert isinstance(result.get("text"), str) and len(result["text"]) > 200
    assert isinstance(result.get("title"), str) and len(result["title"].strip()) > 0
    assert isinstance(result.get("url"), str) and result["url"].startswith("http")


@dataclass
class FakeConn:
    duplicate_url: bool = False
    inserted_rows: list[tuple[str, tuple]] = field(default_factory=list)
    log_rows: list[tuple[str, tuple]] = field(default_factory=list)

    async def fetchval(self, query, *args):
        if "SELECT 1 FROM articles WHERE original_url" in query:
            return 1 if self.duplicate_url else None
        return None

    async def fetch(self, query, *args):
        if "match_recent_articles" in query:
            return []
        return []

    async def fetchrow(self, query, *args):
        self.inserted_rows.append((query, args))
        return {"id": "integration-article-1"}

    async def execute(self, query, *args):
        self.log_rows.append((query, args))
        return "INSERT 0 1"


class _AcquireCtx:
    def __init__(self, conn: FakeConn):
        self._conn = conn

    async def __aenter__(self):
        return self._conn

    async def __aexit__(self, exc_type, exc, tb):
        return False


class FakePool:
    def __init__(self, conn: FakeConn):
        self._conn = conn

    def acquire(self):
        return _AcquireCtx(self._conn)


def test_ingest_single_google_news_article_pipeline(monkeypatch):
    """
    Integration-style test that validates one article goes through:
    scraping -> summarization -> embedding -> DB insert.
    """
    stage_flags = {
        "scraped": False,
        "summarized": False,
        "embedded": False,
    }

    # Keep this test deterministic in CI by stubbing expensive/remote stages
    # while still using a Google News URL and validating resolver integration.
    def fake_scrape(url: str):
        from backend.services.scraper import resolve_google_news_url

        stage_flags["scraped"] = True
        resolved = resolve_google_news_url(url)
        return {
            "text": (
                "Kenya technology regulators announced a new framework for AI startups, "
                "focusing on accountability, safety testing, and transparent disclosures. "
                "Investors said the policy could accelerate responsible innovation while "
                "keeping consumer trust high across finance, education, and healthcare sectors. "
                "The framework introduces pre-deployment risk assessments, mandatory incident reporting, "
                "and periodic independent audits for high-impact systems. Officials said the approach "
                "balances growth and public safety while helping startups enter regulated markets faster. "
                "Industry groups welcomed clearer compliance rules and said the policy may attract regional "
                "capital for trustworthy AI products."
            ),
            "title": "Kenya outlines AI startup safety framework",
            "image_url": None,
            "image_bytes": None,
            "url": resolved,
            "original_url": url,
            "is_paywalled": False,
        }

    async def fake_summarize(
        text: str,
        provider: str,
        category_hint: Optional[str] = None,
        category_bias: str = "neutral",
        http_client=None,
        country_code: Optional[str] = None,
        published_at: Optional[datetime] = None,
    ):
        stage_flags["summarized"] = True
        assert len(text.split()) >= 30
        assert country_code == "KE"
        return {
            "title": "Kenya issues AI safety policy for startups",
            "summary": (
                "Kenya introduced new rules requiring AI startups to run safety checks, "
                "publish model limitations, and implement accountability controls before deployment."
            ),
            "categories": ["tech", "business"],
            "subcategory": "AI Policy",
            "type": "hard_news",
            "local_relevance": "local",
            "local_confidence": 0.92,
            "local_reason": "Policy and institutions are in Kenya.",
        }

    async def fake_embed(text: str):
        stage_flags["embedded"] = True
        assert "Kenya" in text
        return [0.01, 0.11, 0.21, 0.31]

    monkeypatch.setattr(ingestion, "scrape_article_sync", fake_scrape)
    monkeypatch.setattr(ingestion, "summarize_article", fake_summarize)
    monkeypatch.setattr(ingestion, "embed_text", fake_embed)

    conn = FakeConn()
    pool = FakePool(conn)

    article_id = asyncio.run(ingestion.ingest_from_url(ARTICLE_URL, pool, country_code="KE"))

    assert article_id == "integration-article-1"
    assert stage_flags["scraped"] is True
    assert stage_flags["summarized"] is True
    assert stage_flags["embedded"] is True

    assert len(conn.inserted_rows) == 1
    insert_query, insert_args = conn.inserted_rows[0]
    assert "INSERT INTO articles" in insert_query
    assert insert_args[3] == ARTICLE_URL
    assert insert_args[6] == ["tech", "business"]
    assert insert_args[8] == [0.01, 0.11, 0.21, 0.31]

    success_logs = [row for row in conn.log_rows if "ingestion_logs" in row[0] and row[1][1] == "SUCCESS"]
    assert len(success_logs) >= 1


def test_ingest_single_google_news_article_skips_high_confidence_non_local(monkeypatch):
    """Local ingestion should reject high-confidence non-local stories."""

    def fake_scrape(url: str):
        return {
            "text": (
                "US lawmakers debated AI antitrust policy in Washington, focusing on domestic competition, "
                "federal enforcement powers, and U.S.-only compliance obligations. "
                "The hearing addressed impacts on American agencies and companies, with no material references "
                "to Kenyan institutions, residents, regulations, markets, or public services. "
                "Witnesses emphasized U.S. jurisdiction, congressional oversight, and federal court precedent "
                "as the basis for implementation timelines and agency guidance. "
                "Committee members discussed procedural timelines, legal standards, procurement implications, "
                "state-federal coordination, and enforcement sequencing for domestic investigations. "
                "Industry witnesses highlighted compliance burdens on U.S. firms and reviewed historical merger cases "
                "used by federal regulators to shape current policy proposals."
            ),
            "title": "US lawmakers debate AI antitrust policy",
            "image_url": None,
            "image_bytes": None,
            "url": url,
            "original_url": url,
            "is_paywalled": False,
        }

    async def fake_summarize(
        text: str,
        provider: str,
        category_hint: Optional[str] = None,
        category_bias: str = "neutral",
        http_client=None,
        country_code: Optional[str] = None,
        published_at: Optional[datetime] = None,
    ):
        return {
            "title": "US lawmakers debate AI antitrust policy",
            "summary": "US congressional hearings focused on domestic antitrust tools and U.S. agency oversight for major AI companies.",
            "categories": ["tech", "politics"],
            "subcategory": "AI Policy",
            "type": "hard_news",
            "local_relevance": "non_local",
            "local_confidence": 0.94,
            "local_reason": "Event and impact are centered in the US.",
        }

    async def fake_embed(text: str):
        return [0.01, 0.11, 0.21, 0.31]

    monkeypatch.setattr(ingestion, "scrape_article_sync", fake_scrape)
    monkeypatch.setattr(ingestion, "summarize_article", fake_summarize)
    monkeypatch.setattr(ingestion, "embed_text", fake_embed)

    conn = FakeConn()
    pool = FakePool(conn)

    article_id = asyncio.run(ingestion.ingest_from_url(ARTICLE_URL, pool, country_code="KE"))

    assert article_id is None
    assert len(conn.inserted_rows) == 0

    rejected_logs = [
        row for row in conn.log_rows
        if "ingestion_logs" in row[0] and row[1][1] == "SKIPPED" and row[1][10] == "LOW_LOCAL_RELEVANCE"
    ]
    assert len(rejected_logs) >= 1


def test_ingest_non_local_but_low_confidence_sets_country_code_to_none(monkeypatch):
    """
    If an article is classified as non_local but with low confidence (< 0.70),
    it should pass the gate (i.e. not be skipped) but its country_code in the DB
    should be set to None.
    """
    def fake_scrape(url: str):
        return {
            "text": (
                "Kenya technology regulators announced a new framework for AI startups, "
                "focusing on accountability, safety testing, and transparent disclosures. "
                "Investors said the policy could accelerate responsible innovation while "
                "keeping consumer trust high across finance, education, and healthcare sectors. "
                "The framework introduces pre-deployment risk assessments, mandatory incident reporting, "
                "and periodic independent audits for high-impact systems. Officials said the approach "
                "balances growth and public safety while helping startups enter regulated markets faster. "
                "Industry groups welcomed clearer compliance rules and said the policy may attract regional "
                "capital for trustworthy AI products."
            ),
            "title": "Standard title",
            "image_url": None,
            "image_bytes": None,
            "url": url,
            "original_url": url,
            "is_paywalled": False,
        }

    async def fake_summarize(*args, **kwargs):
        return {
            "title": "Standard title",
            "summary": "Standard summary",
            "categories": ["tech"],
            "subcategory": "AI",
            "type": "hard_news",
            "local_relevance": "non_local",
            "local_confidence": 0.60, # low confidence, passes gate when strict mode is off
            "local_reason": "Low confidence non-local",
        }

    async def fake_embed(text: str):
        return [0.01, 0.11, 0.21, 0.31]

    monkeypatch.setattr(ingestion, "scrape_article_sync", fake_scrape)
    monkeypatch.setattr(ingestion, "summarize_article", fake_summarize)
    monkeypatch.setattr(ingestion, "embed_text", fake_embed)

    conn = FakeConn()
    pool = FakePool(conn)

    article_id = asyncio.run(ingestion.ingest_from_url(ARTICLE_URL, pool, country_code="KE"))

    assert article_id == "integration-article-1"
    assert len(conn.inserted_rows) == 1
    insert_query, insert_args = conn.inserted_rows[0]
    assert insert_args[11] is None  # Should be set to None because it's non-local!


def test_summarize_article_locality_context(monkeypatch):
    """Verifies that summarize_article constructs prompt and makes calls without NameError."""
    from unittest.mock import AsyncMock, MagicMock

    # Create a mock client
    mock_client = MagicMock()
    mock_response = MagicMock()
    mock_response.text = '{"title": "Test Title", "summary": "This is a test summary that is long enough to fit the constraints but not too long to trigger any failures.", "categories": ["tech"], "type": "hard_news", "subcategory": "Test", "local_relevance": "local", "local_confidence": 0.9, "local_reason": "test country"}'
    
    # Mock the async call: client.aio.models.generate_content
    mock_generate = AsyncMock(return_value=mock_response)
    mock_client.aio.models.generate_content = mock_generate

    # Patch the global client and make sure it is set
    monkeypatch.setattr(ingestion, "_gemini_client", mock_client)

    result = asyncio.run(
        ingestion.summarize_article(
            text="Some article text goes here.",
            provider="gemini",
            country_code="KE",
        )
    )

    assert result["title"] == "Test Title"
    mock_generate.assert_called_once()
    called_args, called_kwargs = mock_generate.call_args
    assert called_kwargs["config"].response_mime_type == "application/json"
    prompt = called_kwargs["contents"]
    assert "Target country: KE" in prompt
    assert "local_relevance" in prompt




