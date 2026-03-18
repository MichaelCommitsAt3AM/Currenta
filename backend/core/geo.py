import httpx
import logging
import ipaddress
from typing import Optional

logger = logging.getLogger(__name__)

async def get_country_from_ip(ip: str) -> Optional[str]:
    """
    Looks up the country code for an IP address using ipwho.is over HTTPS.
    Returns 2-letter ISO country code (e.g. 'KE', 'US') or None on failure.
    """
    if not ip or ip in ("127.0.0.1", "localhost", "::1"):
        return None

    try:
        ip_obj = ipaddress.ip_address(ip)
        if ip_obj.is_private or ip_obj.is_loopback or ip_obj.is_reserved:
            return None
    except ValueError:
        logger.warning("GeoIP lookup skipped for invalid IP value: %s", ip)
        return None
        
    try:
        async with httpx.AsyncClient(timeout=2.0) as client:
            response = await client.get(f"https://ipwho.is/{ip}")
            if response.status_code == 200:
                data = response.json()
                if data.get("success") is True:
                    country_code = data.get("country_code")
                    if isinstance(country_code, str) and len(country_code) == 2:
                        return country_code.upper()
    except Exception as e:
        logger.warning("GeoIP lookup failed for %s: %s", ip, e)
        
    return None
