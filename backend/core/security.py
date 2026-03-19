import os
import logging
import ipaddress
import jwt
from fastapi import Security, HTTPException, status, Header, Request
from fastapi.security.api_key import APIKeyHeader
from pydantic import BaseModel
from slowapi import Limiter
from slowapi.util import get_remote_address

# Use structured logging instead of print() for production
logger = logging.getLogger(__name__)


def _is_valid_ip(ip: str) -> bool:
    try:
        ipaddress.ip_address(ip)
        return True
    except ValueError:
        return False


def _is_public_ip(ip: str) -> bool:
    try:
        ip_obj = ipaddress.ip_address(ip)
        return not (
            ip_obj.is_private
            or ip_obj.is_loopback
            or ip_obj.is_reserved
            or ip_obj.is_multicast
            or ip_obj.is_link_local
            or ip_obj.is_unspecified
        )
    except ValueError:
        return False


def _normalize_ip_token(token: str) -> str:
    value = token.strip().strip('"')
    if value.startswith("[") and value.endswith("]"):
        value = value[1:-1]
    if value.startswith("for="):
        value = value[4:]
    return value.strip().strip('"')


def _parse_forwarded_for_list(header_value: str) -> list[str]:
    if not header_value:
        return []
    return [_normalize_ip_token(part) for part in header_value.split(",") if part.strip()]


def _parse_forwarded_header(header_value: str) -> list[str]:
    """
    Parse RFC 7239 Forwarded header values and extract all `for=` IP candidates.
    """
    if not header_value:
        return []

    candidates: list[str] = []
    for item in header_value.split(","):
        for part in item.split(";"):
            token = part.strip()
            if token.lower().startswith("for="):
                candidates.append(_normalize_ip_token(token))
    return candidates


def get_client_ip(request: Request) -> str:
    """
    Returns the client IP address in a proxy-aware but safe way.

    If TRUST_PROXY_HEADERS=true, the app will trust X-Forwarded-For only when
    the direct peer is in TRUSTED_PROXY_IPS (if configured). Otherwise it falls
    back to request.client.host.
    """
    peer_ip = request.client.host if request.client and request.client.host else ""
    if not peer_ip:
        return "unknown"

    trust_proxy_headers = os.getenv("TRUST_PROXY_HEADERS", "false").lower() == "true"
    logger.debug("IP detection peer=%s trust_proxy_headers=%s", peer_ip, trust_proxy_headers)
    if not trust_proxy_headers:
        return peer_ip

    trusted_proxy_ips_raw = os.getenv("TRUSTED_PROXY_IPS", "")
    trusted_proxy_ips = {ip.strip() for ip in trusted_proxy_ips_raw.split(",") if ip.strip()}

    # If a trusted proxy allowlist exists, only honor X-Forwarded-For when the
    # immediate caller is a trusted proxy.
    if trusted_proxy_ips and "*" not in trusted_proxy_ips and peer_ip not in trusted_proxy_ips:
        return peer_ip

    candidates: list[str] = []
    candidates.extend(_parse_forwarded_for_list(request.headers.get("X-Forwarded-For", "")))
    candidates.extend(_parse_forwarded_for_list(request.headers.get("X-Real-IP", "")))
    candidates.extend(_parse_forwarded_for_list(request.headers.get("X-Original-Forwarded-For", "")))
    candidates.extend(_parse_forwarded_for_list(request.headers.get("X-Envoy-External-Address", "")))
    candidates.extend(_parse_forwarded_for_list(request.headers.get("CF-Connecting-IP", "")))
    candidates.extend(_parse_forwarded_for_list(request.headers.get("True-Client-IP", "")))
    candidates.extend(_parse_forwarded_header(request.headers.get("Forwarded", "")))

    for candidate_ip in candidates:
        if _is_public_ip(candidate_ip):
            return candidate_ip

    for candidate_ip in candidates:
        if _is_valid_ip(candidate_ip):
            return candidate_ip

    return peer_ip

def get_user_or_ip(request: Request):
    """
    Returns user ID if authenticated, else falls back to remote address.
    """
    auth = request.headers.get("Authorization")
    if auth and auth.startswith("Bearer "):
        # We don't want to fully verify here (expensive), but we can use the token as a key
        return auth
    return get_client_ip(request) or get_remote_address(request)

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
