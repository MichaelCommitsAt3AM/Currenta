import asyncio
from dataclasses import dataclass, field
from typing import Optional

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

    async def fake_summarize(text: str, provider: str, category_hint: Optional[str] = None, category_bias: str = "neutral"):
        stage_flags["summarized"] = True
        assert len(text.split()) >= 30
        return {
            "title": "Kenya issues AI safety policy for startups",
            "summary": (
                "Kenya introduced new rules requiring AI startups to run safety checks, "
                "publish model limitations, and implement accountability controls before deployment."
            ),
            "categories": ["tech", "business"],
            "subcategory": "AI Policy",
            "type": "hard_news",
        }

    async def fake_embed(text: str):
        stage_flags["embedded"] = True
        assert "Kenya" in text
        return [0.01, 0.11, 0.21, 0.31]

    monkeypatch.setattr(ingestion, "scrape_article_sync", fake_scrape)
    monkeypatch.setattr(ingestion, "summarize_article", fake_summarize)
    monkeypatch.setattr(ingestion, "embed_text", fake_embed)
    monkeypatch.setattr(ingestion, "is_duplicate", lambda conn, embedding: asyncio.sleep(0, result=False))

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
    assert insert_args[2] == ARTICLE_URL
    assert insert_args[5] == ["tech", "business"]
    assert insert_args[7] == [0.01, 0.11, 0.21, 0.31]

    success_logs = [row for row in conn.log_rows if "ingestion_logs" in row[0] and row[1][1] == "SUCCESS"]
    assert len(success_logs) >= 1
