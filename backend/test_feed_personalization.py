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

# Same idea for `supabase`: backend.services.ingestion only needs the
# create_client/Client names to import cleanly, and pulling in the real
# package's heavy (and, on some Python versions, native-build-only) transitive
# dependencies is unnecessary for tests that never construct a real client.
if "supabase" not in sys.modules:
    supabase_module = types.ModuleType("supabase")

    class _DummyClient:
        def __init__(self, *args, **kwargs):
            pass

    def _dummy_create_client(*args, **kwargs):
        return _DummyClient()

    supabase_module.Client = _DummyClient
    supabase_module.create_client = _dummy_create_client
    sys.modules["supabase"] = supabase_module

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
    """Each category's popular-subcategory label text should be embedded in a
    single batched call and the resulting vectors averaged, matching the
    update_user_interest_vector SQL function's approach (see
    20260421113000_recommendation_engine_core.sql) of caching one combined
    vector on user_profiles."""
    embed_calls = []

    async def fake_embed_texts(texts):
        embed_calls.append(texts)
        # Distinct per input so the mean is verifiably not just one vector repeated
        return [[1.0, 0.0] if "tech" in t else [0.0, 1.0] for t in texts]

    monkeypatch.setattr(feed, "embed_texts", fake_embed_texts)

    conn = _FakeConn()
    pool = _FakePool(conn)

    result = asyncio.run(
        feed._seed_cold_start_interest_embedding("user-1", ["tech", "science"], pool)
    )

    assert len(embed_calls) == 1  # one batched round-trip, not two sequential ones
    embedded_texts = embed_calls[0]
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
    async def failing_embed_texts(texts):
        raise RuntimeError("embedding provider unavailable")

    monkeypatch.setattr(feed, "embed_texts", failing_embed_texts)

    conn = _FakeConn()
    pool = _FakePool(conn)

    result = asyncio.run(
        feed._seed_cold_start_interest_embedding("user-1", ["tech"], pool)
    )

    assert result is None
    assert conn.executed == []


class _FakeViewsConn:
    def __init__(self, rows):
        self._rows = rows
        self.fetch_calls = []

    async def fetch(self, query, *args):
        self.fetch_calls.append((query, args))
        return self._rows


class _FakeRedis:
    def __init__(self, sets=None, strings=None, smembers_raises=False):
        self.sets = sets or {}
        self.strings = strings or {}
        self.smembers_raises = smembers_raises
        self.expire_calls = []
        self.sadd_calls = []
        self.set_calls = []

    async def smembers(self, key):
        if self.smembers_raises:
            raise RuntimeError("redis unavailable")
        return self.sets.get(key, set())

    async def get(self, key):
        return self.strings.get(key)

    async def sadd(self, key, *members):
        self.sadd_calls.append((key, members))
        self.sets.setdefault(key, set()).update(members)

    async def expire(self, key, ttl):
        self.expire_calls.append((key, ttl))

    async def set(self, key, value, ex=None):
        self.set_calls.append((key, value, ex))
        self.strings[key] = value


_UID = "11111111-1111-1111-1111-111111111111"


def test_get_viewed_ids_prefers_redis_and_skips_db():
    """The Redis set is the fast path fed by /feed/view — if it has anything,
    trust it and never touch Postgres."""
    redis_client = _FakeRedis(sets={f"user_seen_v2:{_UID}": {"a", "b"}})
    conn = _FakeViewsConn(rows=[])
    pool = _FakePool(conn)

    result = asyncio.run(feed._get_viewed_ids(_UID, redis_client, pool))

    assert result == {"a", "b"}
    assert conn.fetch_calls == []


