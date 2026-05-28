import asyncio
import os
import sys
import math
from datetime import datetime, timezone
from dotenv import load_dotenv
import asyncpg

sys.path.append(os.path.join(os.path.dirname(__file__), ".."))
load_dotenv()

# Copy functions from api.trending and api.feed to be import-independent
def _hours_since_published(published_at: datetime, now: datetime) -> float:
    if not published_at:
        return 9999.0
    if published_at.tzinfo is None:
        published_at = published_at.replace(tzinfo=timezone.utc)
    delta = now - published_at.astimezone(timezone.utc)
    return max(delta.total_seconds() / 3600.0, 0.0)

def _effective_trending_score(article: dict, now: datetime) -> float:
    trend_score = float(article.get("trend_score") or 0.0)
    hours_old = _hours_since_published(article.get("published_at"), now)
    freshness = math.exp(-hours_old / 24.0)
    return (trend_score * (0.7 + 0.6 * freshness)) + freshness

def _primary_category(article: dict) -> str:
    categories = article.get("categories")
    if isinstance(categories, list) and categories:
        first = str(categories[0]).strip().lower()
        return first or "uncategorized"
    return "uncategorized"

def _select_diverse_trending_articles(articles: list, limit: int) -> list:
    if limit <= 0:
        return []
    source_cap = 1 if limit <= 5 else 2
    category_cap = max(1, limit // 3)
    selected = []
    source_counts = {}
    category_counts = {}
    
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

    for article in articles:
        if len(selected) >= limit:
            break
        if article in selected:
            continue
        selected.append(article)
    return selected

def _collapse_near_duplicate_articles(articles: list) -> list:
    # Basic implementation just to simulate
    return articles

ARTICLE_COLUMNS = "id, title, source_name, categories, trend_score, published_at, country_code"

async def main():
    db_url = os.getenv("DATABASE_URL")
    conn = await asyncpg.connect(db_url, statement_cache_size=0)
    try:
        now = datetime.now(timezone.utc)
        print(f"Current UTC time: {now}")
        
        # Simulating global trending query
        hours = 72
        limit = 20
        candidate_limit = 120
        
        query = f"""
            SELECT {ARTICLE_COLUMNS}
            FROM articles
            WHERE trend_score > 0
            AND published_at > NOW() - (INTERVAL '1 hour' * $2)
            ORDER BY trend_score DESC, published_at DESC
            LIMIT $1
        """
        records = await conn.fetch(query, candidate_limit, hours)
        print(f"\n1. Database returned {len(records)} candidates within last {hours} hours:")
        for r in records:
            print(f"- ID: {r['id']}, Title: {r['title'][:40]}, Country: {r['country_code']}, Score: {r['trend_score']}, Published: {r['published_at']}")
            
        candidates = []
        for record in records:
            r = dict(record)
            r["ranking_score"] = _effective_trending_score(r, now)
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
        print(f"\n2. After near-duplicate collapsing: {len(deduped)} articles remaining.")
        
        selected = _select_diverse_trending_articles(deduped, limit)
        print(f"\n3. After diversity filtering: {len(selected)} articles selected.")
        for r in selected:
            print(f"- Title: {r['title'][:40]}, Source: {r['source_name']}, Category: {r.get('categories')}")
            
    finally:
        await conn.close()

if __name__ == "__main__":
    asyncio.run(main())
