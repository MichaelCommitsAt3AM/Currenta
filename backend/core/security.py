import os
import logging
import jwt
from fastapi import Security, HTTPException, status, Header, Request
from fastapi.security.api_key import APIKeyHeader
from pydantic import BaseModel
from slowapi import Limiter
from slowapi.util import get_remote_address

# Use structured logging instead of print() for production
logger = logging.getLogger(__name__)

def get_user_or_ip(request: Request):
    """
    Returns user ID if authenticated, else falls back to remote address.
    """
    auth = request.headers.get("Authorization")
    if auth and auth.startswith("Bearer "):
        # We don't want to fully verify here (expensive), but we can use the token as a key
        return auth
    return get_remote_address(request)

limiter = Limiter(key_func=get_user_or_ip)


# --- Admin API Key Setup ---
ADMIN_API_KEY = os.getenv("ADMIN_API_KEY")
if not ADMIN_API_KEY:
    raise RuntimeError(
        "ADMIN_API_KEY env var is not set. "
        "Generate a strong random key and set it in your environment before starting."
    )

admin_api_key_header = APIKeyHeader(name="X-API-Key", auto_error=True)

async def verify_admin_api_key(api_key: str = Security(admin_api_key_header)):
    if api_key != ADMIN_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Admin API Key",
        )
    return api_key

# --- Supabase JWKS Setup ---
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_ANON_KEY", "")

# Cache the JWKS fetching so we don't hit the Supabase API on every request.
# lifespan=86400 caches the public keys for 24 hours (they rarely rotate).
jwks_client = None

if SUPABASE_URL:
    jwks_url = f"{SUPABASE_URL}/auth/v1/.well-known/jwks.json"
    jwks_client = jwt.PyJWKClient(
        jwks_url,
        headers={"apikey": SUPABASE_KEY} if SUPABASE_KEY else {},
        lifespan=86400,
    )

class User(BaseModel):
    id: str
    email: str | None = None
    role: str | None = None

async def verify_supabase_jwt(authorization: str = Header(None)):
    if not authorization or not authorization.startswith("Bearer "):
        # No token is a valid state for public/optional-auth endpoints
        return None

    token = authorization.split(" ")[1]

    if not jwks_client:
        logger.error("SUPABASE_URL not configured — cannot validate JWT via JWKS.")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Auth configuration error"
        )

    try:
        signing_key = jwks_client.get_signing_key_from_jwt(token)
        payload = jwt.decode(
            token,
            signing_key.key,
            algorithms=["ES256"],
            audience="authenticated",
            options={"verify_exp": True}
        )
        return User(
            id=payload.get("sub"),
            email=payload.get("email"),
            role=payload.get("role")
        )

    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token has expired")
    except jwt.InvalidAudienceError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token audience")
    except jwt.DecodeError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token formatting")
    except Exception as e:
        logger.warning("JWT verification failed: %s", type(e).__name__)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
        )
