from fastapi import APIRouter, HTTPException, Depends, Request
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import List, Optional
import os
import asyncpg
import google.generativeai as genai
import json
from datetime import date
from ..core.security import limiter, verify_supabase_jwt, User

router = APIRouter()

# Constants for Abuse Prevention
MAX_HISTORY_DEPTH = 6
MAX_INPUT_CHARS = 500
DAILY_MESSAGE_LIMIT = 50

# Gemini Configuration
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)

class ChatMessage(BaseModel):
    role: str # 'user' or 'model'
    content: str

class ChatRequest(BaseModel):
    article_id: str
    messages: List[ChatMessage]

def get_db(request: Request) -> asyncpg.Pool:
    pool = request.app.state.db_pool
    if not pool:
        raise HTTPException(status_code=500, detail="Database connection not available")
    return pool

@router.post("")
@limiter.limit("3/minute")
async def chat_with_article(
    request: Request,
    chat_req: ChatRequest,
    db_pool: asyncpg.Pool = Depends(get_db),
    user: User = Depends(verify_supabase_jwt)
):
    """
    Handles a chat conversation about a specific article.
    Implements abuse prevention logic.
    """
    if not user:
        raise HTTPException(status_code=401, detail="Authentication required")
        
    if not GEMINI_API_KEY:
        raise HTTPException(status_code=500, detail="Gemini API key not configured")

    # 1. Enforce Input Length
    last_message = chat_req.messages[-1].content
    if len(last_message) > MAX_INPUT_CHARS:
        raise HTTPException(
            status_code=400, 
            detail=f"Message too long. Max {MAX_INPUT_CHARS} characters."
        )

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
                    # Reset for the new day
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
                # First time user
                await conn.execute(
                    "INSERT INTO user_ai_usage (user_id, daily_count, last_reset_at) VALUES ($1, 1, $2)",
                    user.id, today
                )

            # 3. Fetch article context
            article = await conn.fetchrow(
                "SELECT title, summary, source_name FROM articles WHERE id = $1",
                chat_req.article_id
            )
            
        if not article:
            raise HTTPException(status_code=404, detail="Article not found")

        # 4. Prepare Model with Strict Instructions
        model = genai.GenerativeModel(
            model_name='gemini-2.5-flash-lite',
            system_instruction=(
                f"You are a specialized news assistant for the 'Currenta' app. "
                f"Your ONLY purpose is to help the user understand this specific article:\n\n"
                f"Title: {article['title']}\n"
                f"Source: {article['source_name']}\n"
                f"Summary: {article['summary']}\n\n"
                f"STRICT RULES:\n"
                f"1. ONLY answer questions related to this article.\n"
                f"2. If the user asks about unrelated topics, politely refuse and redirect them to the article.\n"
                f"3. Do not engage in general roleplay, coding assistance, or creative writing.\n"
                f"4. Keep responses concise and factual.\n"
                f"5. If you don't know something based on the article or general news context, say so."
            )
        )

        # 5. Limit History Depth
        safe_messages = chat_req.messages[-(MAX_HISTORY_DEPTH + 1):-1]
        history = []
        for msg in safe_messages:
            history.append({
                "role": "user" if msg.role == "user" else "model",
                "parts": [msg.content]
            })

        # 6. Start chat and stream
        chat = model.start_chat(history=history)
        
        async def generate():
            try:
                response = await chat.send_message_async(last_message, stream=True)
                async for chunk in response:
                    if chunk.text:
                        yield json.dumps({"content": chunk.text}) + "\n"
            except Exception as e:
                yield json.dumps({"error": str(e)}) + "\n"

        return StreamingResponse(generate(), media_type="application/x-ndjson")

    except HTTPException:
        raise
    except Exception as e:
        print(f"Error in chat_with_article: {e}")
        raise HTTPException(status_code=500, detail="An internal error occurred.")

