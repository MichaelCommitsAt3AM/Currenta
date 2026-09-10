import hashlib
import logging
import os
import re

import asyncpg
from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel

from ..core.security import limiter, get_client_ip

logger = logging.getLogger(__name__)

router = APIRouter()

# Deliberately loose — the client already validates, and an over-strict regex
# rejects valid addresses. We just want an "@" with something either side and a
# dotted domain, plus a length cap.
_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
_MAX_EMAIL_LEN = 254

# Salt keeps the stored ip_hash from being a plain rainbow-table lookup. Not a
# secret in the cryptographic sense; override per-environment if desired.
_IP_SALT = os.environ.get("WAITLIST_IP_SALT", "currenta-waitlist-v1")


class WaitlistRequest(BaseModel):
    email: str
    ref: str | None = None
    ts: str | None = None
    suspected_bot: bool = False


def _redact_email(email: str) -> str:
    if "@" not in email:
        return "<redacted>"
    local, domain = email.split("@", 1)
    return f"{local[:1]}***@{domain}"


def _hash_ip(ip: str) -> str:
    return hashlib.sha256(f"{_IP_SALT}:{ip}".encode()).hexdigest()


@router.post("")
@limiter.limit("6/hour")
async def join_waitlist(request: Request, body: WaitlistRequest):
    """
    Record an early-access signup from the marketing site.

    Idempotent: re-submitting an email that's already on the list returns 200
    with ``new=false`` rather than an error, so the client can always show a
    friendly confirmation.
    """
    email = (body.email or "").strip().lower()
    if not email or len(email) > _MAX_EMAIL_LEN or not _EMAIL_RE.match(email):
        raise HTTPException(status_code=422, detail="Invalid email address")

    pool = getattr(request.app.state, "db_pool", None)
    if pool is None:
        logger.error("[waitlist] DB pool unavailable — cannot record signup")
        raise HTTPException(status_code=503, detail="Service temporarily unavailable")

    user_agent = (request.headers.get("user-agent") or "")[:500] or None
    referrer = (body.ref or "").strip()[:500] or None
    ip_hash = _hash_ip(get_client_ip(request))

    try:
        async with pool.acquire() as conn:
            row = await conn.fetchrow(
                """
                INSERT INTO waitlist_signups
                    (email, referrer, user_agent, ip_hash, suspected_bot, source)
                VALUES ($1, $2, $3, $4, $5, 'landing')
                ON CONFLICT (email) DO NOTHING
                RETURNING id
                """,
                email,
                referrer,
                user_agent,
                ip_hash,
                bool(body.suspected_bot),
            )
    except asyncpg.UndefinedTableError:
        logger.error("[waitlist] waitlist_signups table missing — run migration 20260910200000")
        raise HTTPException(status_code=503, detail="Service temporarily unavailable")
    except Exception:
        logger.exception("[waitlist] insert failed")
        raise HTTPException(status_code=503, detail="Service temporarily unavailable")

    is_new = row is not None
    logger.info(
        "[waitlist] signup %s (new=%s, suspected_bot=%s)",
        _redact_email(email),
        is_new,
        bool(body.suspected_bot),
    )
    return {"status": "ok", "new": is_new}
