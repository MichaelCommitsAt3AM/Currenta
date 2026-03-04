import os
import httpx
import jwt
from fastapi import Security, HTTPException, status, Header
from fastapi.security.api_key import APIKeyHeader
from pydantic import BaseModel
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)

# --- Admin API Key Setup ---
ADMIN_API_KEY = os.getenv("ADMIN_API_KEY", "dev_admin_key_123")  # Replace with a strong key in prod
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

# Cache the JWKS fetching so we don't hit the Supabase API on every request
jwks_client = None

if SUPABASE_URL:
    jwks_url = f"{SUPABASE_URL}/auth/v1/.well-known/jwks.json"
    jwks_client = jwt.PyJWKClient(
        jwks_url,
        headers={"apikey": SUPABASE_KEY} if SUPABASE_KEY else {}
    )

class User(BaseModel):
    id: str
    email: str | None = None
    role: str | None = None

async def verify_supabase_jwt(authorization: str = Header(None)):
    if not authorization or not authorization.startswith("Bearer "):
        print(f"DEBUG AUTH: Authorization header missing or malformed: {authorization[:32] if authorization else 'None'}")
        return None
    
    token = authorization.split(" ")[1]
    print(f"DEBUG AUTH: Received token starting with: {token[:16]}...")
    
    if not jwks_client:
        # If Supabase URL isn't configured, we can't validate tokens asymmetrically.
        # Fallback to rejecting or accepting based on environment?
        # For now, let's reject to be safe.
        print("WARNING: SUPABASE_URL not configured. Cannot validate JWKS.")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Auth configuration error"
        )

    try:
        # Get the signing key from the JWKS matching the token's kid
        signing_key = jwks_client.get_signing_key_from_jwt(token)
        
        # Verify the token using the public key
        # Note: Supabase JWTs typically have 'aud': 'authenticated'
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
        print(f"JWT Verification error: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
        )
