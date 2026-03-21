import logging
from fastapi import APIRouter, HTTPException, Depends, Request
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import List, Optional
from uuid import UUID
import os
import asyncpg
import json
from datetime import date

from google import genai
from google.genai import types as genai_types
import asyncio

from ..core.security import limiter, verify_supabase_jwt, User

logger = logging.getLogger(__name__)

router = APIRouter()

# --- Abuse Prevention Constants ---
MAX_HISTORY_DEPTH = 6
MAX_INPUT_CHARS = 500
DAILY_MESSAGE_LIMIT = 50

# --- LLM Provider Selection ---
LLM_PROVIDER = os.environ.get("LLM_PROVIDER", "gemini").lower()

# --- Gemini Client (Google AI Studio) ---
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
_gemini_client: genai.Client | None = None
if GEMINI_API_KEY:
    _gemini_client = genai.Client(api_key=GEMINI_API_KEY)

# --- Vertex AI Client (Google Cloud) ---
# Recommendation 5: Use IAM (Service Account) in production.
# If running on GCP, the SDK will automatically use the environment's service account.
VERTEX_PROJECT = os.environ.get("VERTEX_PROJECT")
VERTEX_LOCATION = os.environ.get("VERTEX_LOCATION", "us-central1")
_vertex_client: genai.Client | None = None

# If LLM_PROVIDER is vertex, we try to initialize it.
# In GCP Cloud Run, VERTEX_PROJECT can often be inferred, but we check for it or the provider flag.
if LLM_PROVIDER == "vertex" or VERTEX_PROJECT:
    try:
        _vertex_client = genai.Client(
            vertexai=True,
            project=VERTEX_PROJECT, # Can be None if running on GCP
            location=VERTEX_LOCATION
        )
        logger.info("Vertex AI client initialized (IAM/ADC).")
    except Exception as e:
        logger.warning(f"Could not initialize Vertex AI client: {e}")

def _get_active_client() -> genai.Client | None:
    """Returns the client based on LLM_PROVIDER setting."""
    if LLM_PROVIDER == "vertex":
        return _vertex_client
    return _gemini_client

# The grounding tool using the new SDK's typed config
_GOOGLE_SEARCH_TOOL = genai_types.Tool(google_search=genai_types.GoogleSearch())


class ChatMessage(BaseModel):
    role: str  # 'user' or 'model'
    content: str


class ChatRequest(BaseModel):
    article_id: UUID  # Pydantic validates UUID format; rejects garbage inputs automatically
    messages: List[ChatMessage]


def get_db(request: Request) -> asyncpg.Pool:
    pool = request.app.state.db_pool
    if not pool:
        raise HTTPException(status_code=500, detail="Database connection not available")
    return pool


def _build_system_instruction(article: dict) -> str:
    return (
        f"You are a specialized news assistant for the 'Currenta' app. "
        f"Your primary purpose is to help the user understand this specific article and its broader context:\n\n"
        f"Title: {article['title']}\n"
        f"Source: {article['source_name']}\n"
        f"Summary: {article['summary']}\n\n"
        f"CONTEXTUAL SEARCH CAPABILITY:\n"
        f"- You have access to Google Search to provide background, historical context, or related events "
        f"that help explain current news more deeply.\n"
        f"- Use search when you need to explain 'the events leading up to this story' or complex background details "
        f"not fully covered in the summary provided.\n\n"
        f"STRICT RULES:\n"
        f"1. RELEVANCE: While you can search for external context, your conversation MUST remain centered on this article. "
        f"Do not drift into unrelated topics or perform general searches that don't serve the understanding of this article.\n"
        f"2. NARRATIVE: Explain the story's context like a journalist. Connect external facts back to the specific actors "
        f"and events mentioned in the article above.\n"
        f"3. NO FLUFF: Do not engage in coding, general advice, or unrelated creative tasks. Your domain is strictly news context.\n"
        f"4. FACTUALITY: If search results are unavailable or inconclusive, state that clearly.\n"
        f"5. CONCISENESS: Your responses MUST be extremely concise. Limit yourself to exactly ONE short paragraph or a few bullet points. "
        f"Do not provide long-winded explanations even if the user asks for detail."
    )


