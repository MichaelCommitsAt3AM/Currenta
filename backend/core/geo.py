import httpx
import logging
from typing import Optional

logger = logging.getLogger(__name__)

async def get_country_from_ip(ip: str) -> Optional[str]:
    """
    Looks up the country code for an IP address using ip-api.com.
    Returns 2-letter ISO country code (e.g. 'KE', 'US') or None on failure.
    
    Note: Free tier of ip-api.com is limited to 45 requests per minute.
    """
    if not ip or ip in ("127.0.0.1", "localhost", "::1"):
        return None
        
    try:
        async with httpx.AsyncClient(timeout=2.0) as client:
            # We use HTTP for the free tier of ip-api.com
            response = await client.get(f"http://ip-api.com/json/{ip}?fields=status,countryCode")
            if response.status_code == 200:
                data = response.json()
                if data.get("status") == "success":
                    return data.get("countryCode")
    except Exception as e:
        logger.warning(f"GeoIP lookup failed for {ip}: {e}")
        
    return None
