import asyncio
from datetime import datetime, timedelta, timezone

from backend.api import trending
from backend.services import trending as trending_service


def _article(
    article_id: str,
    title: str,
    source: str,
    category: str,
    trend_score: float,
    hours_old: float,
) -> dict:
    return {
        "id": article_id,
        "title": title,
        "summary": title,
        "original_url": f"https://example.com/{article_id}",
        "source_name": source,
        "categories": [category],
        "trend_score": trend_score,
        "published_at": datetime.now(timezone.utc) - timedelta(hours=hours_old),
    }


def test_effective_trending_score_prefers_fresher_story_when_scores_close():
    now = datetime.now(timezone.utc)
    fresh = _article("fresh", "Fresh Story", "Reuters", "world", 8.0, 2)
    stale = _article("stale", "Older Story", "AP", "world", 8.0, 40)

    fresh_score = trending._effective_trending_score(fresh, now)
    stale_score = trending._effective_trending_score(stale, now)

    assert fresh_score > stale_score


def test_select_diverse_trending_articles_limits_source_and_category_concentration():
    ranked = [
        _article("a1", "Election update one", "Reuters", "world", 9.0, 1),
        _article("a2", "Election update two", "Reuters", "world", 8.8, 2),
        _article("a3", "Election update three", "Reuters", "world", 8.7, 3),
        _article("b1", "AI chip release", "The Verge", "tech", 8.6, 2),
        _article("c1", "Market rally", "Bloomberg", "business", 8.5, 2),
        _article("d1", "Grand slam final", "ESPN", "sports", 8.4, 2),
    ]

    selected = trending._select_diverse_trending_articles(ranked, limit=5)
    selected_ids = [a["id"] for a in selected]

    assert len(selected) == 5
    assert "a1" in selected_ids
    # Ensure we don't take all top slots from same source/category.
    assert not ({"a1", "a2", "a3"} <= set(selected_ids))


def test_trending_pipeline_dedup_then_diversify_keeps_distinct_topics():
    now = datetime.now(timezone.utc)
    candidates = [
        {
            "id": "dup1",
            "title": "Jury Finds Elon Musk Misled Investors Before Twitter Acquisition",
            "summary": "A California jury ruled Elon Musk misled investors before his Twitter purchase.",
            "original_url": "https://source-a.example/elon-musk-twitter-lawsuit",
            "source_name": "Source A",
            "categories": ["tech"],
            "trend_score": 9.2,
            "published_at": now - timedelta(hours=3),
        },
        {
            "id": "dup2",
            "title": "Elon Musk Found Liable for Misleading Twitter Investors",
            "summary": "A California jury found Elon Musk intentionally misled investors regarding Twitter.",
            "original_url": "https://source-b.example/elon-musk-misled-investors",
            "source_name": "Source B",
            "categories": ["tech"],
            "trend_score": 9.1,
            "published_at": now - timedelta(hours=2),
        },
        _article("space1", "NASA releases Webb deep field", "NASA", "science", 8.7, 4),
        _article("sports1", "Grand slam final preview", "ESPN", "sports", 8.6, 5),
    ]

    for article in candidates:
        article["ranking_score"] = trending._effective_trending_score(article, now)

    ranked = sorted(candidates, key=lambda a: a["ranking_score"], reverse=True)
    deduped = trending._collapse_near_duplicate_articles(ranked)
    selected = trending._select_diverse_trending_articles(deduped, limit=3)

    selected_ids = {a["id"] for a in selected}
    assert len(selected) == 3
    assert len(selected_ids & {"dup1", "dup2"}) == 1
    assert "space1" in selected_ids


# ── trend_score decay ────────────────────────────────────────────────────────


class _DecayConn:
    def __init__(self, rowcount=7):
        self.executed = []
        self._rowcount = rowcount

    async def execute(self, query, *args):
        self.executed.append((query, args))
        return f"UPDATE {self._rowcount}"


class _DecayAcquireCtx:
    def __init__(self, conn):
        self._conn = conn

    async def __aenter__(self):
        return self._conn

    async def __aexit__(self, *exc):
        return False


class _DecayPool:
    def __init__(self, conn):
        self._conn = conn

    def acquire(self):
        return _DecayAcquireCtx(self._conn)


class _DecayRedis:
    def __init__(self, strings=None):
        self.strings = dict(strings or {})
        self.set_calls = []

    async def get(self, key):
        return self.strings.get(key)

    async def set(self, key, value, ex=None):
        self.set_calls.append((key, value, ex))
        self.strings[key] = value


def test_decayed_trend_score_reduces_and_floors():
    # One run knocks the score down by the decay factor.
    assert trending_service._decayed_trend_score(10.0) == 10.0 * trending_service.TREND_SCORE_DECAY_FACTOR
    # Anything that lands below the floor after decay snaps to 0 so the row
    # drops out of the "trend_score > 0" trending tier.
    assert trending_service._decayed_trend_score(trending_service.TREND_SCORE_FLOOR) == 0.0
    assert trending_service._decayed_trend_score(0.0) == 0.0


def test_decay_converges_to_zero_when_story_stops_trending():
    score = 12.0  # pinned at the cap
    for _ in range(20):
        score = trending_service._decayed_trend_score(score)
    assert score == 0.0


def test_decay_preserves_a_still_hot_story():
    # Model: decay, then this run's boost (+10, capped at 12) because it is
    # still trending. Should stabilise at the cap, not erode.
    score = 12.0
    for _ in range(10):
        score = min(trending_service._decayed_trend_score(score) + 10.0, 12.0)
    assert score == 12.0


def test_decay_trend_scores_runs_and_records_timestamp():
    conn = _DecayConn()
    redis = _DecayRedis()

    asyncio.run(trending_service._decay_trend_scores(_DecayPool(conn), redis))

    assert len(conn.executed) == 1
    query, args = conn.executed[0]
    assert "UPDATE articles" in query
    assert "trend_score * $1" in query
    assert args[0] == trending_service.TREND_SCORE_DECAY_FACTOR
    assert args[1] == trending_service.TREND_SCORE_FLOOR
    # last-run timestamp persisted for the co-fire guard
    assert len(redis.set_calls) == 1
    assert redis.set_calls[0][0] == trending_service._TREND_DECAY_LAST_RUN_KEY


def test_decay_trend_scores_skips_when_recently_run():
    recent = (datetime.now(timezone.utc) - timedelta(seconds=60)).isoformat()
    conn = _DecayConn()
    redis = _DecayRedis(strings={trending_service._TREND_DECAY_LAST_RUN_KEY: recent})

    asyncio.run(trending_service._decay_trend_scores(_DecayPool(conn), redis))

    assert conn.executed == []
    assert redis.set_calls == []


def test_decay_trend_scores_runs_without_redis():
    conn = _DecayConn()

    asyncio.run(trending_service._decay_trend_scores(_DecayPool(conn), None))

    assert len(conn.executed) == 1