def test_get_viewed_ids_falls_back_to_article_views_and_rehydrates_redis():
    """A Redis miss (e.g. post-restart eviction) must not be read as 'nothing
    seen' — this is exactly the bug where users saw yesterday's articles
    again. It should fall back to the durable article_views table and refill
    the Redis set so subsequent requests skip the DB round-trip again."""
    redis_client = _FakeRedis(sets={})  # empty set == cache miss, not "no history"
    conn = _FakeViewsConn(rows=[{"article_id": "x"}, {"article_id": "y"}])
    pool = _FakePool(conn)

    result = asyncio.run(feed._get_viewed_ids(_UID, redis_client, pool))

    assert result == {"x", "y"}
    assert len(conn.fetch_calls) == 1
    query, args = conn.fetch_calls[0]
    assert "article_views" in query
    assert args[0] == feed.UUID(_UID)
    assert args[1] == feed.VIEWED_LOOKBACK_DAYS

    # Rehydrated so the next call is served from Redis again
    assert redis_client.sets[f"user_seen_v2:{_UID}"] == {"x", "y"}
    assert redis_client.expire_calls == [(f"user_seen_v2:{_UID}", feed.SEEN_SET_TTL_SECONDS)]
    hydrated_sets = [c for c in redis_client.set_calls if c[0] == f"user_seen_hydrated:{_UID}"]
    assert len(hydrated_sets) == 1
    assert hydrated_sets[0][2] == feed.VIEWED_HYDRATED_TTL_SECONDS


def test_get_viewed_ids_hydrated_sentinel_short_circuits_repeat_db_queries():
    """Once a request has already confirmed against Postgres that a user has
    no recent view history, a still-empty Redis set on the next request
    within the sentinel TTL must not trigger another DB query — otherwise a
    prolific-scrolling user with zero real history hits Postgres on every
    single feed page."""
    redis_client = _FakeRedis(
        sets={},
        strings={f"user_seen_hydrated:{_UID}": "1"},
    )
    conn = _FakeViewsConn(rows=[{"article_id": "should-not-be-returned"}])
    pool = _FakePool(conn)

    result = asyncio.run(feed._get_viewed_ids(_UID, redis_client, pool))

    assert result == set()
    assert conn.fetch_calls == []


def test_get_viewed_ids_survives_redis_read_error_via_db_fallback():
    """If Redis errors on read (not just empty), the seen-filter must degrade
    to the DB query rather than propagate the error into get_feed."""
    redis_client = _FakeRedis(smembers_raises=True)
    conn = _FakeViewsConn(rows=[{"article_id": "z"}])
    pool = _FakePool(conn)

    result = asyncio.run(feed._get_viewed_ids(_UID, redis_client, pool))

    assert result == {"z"}


def test_get_viewed_ids_survives_db_error_returning_empty():
    """A failing Postgres fallback query must not break the feed request —
    best-effort only, same policy as every other Redis/DB cache path here."""
    redis_client = _FakeRedis(sets={})

    class _FailingConn:
        async def fetch(self, query, *args):
            raise RuntimeError("db unavailable")

    pool = _FakePool(_FailingConn())

    result = asyncio.run(feed._get_viewed_ids(_UID, redis_client, pool))

    assert result == set()


def test_get_viewed_ids_with_no_redis_client_queries_db_directly():
    """When Redis is entirely unconfigured (redis_client is None), the
    fallback must still work rather than skip filtering altogether — this was
    the other half of the original bug (`if user_id and redis_client`)."""
    conn = _FakeViewsConn(rows=[{"article_id": "w"}])
    pool = _FakePool(conn)

    result = asyncio.run(feed._get_viewed_ids(_UID, None, pool))

    assert result == {"w"}


def test_seen_filter_uses_any_array_not_variadic_not_in():
    """Regression guard for the `id <> ALL($1::uuid[])` refactor: the seen
    filter must be exactly one positional parameter regardless of how many
    articles were viewed, so downstream bucket param offsets never drift with
    view-history size, and the old per-id `NOT IN (...)` form must be gone."""
    import inspect

    source = inspect.getsource(feed.get_feed)
    assert "id <> ALL($1::uuid[])" in source
    assert "NOT IN" not in source


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
