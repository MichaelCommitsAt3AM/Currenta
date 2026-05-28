import logging
import math
from datetime import datetime, timezone
from fastapi import APIRouter, HTTPException, Depends, Query, Request, BackgroundTasks
import asyncpg
from typing import List, Optional
from ..core.security import limiter, verify_admin_api_key
from .feed import ARTICLE_COLUMNS, get_db, _collapse_near_duplicate_articles
from ..services.trending import update_trending_scores

logger = logging.getLogger(__name__)

router = APIRouter()


def _hours_since_published(published_at: Optional[datetime], now: datetime) -> float:
    if not published_at:
        return 9999.0
    if published_at.tzinfo is None:
        published_at = published_at.replace(tzinfo=timezone.utc)
    delta = now - published_at.astimezone(timezone.utc)
    return max(delta.total_seconds() / 3600.0, 0.0)


def _effective_trending_score(article: dict, now: datetime) -> float:
    """
    Recency-aware score to avoid stale items dominating the trending list.
    Keeps trend_score as primary input while applying time decay.
    """
    trend_score = float(article.get("trend_score") or 0.0)
    hours_old = _hours_since_published(article.get("published_at"), now)

    # Half-life style decay: 1.0 at publish time, ~0.37 after 24h, ~0.14 after 48h.
    freshness = math.exp(-hours_old / 24.0)

    # Keep trend score dominant while strongly preferring recent stories.
    return (trend_score * (0.7 + 0.6 * freshness)) + freshness


def _primary_category(article: dict) -> str:
    categories = article.get("categories")
    if isinstance(categories, list) and categories:
        first = str(categories[0]).strip().lower()
        return first or "uncategorized"
    return "uncategorized"


