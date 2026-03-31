from fastapi import APIRouter, HTTPException, Depends, Request
from pydantic import BaseModel
from typing import List, Optional
import logging
from datetime import datetime, timezone
import uuid

from ..core.security import verify_is_admin, User
from ..services.ingestion import (
    scrape_article_sync, 
    summarize_article, 
    embed_text, 
    generate_content_hash,
    calculate_ranking_score,
    log_ingestion_event,
    LLM_PROVIDER
)
import asyncio

logger = logging.getLogger(__name__)

router = APIRouter()

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

class PublishRequest(BaseModel):
    title: str
    summary: str
    categories: List[str]
    subcategory: str
    source_name: str
    original_url: str
    image_url: Optional[str] = None
    country_code: Optional[str] = "US"
    is_paywalled: bool = False

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
    logger.info(f"Admin {user.id} requested draft for URL: {url}")
    
    try:
        # 1. Scrape
        scraper_result = await asyncio.to_thread(scrape_article_sync, url)
        if scraper_result.get("error"):
            raise HTTPException(status_code=400, detail=f"Scraping failed: {scraper_result['error']}")
        
        text = scraper_result.get("text", "")
        if not text or len(text) < 100:
            raise HTTPException(status_code=400, detail="Insufficient content found at URL")
        
        # 2. Summarize & Classify
        llm_res = await summarize_article(
            text=text,
            provider=LLM_PROVIDER,
            category_hint=None
        )
        
        # 3. Prepare response
        # Extract source name from URL if not provided by scraper
        source_name = scraper_result.get("source_name") or url.split("//")[-1].split("/")[0]
        
        return NewsDraft(
            title=llm_res.get("title", "Unknown Title"),
            summary=llm_res.get("summary", ""),
            categories=llm_res.get("categories", ["world"]),
            subcategory=llm_res.get("subcategory", ""),
            source_name=source_name,
            original_url=url,
            image_url=scraper_result.get("image_url")
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating draft: {e}")
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
    logger.info(f"Admin {user.id} publishing article: {publish_req.title}")
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
                raise HTTPException(status_code=409, detail="Article already exists (URL or content hash match)")
            
            # Generate Embedding
            embedding = await embed_text(f"{publish_req.title}\n\n{publish_req.summary}")
            
            # Calculate ranking score
            published_at = datetime.now(timezone.utc)
            ranking_score = calculate_ranking_score(published_at, trend_score=0.0)
            
            # Insert
            article_id = await conn.fetchval(
                """
                INSERT INTO articles (
                    title, summary, original_url, source_name, 
                    published_at, categories, subcategory, 
                    country_code, image_url, content_hash, 
                    embedding, ranking_score, ingestion_method,
                    is_paywalled
                ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
                RETURNING id
                """,
                publish_req.title,
                publish_req.summary,
                publish_req.original_url,
                publish_req.source_name,
                published_at,
                publish_req.categories,
                publish_req.subcategory,
                publish_req.country_code,
                publish_req.image_url,
                content_hash,
                embedding,
                ranking_score,
                "manual_admin",
                publish_req.is_paywalled
            )
            
            await log_ingestion_event(
                conn,
                publish_req.original_url,
                "SUCCESS",
                source_name=publish_req.source_name,
                dedup_decision="MANUAL_PUBLISH",
                has_text=True,
                has_image=bool(publish_req.image_url)
            )
            
            return {"status": "success", "article_id": str(article_id)}
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error publishing news: {e}")
        raise HTTPException(status_code=500, detail=str(e))
