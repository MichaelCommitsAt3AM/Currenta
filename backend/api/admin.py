from fastapi import APIRouter, HTTPException, Depends, Request
from pydantic import BaseModel
from typing import List, Optional
import logging
from datetime import datetime, timezone
import uuid
import re
from urllib.parse import urlparse

from ..core.security import verify_is_admin, User
from ..services.ingestion import (
    scrape_article_sync,
    summarize_article,
    embed_text,
    generate_content_hash,
    calculate_ranking_score,
    log_ingestion_event,
    LLM_PROVIDER,
    VALID_CATEGORIES
)
from ..services.taxonomy import get_taxonomy
import asyncio
from datetime import date, timedelta

logger = logging.getLogger(__name__)

router = APIRouter()


class AnalyticsOverview(BaseModel):
    ai_usage: dict
    content_engagement: dict
    user_growth: dict
    ingestion_health: List[dict]


@router.get("/session/check")
async def check_admin_session(user: User = Depends(verify_is_admin)):
    """
    Confirms the current authenticated user has admin privileges.
    """
    return {"ok": True, "user_id": user.id, "email": user.email}

class DraftRequest(BaseModel):
    url: str

class NewsDraft(BaseModel):
    title: str
    summary: str
    categories: List[str]
    subcategory: str
    source_name: str
    original_url: str
    image_url: Optional[str] = None
    expires_at: Optional[datetime] = None

class PublishRequest(BaseModel):
    title: str
    summary: str
    categories: List[str]
    subcategory: str
    source_name: str
    original_url: str
    image_url: Optional[str] = None
    country_code: Optional[str] = None
    is_paywalled: bool = False
    expires_at: Optional[datetime] = None

class SqlQueryRequest(BaseModel):
    query: str

def is_sql_safe(query: str) -> bool:
    """
    Very basic check to ensure only SELECT-like queries are run.
    This is NOT a substitute for proper DB-level permissions.
    """
    q = query.strip().lower()
    
    # Must start with safe commands
    if not re.match(r'^\s*(select|explain|show)\b', q):
        return False
    
    # Blacklist of hazardous keywords
    forbidden = [
        "delete", "drop", "update", "insert", "truncate", "alter", 
        "grant", "revoke", "create", "replace", "vacuum", "merge",
        "upsert", "call", "execute", "do"
    ]
    
    for word in forbidden:
        if re.search(r'\b' + re.escape(word) + r'\b', q):
            return False
            
    # Block multiple statements
    if ";" in q:
        # Only allow semicolon if it's at the very end
        if re.search(r';\s*\S', q):
            return False
            
    return True