def _select_diverse_trending_articles(articles: List[dict], limit: int) -> List[dict]:
    """
    Selects a diverse set of trending articles, limiting concentration from
    the same source/category while preserving overall rank order.
    """
    if limit <= 0:
        return []

    source_cap = 1 if limit <= 5 else 2
    category_cap = max(1, limit // 3)

    selected: List[dict] = []
    source_counts: dict[str, int] = {}
    category_counts: dict[str, int] = {}

    # Pass 1: enforce strict diversity caps.
    for article in articles:
        source = str(article.get("source_name") or "unknown").strip().lower()
        category = _primary_category(article)

        if source_counts.get(source, 0) >= source_cap:
            continue
        if category_counts.get(category, 0) >= category_cap:
            continue

        selected.append(article)
        source_counts[source] = source_counts.get(source, 0) + 1
        category_counts[category] = category_counts.get(category, 0) + 1
        if len(selected) >= limit:
            return selected

    # Pass 2: relax category cap but keep source diversity guard.
    for article in articles:
        if len(selected) >= limit:
            return selected
        if article in selected:
            continue

        source = str(article.get("source_name") or "unknown").strip().lower()
        if source_counts.get(source, 0) >= source_cap + 1:
            continue

        selected.append(article)
        source_counts[source] = source_counts.get(source, 0) + 1

    # Pass 3: fill any remaining slots to avoid under-serving the response.
    for article in articles:
        if len(selected) >= limit:
            break
        if article in selected:
            continue
        selected.append(article)

    return selected

@router.get("")
@limiter.limit("60/minute")
async def get_trending_feed(
    request: Request,
    country: Optional[str] = Query(None, description="Filter trends by this country"),
    hours: int = Query(72, ge=1, le=168, description="Time window in hours"),
    limit: int = Query(20, ge=1, le=50),
    db_pool: asyncpg.Pool = Depends(get_db)
):
    """
    Returns the top trending articles.
    If 'country' is specified, results are strictly filtered to that country,
    with a fallback to global articles to ensure the feed is not empty or under-filled.
    'hours' determines how far back to look, with automatic time-window expansion if content is sparse.
    """
    try:
        async with db_pool.acquire() as conn:
            candidate_limit = min(max(limit * 6, 40), 200)
            current_hours = hours
            records = []

            # Build query based on whether a country filter is active
            if country and country.lower() != 'global':
                # First fetch local articles
                query = f"""
                    SELECT {ARTICLE_COLUMNS}
                    FROM articles
                    WHERE trend_score > 0
                    AND country_code = $2
                    AND published_at > NOW() - (INTERVAL '1 hour' * $3)
                    ORDER BY trend_score DESC, published_at DESC
                    LIMIT $1
                """
                records = await conn.fetch(query, candidate_limit, country.upper(), current_hours)
                
                # If we don't have enough candidates, try expanding the time window
                if len(records) < limit and current_hours < 168:
                    current_hours = max(72, current_hours * 3)
                    records = await conn.fetch(query, candidate_limit, country.upper(), current_hours)
                
                # If we still don't have enough local articles, fill with global/world articles
                local_records = [dict(r) for r in records]
                if len(local_records) < limit:
                    needed = candidate_limit - len(local_records)
                    query_global = f"""
                        SELECT {ARTICLE_COLUMNS}
                        FROM articles
                        WHERE trend_score > 0
                        AND (country_code IS NULL OR country_code != $2)
                        AND published_at > NOW() - (INTERVAL '1 hour' * $3)
                        ORDER BY trend_score DESC, published_at DESC
                        LIMIT $1
                    """
                    global_records = await conn.fetch(query_global, needed, country.upper(), current_hours)
                    local_records.extend([dict(r) for r in global_records])
                records = local_records
            else:
                # Global feed query
                query = f"""
                    SELECT {ARTICLE_COLUMNS}
                    FROM articles
                    WHERE trend_score > 0
                    AND published_at > NOW() - (INTERVAL '1 hour' * $2)
                    ORDER BY trend_score DESC, published_at DESC
                    LIMIT $1
                """
                records = await conn.fetch(query, candidate_limit, current_hours)
                
                # If we don't have enough, expand time window
                if len(records) < limit and current_hours < 168:
                    current_hours = max(72, current_hours * 3)
                    records = await conn.fetch(query, candidate_limit, current_hours)
                
                # If we still don't have enough, expand to max 168 hours
                if len(records) < limit and current_hours < 168:
                    records = await conn.fetch(query, candidate_limit, 168)
                
                records = [dict(r) for r in records]

            now = datetime.now(timezone.utc)
            candidates: List[dict] = []
            for r in records:
                base_score = _effective_trending_score(r, now)
                # Boost local articles when a specific country filter is requested
                is_local = country and country.lower() != 'global' and r.get("country_code") == country.upper()
                r["ranking_score"] = base_score + (100.0 if is_local else 0.0)
                candidates.append(r)

            candidates.sort(
                key=lambda a: (
                    float(a.get("ranking_score") or 0.0),
                    float(a.get("trend_score") or 0.0),
                    a.get("published_at") or datetime.min.replace(tzinfo=timezone.utc),
                ),
                reverse=True,
            )

            deduped = _collapse_near_duplicate_articles(candidates)
            selected = _select_diverse_trending_articles(deduped, limit)

            articles: List[dict] = []
            for r in selected:
                r['published_at'] = r['published_at'].isoformat() if r.get('published_at') else None
                r['created_at'] = r['created_at'].isoformat() if r.get('created_at') else None
                r['id'] = str(r['id']) if r.get('id') else None
                r['cluster_id'] = str(r['cluster_id']) if r.get('cluster_id') else None
                r.pop('ranking_score', None)
                articles.append(r)
                
            return articles

    except Exception as e:
        logger.error("Database error in get_trending_feed: %s", e)
        raise HTTPException(status_code=500, detail="Failed to fetch trending articles")

@router.post("/trigger")
@limiter.limit("5/minute;100/day")
async def trigger_trending_update(
    request: Request,
    background_tasks: BackgroundTasks,
    db_pool: asyncpg.Pool = Depends(get_db),
    admin_key: str = Depends(verify_admin_api_key)
):
    """
    Manually triggers the trending score update process.
    """
    try:
        if request.app.state.redis_client:
            await request.app.state.redis_client.publish("worker_tasks", "trigger_trending")
        else:
            background_tasks.add_task(update_trending_scores, db_pool)
        return {"status": "trending_update_started"}
    except Exception as e:
        logger.error("Error triggering trending update: %s", e)
        raise HTTPException(status_code=500, detail=str(e))
