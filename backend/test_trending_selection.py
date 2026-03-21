from datetime import datetime, timedelta, timezone

from backend.api import trending


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