@router.post("/news/draft", response_model=NewsDraft)
async def create_news_draft(
    request: Request,
    draft_req: DraftRequest,
    user: User = Depends(verify_is_admin)
):
    """
    Scrapes a URL and generates a draft news article using AI.
    """
    url = draft_req.url
    logger.info("[admin_portal] Admin %s requested draft for URL: %s", user.id, url)
    source_name = urlparse(url).netloc or "admin_portal"
    pool = request.app.state.db_pool

    async with pool.acquire() as conn:
        await log_ingestion_event(
            conn,
            url,
            "REQUESTED",
            trigger_source="admin_portal",
            source_name=source_name,
            dedup_stage="ADMIN_PORTAL_DRAFT",
            dedup_decision="TRIGGERED",
        )
    
    try:
        # 1. Scrape
        scraper_result = await asyncio.to_thread(scrape_article_sync, url)
        if scraper_result.get("error"):
            async with pool.acquire() as conn:
                await log_ingestion_event(
                    conn,
                    url,
                    "FAILED",
                    trigger_source="admin_portal",
                    source_name=source_name,
                    dedup_stage="ADMIN_PORTAL_DRAFT",
                    dedup_decision="SCRAPE_FAILED",
                    error_type="SCRAPER_FAIL",
                    error_message=scraper_result.get("error"),
                    resolved_url=scraper_result.get("url"),
                )
            raise HTTPException(status_code=400, detail=f"Scraping failed: {scraper_result['error']}")
        
        text = scraper_result.get("text", "")
        if not text or len(text) < 100:
            async with pool.acquire() as conn:
                await log_ingestion_event(
                    conn,
                    url,
                    "FAILED",
                    trigger_source="admin_portal",
                    source_name=source_name,
                    dedup_stage="ADMIN_PORTAL_DRAFT",
                    dedup_decision="CONTENT_TOO_SHORT",
                    error_type="CONTENT_TOO_SHORT",
                    error_message="Insufficient content found at URL",
                    has_text=bool(text),
                    resolved_url=scraper_result.get("url"),
                )
            raise HTTPException(status_code=400, detail="Insufficient content found at URL")
        
        # 2. Summarize & Classify
        llm_res = await summarize_article(
            text=text,
            provider=LLM_PROVIDER,
            category_hint=None
        )
        
        # 3. Prepare response
        # Extract source name from URL if not provided by scraper
        source_name = scraper_result.get("source_name") or source_name

        async with pool.acquire() as conn:
            await log_ingestion_event(
                conn,
                url,
                "SUCCESS",
                trigger_source="admin_portal",
                source_name=source_name,
                dedup_stage="ADMIN_PORTAL_DRAFT",
                dedup_decision="DRAFT_GENERATED",
                has_text=True,
                has_image=bool(scraper_result.get("image_url")),
                extracted_image_url=scraper_result.get("image_url"),
                content_preview=text,
                resolved_url=scraper_result.get("url"),
            )
        
        return NewsDraft(
            title=llm_res.get("title", "Unknown Title"),
            summary=llm_res.get("summary", ""),
            categories=llm_res.get("categories", ["world"]),
            subcategory=(llm_res.get("subcategories") or [""])[0],
            source_name=source_name,
            original_url=url,
            image_url=scraper_result.get("image_url"),
            expires_at=llm_res.get("expires_at")
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating draft: {e}")
        async with pool.acquire() as conn:
            await log_ingestion_event(
                conn,
                url,
                "FAILED",
                trigger_source="admin_portal",
                source_name=source_name,
                dedup_stage="ADMIN_PORTAL_DRAFT",
                dedup_decision="INTERNAL_ERROR",
                error_type="INTERNAL_ERROR",
                error_message=str(e),
            )
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/news/publish")
async def publish_manual_news(
    request: Request,
    publish_req: PublishRequest,
    user: User = Depends(verify_is_admin)
):
    """
    Publishes a manually verified news article to the database.
    """
    logger.info("[admin_portal] Admin %s publishing article: %s", user.id, publish_req.title)
    pool = request.app.state.db_pool
    
    try:
        content_hash = generate_content_hash(publish_req.original_url, publish_req.title)
        
        async with pool.acquire() as conn:
            # Check for duplicates
            existing = await conn.fetchval(
                "SELECT id FROM articles WHERE original_url = $1 OR content_hash = $2",
                publish_req.original_url, content_hash
            )
            if existing:
                await log_ingestion_event(
                    conn,
                    publish_req.original_url,
                    "SKIPPED",
                    trigger_source="admin_portal",
                    source_name=publish_req.source_name,
                    dedup_stage="ADMIN_PORTAL_PUBLISH",
                    dedup_decision="DUPLICATE",
                    error_type="DUPLICATE",
                    error_message="Article already exists (URL or content hash match)",
                    has_text=True,
                    has_image=bool(publish_req.image_url),
                )
                raise HTTPException(status_code=409, detail="Article already exists (URL or content hash match)")
            
            # Generate Embedding
            embedding = await embed_text(f"{publish_req.title}\n\n{publish_req.summary}")
            
            # Calculate ranking score
            published_at = datetime.now(timezone.utc)
            ranking_score = calculate_ranking_score(published_at, trend_score=0.0)
            
            # Generate ID and Clustering Data
            article_id_uuid = uuid.uuid4()
            cluster_id = article_id_uuid # Manual story starts its own cluster

            # Admins can free-type the subcategory field before publishing; resolve
            # it to a canonical taxonomy slug the same way the ingestion pipeline does.
            subcategory = get_taxonomy().match(publish_req.subcategory, publish_req.categories) or ""
            subcategories = [subcategory] if subcategory else []

            article_id = await conn.fetchval(
                """
                INSERT INTO articles (
                    id, title, summary, original_url, source_name,
                    published_at, categories, subcategory, subcategories,
                    country_code, image_url, content_hash,
                    embedding, ranking_score, ingestion_method,
                    is_paywalled, cluster_id, is_major_source, summary_model, expires_at
                ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13::float8[]::vector, $14, $15, $16, $17, $18, $19, $20)
                RETURNING id
                """,
                article_id_uuid,
                publish_req.title,
                publish_req.summary,
                publish_req.original_url,
                publish_req.source_name,
                published_at,
                publish_req.categories,
                subcategory,
                subcategories,
                publish_req.country_code,
                publish_req.image_url,
                content_hash,
                embedding,
                ranking_score,
                "manual_admin",
                publish_req.is_paywalled,
                cluster_id,
                False, # is_major_source
                "manual_admin", # summary_model
                publish_req.expires_at
            )
            
            await log_ingestion_event(
                conn,
                publish_req.original_url,
                "SUCCESS",
                trigger_source="admin_portal",
                source_name=publish_req.source_name,
                dedup_stage="ADMIN_PORTAL_PUBLISH",
                dedup_decision="MANUAL_PUBLISH",
                has_text=True,
                has_image=bool(publish_req.image_url)
            )
            
            return {"status": "success", "article_id": str(article_id)}
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error publishing news: {e}")
        try:
            async with pool.acquire() as conn:
                await log_ingestion_event(
                    conn,
                    publish_req.original_url,
                    "FAILED",
                    trigger_source="admin_portal",
                    source_name=publish_req.source_name,
                    dedup_stage="ADMIN_PORTAL_PUBLISH",
                    dedup_decision="PUBLISH_ERROR",
                    error_type="INTERNAL_ERROR",
                    error_message=str(e),
                    has_text=True,
                    has_image=bool(publish_req.image_url),
                )
        except Exception as log_err:
            logger.warning("Failed to log admin publish error: %s", log_err)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/query")
async def run_admin_query(
    request: Request,
    query_req: SqlQueryRequest,
    user: User = Depends(verify_is_admin)
):
    """
    Executes a read-only SQL query for administrative purposes.
    Enforces safety checks and a 100-row limit.
    """
    raw_query = query_req.query.strip()
    
    if not is_sql_safe(raw_query):
        logger.warning("[admin_query] Blocked hazardous query from admin %s: %s", user.id, raw_query)
        raise HTTPException(
            status_code=403, 
            detail="Forbidden: Only non-hazardous commands (SELECT, EXPLAIN, SHOW) are allowed."
        )

    logger.info("[admin_query] Admin %s running query: %s", user.id, raw_query)
    pool = request.app.state.db_pool
    
    try:
        async with pool.acquire() as conn:
            # PostgreSQL hack: use a read-only transaction for extra safety
            async with conn.transaction(readonly=True):
                # Wrap the query to enforce the 100-row limit if it's a SELECT
                # If it already has a LIMIT, we might still want to wrap it or replace it.
                # Simplest way: wrap in a subquery
                if raw_query.lower().startswith("select"):
                    # Remove trailing semicolon for wrapping
                    inner_query = raw_query.rstrip('; ')
                    final_query = f"SELECT * FROM ({inner_query}) AS user_query LIMIT 100"
                else:
                    final_query = raw_query

                records = await conn.fetch(final_query)
                
                # Convert asyncpg.Record to list of dicts for JSON serialization
                results = [dict(r) for r in records]
                
                return {
                    "status": "success",
                    "row_count": len(results),
                    "columns": list(results[0].keys()) if results else [],
                    "data": results
                }
                
    except Exception as e:
        logger.error(f"Error running admin query: {e}")
        raise HTTPException(status_code=400, detail=f"SQL Error: {str(e)}")


@router.get("/analytics/overview", response_model=AnalyticsOverview)
async def get_analytics_overview(
    request: Request,
    user: User = Depends(verify_is_admin)
):
    """
    Fetches aggregated analytics data for the dashboard.
    """
    pool = request.app.state.db_pool
    today = date.today()
    yesterday = today - timedelta(days=1)
    
    async with pool.acquire() as conn:
        # 1. AI Usage
        ai_usage = await conn.fetchrow("""
            SELECT 
                (SELECT COALESCE(SUM(daily_count), 0) FROM user_ai_usage WHERE last_reset_at = $1) as messages_today,
                (SELECT COUNT(*) FROM user_ai_usage WHERE daily_count >= 30 AND last_reset_at = $1) as quota_users,
                (SELECT COUNT(*) FROM ingestion_logs WHERE status = 'SUCCESS' AND created_at >= $1) as news_generations_today
        """, today)
        
        # 2. Content Engagement
        trending = await conn.fetch("""
            SELECT a.title, a.trend_score
            FROM articles a
            WHERE a.published_at > NOW() - INTERVAL '7 days'
            AND a.trend_score > 0
            ORDER BY a.trend_score DESC
            LIMIT 5
        """)
        
        cat_distribution = await conn.fetch("""
            SELECT category, COUNT(*) as count
            FROM user_interests
            GROUP BY category
            ORDER BY count DESC
        """)
        
        # 3. User Growth
        # Note: If created_at doesn't exist, this might fail, so we'll be careful.
        try:
            growth = await conn.fetchrow("""
                SELECT 
                    (SELECT COUNT(*) FROM user_profiles) as total_users,
                    (SELECT COUNT(*) FROM user_profiles WHERE created_at >= $1) as new_users_24h
            """, today)
        except Exception:
            # Fallback if created_at is missing
            growth = {"total_users": 0, "new_users_24h": 0}
            total = await conn.fetchval("SELECT COUNT(*) FROM user_profiles")
            growth["total_users"] = total
        
        # 4. Ingestion Health
        ingestion = await conn.fetch("""
            SELECT status, COUNT(*) as count
            FROM ingestion_logs
            WHERE created_at >= NOW() - INTERVAL '24 hours'
            GROUP BY status
        """)
        
        return {
            "ai_usage": {
                "messages_today": ai_usage["messages_today"],
                "quota_users": ai_usage["quota_users"],
                "news_generations_today": ai_usage["news_generations_today"]
            },
            "content_engagement": {
                "trending": [dict(r) for r in trending],
                "category_distribution": [dict(r) for r in cat_distribution]
            },
            "user_growth": dict(growth),
            "ingestion_health": [dict(r) for r in ingestion]
        }
