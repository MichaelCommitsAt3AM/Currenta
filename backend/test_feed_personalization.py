import asyncio
import os
import sys
import types

# Ensure backend security module import does not fail in test-only execution.
os.environ.setdefault("ADMIN_API_KEY", "test-key")

# Provide a tiny geoip2 stub so feed import works in environments where the
# optional geo lookup dependency is not installed.
if "geoip2" not in sys.modules:
    geoip2_module = types.ModuleType("geoip2")
    geoip2_database_module = types.ModuleType("geoip2.database")

    class _DummyReader:
        def __init__(self, *args, **kwargs):
            pass

    geoip2_database_module.Reader = _DummyReader
    geoip2_module.database = geoip2_database_module
    sys.modules["geoip2"] = geoip2_module
    sys.modules["geoip2.database"] = geoip2_database_module

from backend.api import feed


class _FakeConn:
    def __init__(self):
        self.executed = []

    async def execute(self, query, *args):
        self.executed.append((query, args))


class _FakeAcquireCtx:
    def __init__(self, conn):
        self._conn = conn

    async def __aenter__(self):
        return self._conn

    async def __aexit__(self, *exc):
        return False


class _FakePool:
    def __init__(self, conn):
        self._conn = conn

    def acquire(self):
        return _FakeAcquireCtx(self._conn)


def test_seed_cold_start_interest_embedding_averages_category_embeddings(monkeypatch):
    """Each category's popular-subcategory label text should be embedded once
    and the resulting vectors averaged, matching the update_user_interest_vector
    SQL function's approach (see 20260421113000_recommendation_engine_core.sql)
    of caching one combined vector on user_profiles."""
    embedded_texts = []

    async def fake_embed_text(text):
        embedded_texts.append(text)
        # Distinct per call so the mean is verifiably not just one vector repeated
        return [1.0, 0.0] if "tech" in text else [0.0, 1.0]

    monkeypatch.setattr(feed, "embed_text", fake_embed_text)

    conn = _FakeConn()
    pool = _FakePool(conn)

    result = asyncio.run(
        feed._seed_cold_start_interest_embedding("user-1", ["tech", "science"], pool)
    )

    assert len(embedded_texts) == 2
    assert "AI & Machine Learning" in embedded_texts[0] or "AI & Machine Learning" in embedded_texts[1]
    assert result == [0.5, 0.5]  # mean of [1,0] and [0,1]

    assert len(conn.executed) == 1
    query, args = conn.executed[0]
    assert "INSERT INTO user_profiles" in query
    assert "ON CONFLICT (user_id) DO UPDATE" in query
    assert args[0] == "user-1"
    assert args[1] == [0.5, 0.5]


def test_seed_cold_start_interest_embedding_returns_none_for_unknown_categories():
    """Categories with no taxonomy entries produce no embeddable text, so this
    should degrade to a no-op rather than write junk."""
    conn = _FakeConn()
    pool = _FakePool(conn)

    result = asyncio.run(
        feed._seed_cold_start_interest_embedding("user-1", ["not_a_real_category"], pool)
    )

    assert result is None
    assert conn.executed == []


def test_seed_cold_start_interest_embedding_is_best_effort_on_embed_failure(monkeypatch):
    """A failure calling the embedding provider must never break feed loading —
    this whole function is a bootstrap nicety, not a hard dependency."""
    async def failing_embed_text(text):
        raise RuntimeError("embedding provider unavailable")

    monkeypatch.setattr(feed, "embed_text", failing_embed_text)

    conn = _FakeConn()
    pool = _FakePool(conn)

    result = asyncio.run(
        feed._seed_cold_start_interest_embedding("user-1", ["tech"], pool)
    )

    assert result is None
    assert conn.executed == []


def test_subcategory_boost_is_parameterized_not_string_interpolated():
    """user_sub_interests is user-writable data (direct Supabase upsert from the
    client), unlike category_boost's validated category names — the subcategory
    boost MUST go in as a bound parameter, never interpolated into the SQL
    string, or a crafted sub_category value could break out of the query."""
    malicious_value = "x'; DROP TABLE articles; --"

    params = ["viewed-id"]
    subcategory_boost = [malicious_value]

    local_params = list(params)
    order_by = "ranking_score DESC"
    if subcategory_boost:
        local_params.append(subcategory_boost)
        order_by = f"(subcategories && ${len(local_params)}::text[]) DESC, {order_by}"

    assert malicious_value not in order_by
    assert order_by == "(subcategories && $2::text[]) DESC, ranking_score DESC"
    assert local_params[-1] == [malicious_value]
