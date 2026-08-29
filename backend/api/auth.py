import random
import logging
import uuid
from fastapi import APIRouter, Request, HTTPException, Depends
from pydantic import BaseModel
from typing import Optional
from ..services.email import email_service
from ..core.security import limiter, verify_supabase_jwt, User
import httpx
import os
import asyncpg

logger = logging.getLogger(__name__)

router = APIRouter()


def _redact_email(email: str) -> str:
    email = (email or "").strip()
    if "@" not in email:
        return "<redacted>"
    local, domain = email.split("@", 1)
    if not local:
        return f"<redacted>@{domain}"
    # Keep the first character and redact the rest of the local-part.
    return f"{local[0]}***@{domain}"

class OTPRequest(BaseModel):
    email: str
    name: Optional[str] = None

@router.post("/send-otp")
@limiter.limit("3/5minutes")
async def send_otp_endpoint(request: Request, otp_req: OTPRequest):
    """
    Generates and sends a 6-digit OTP to the provided email address.
    Rate-limited to 3 requests per 5 minutes per IP address to prevent abuse.
    """
    if not otp_req.email or "@" not in otp_req.email:
        raise HTTPException(status_code=400, detail="Invalid email address")

    # Generate a random 6-digit OTP
    otp = str(random.randint(100000, 999999))
    
    logger.info("Sending OTP to %s", _redact_email(otp_req.email))
    
    # Trigger the email sending via Mailtrap
    result = await email_service.send_otp(
        to_email=otp_req.email,
        otp=otp,
        user_name=otp_req.name
    )
    
    # Handle potential errors from the email service
    if isinstance(result, dict) and "error" in result:
        logger.error(f"Error in send-otp endpoint: {result['error']}")
        raise HTTPException(status_code=500, detail="Failed to send verification email")
    
    return {
        "status": "success", 
        "message": "Verification code has been sent successfully."
    }

@router.delete("/account")
async def delete_account_endpoint(request: Request, user: User = Depends(verify_supabase_jwt)):
    """
    Permanently deletes the user's account and all associated data.
    Requires a valid Supabase JWT. Uses the Service Role Key to perform 
    the deletion via the Supabase Auth Admin API.
    """
    if not user:
        raise HTTPException(status_code=401, detail="Authentication required")

    supabase_url = os.getenv("SUPABASE_URL")
    service_role_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

    if not supabase_url or not service_role_key:
        logger.error("SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY not configured")
        raise HTTPException(status_code=500, detail="Cloud configuration error")

    pool = getattr(request.app.state, "db_pool", None)
    if not pool:
        logger.error("DB Pool not found in app.state — cannot delete user data.")
        raise HTTPException(status_code=500, detail="Database connection error")

    try:
        user_uuid = uuid.UUID(user.id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid user id")

    logger.info(f"Deleting account for user: {user.id}")

    try:
        # Best-effort purge of app tables. This makes deletion work even if
        # foreign keys/cascades are missing in the deployed Supabase schema.
        async with pool.acquire() as conn:
            async with conn.transaction():
                for sql in (
                    "DELETE FROM user_ai_usage WHERE user_id = $1",
                    "DELETE FROM article_likes WHERE user_id = $1",
                    "DELETE FROM article_favorites WHERE user_id = $1",
                    "DELETE FROM article_dislikes WHERE user_id = $1",
                    "DELETE FROM article_views WHERE user_id = $1",
                    "DELETE FROM user_sub_interests WHERE user_id = $1",
                    "DELETE FROM user_muted_subcategories WHERE user_id = $1",
                    "DELETE FROM user_interests WHERE user_id = $1",
                    "DELETE FROM user_profiles WHERE user_id = $1",
                ):
                    try:
                        await conn.execute(sql, user_uuid)
                    except asyncpg.UndefinedTableError:
                        # Keep deletion resilient if schema differs across environments.
                        logger.warning("Skip delete (missing table): %s", sql)

        async with httpx.AsyncClient() as client:
            # Call Supabase Auth Admin API to delete the user
            # https://supabase.com/docs/reference/auth/admin-delete-user
            response = await client.delete(
                f"{supabase_url}/auth/v1/admin/users/{user.id}",
                headers={
                    "Authorization": f"Bearer {service_role_key}",
                    "apikey": service_role_key,
                }
            )

            if response.status_code not in (200, 204):
                logger.error(f"Supabase Admin API failed: {response.status_code} {response.text}")
                raise HTTPException(status_code=500, detail="Failed to delete account on auth provider")

        return {
            "status": "success",
            "message": "Account and all associated data have been deleted successfully."
        }
    except Exception as e:
        logger.error(f"Error during account deletion: {e}")
        if isinstance(e, HTTPException):
            raise
        raise HTTPException(status_code=500, detail="An error occurred during account deletion")