@router.post("")
@limiter.limit("3/minute;30/hour")
async def chat_with_article(
    request: Request,
    chat_req: ChatRequest,
    db_pool: asyncpg.Pool = Depends(get_db),
    user: User = Depends(verify_supabase_jwt)
):
    """
    Handles a chat conversation about a specific article.
    Uses the google-genai SDK (v1+) with async streaming and Google Search grounding.
    """
    if not user:
        raise HTTPException(status_code=401, detail="Authentication required")

    active_client = _get_active_client()
    if not active_client:
        provider_name = "Vertex AI" if LLM_PROVIDER == "vertex" else "Gemini (AI Studio)"
        raise HTTPException(status_code=500, detail=f"{provider_name} is not configured (check env vars)")

    # 1. Enforce Input Length
    if not chat_req.messages:
        raise HTTPException(status_code=400, detail="No messages provided.")
    last_message = chat_req.messages[-1].content
    if len(last_message) > MAX_INPUT_CHARS:
        raise HTTPException(
            status_code=400,
            detail=f"Message too long. Max {MAX_INPUT_CHARS} characters."
        )

    try:
        article = None
        max_retries = 3
        for attempt in range(max_retries):
            try:
                async with db_pool.acquire() as conn:
                    # 2. Check/Update Daily Quota
                    today = date.today()
                    usage = await conn.fetchrow(
                        "SELECT daily_count, last_reset_at FROM user_ai_usage WHERE user_id = $1",
                        user.id
                    )

                    if usage:
                        if usage['last_reset_at'] < today:
                            await conn.execute(
                                "UPDATE user_ai_usage SET daily_count = 1, last_reset_at = $1 WHERE user_id = $2",
                                today, user.id
                            )
                        elif usage['daily_count'] >= DAILY_MESSAGE_LIMIT:
                            raise HTTPException(
                                status_code=429,
                                detail=f"Daily chat limit of {DAILY_MESSAGE_LIMIT} messages reached."
                            )
                        else:
                            await conn.execute(
                                "UPDATE user_ai_usage SET daily_count = daily_count + 1 WHERE user_id = $1",
                                user.id
                            )
                    else:
                        await conn.execute(
                            "INSERT INTO user_ai_usage (user_id, daily_count, last_reset_at) VALUES ($1, 1, $2)",
                            user.id, today
                        )

                    # 3. Fetch article context
                    article = await conn.fetchrow(
                        "SELECT title, summary, source_name FROM articles WHERE id = $1",
                        str(chat_req.article_id)
                    )
                    break # Success
            except (asyncpg.PostgresError, OSError) as e:
                # Re-raise HTTPException (like the rate limit 429) so it's not caught by the generic DB retry
                if isinstance(e, HTTPException):
                    raise
                if attempt < max_retries - 1:
                    logger.warning(f"Database operation failed in chat_with_article (attempt {attempt+1}/{max_retries}): {e}. Retrying...")
                    await asyncio.sleep(0.2 * (2 ** attempt))
                    continue
                logger.error("Error in chat_with_article DB operations: %s", e)
                raise HTTPException(status_code=500, detail="Database connection error.")

        if not article:
            raise HTTPException(status_code=404, detail="Article not found")

        # 4. Build history for the chat session (all messages except the last one)
        safe_messages = chat_req.messages[-(MAX_HISTORY_DEPTH + 1):-1]
        history: list[genai_types.Content] = []
        for msg in safe_messages:
            history.append(
                genai_types.Content(
                    role="user" if msg.role == "user" else "model",
                    parts=[genai_types.Part.from_text(text=msg.content)],
                )
            )

        # 5. Create an async chat session with grounding + system instruction
        chat_session = active_client.aio.chats.create(
            model="gemini-2.5-flash-lite",
            config=genai_types.GenerateContentConfig(
                system_instruction=_build_system_instruction(article),
                tools=[_GOOGLE_SEARCH_TOOL],
                max_output_tokens=1024,
                temperature=0.7,
            ),
            history=history,
        )

        # 6. Stream the response
        async def generate():
            received_any_text = False
            try:
                async for chunk in await chat_session.send_message_stream(last_message):
                    try:
                        # Check safety finish reason
                        if chunk.candidates:
                            candidate = chunk.candidates[0]
                            # finish_reason is now an enum; value 'SAFETY' means blocked
                            if candidate.finish_reason and candidate.finish_reason.name == "SAFETY":
                                yield json.dumps({"error": "I'm sorry, I can't answer that due to safety policies."}) + "\n"
                                return

                        text = chunk.text
                        if text:
                            received_any_text = True
                            yield json.dumps({"content": text}) + "\n"
                    except (AttributeError, ValueError):
                        # Chunk may have no text (e.g. grounding metadata only chunk) — skip
                        continue

                if not received_any_text:
                    yield json.dumps({"error": "The assistant was unable to generate a response. Please try rephrasing your question."}) + "\n"

            except Exception as e:
                logger.error("Chat stream error: %s", e)
                yield json.dumps({"error": "An error occurred while generating the response."}) + "\n"

        return StreamingResponse(generate(), media_type="application/x-ndjson")

    except HTTPException:
        raise
    except Exception as e:
        logger.error("Error in chat_with_article: %s", e)
        raise HTTPException(status_code=500, detail="An internal error occurred.")
