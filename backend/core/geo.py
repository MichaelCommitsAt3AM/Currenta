import logging
import ipaddress
import os
import geoip2.database
from typing import Optional

logger = logging.getLogger(__name__)

# Path to the local GeoLite2 binary database
MMDB_PATH = os.path.join(os.path.dirname(__file__), "GeoLite2-Country.mmdb")
_reader = None

def get_reader():
    global _reader
    if _reader is None:
        if os.path.exists(MMDB_PATH):
            try:
                _reader = geoip2.database.Reader(MMDB_PATH)
                logger.info("Local GeoIP database successfully loaded.")
            except Exception as e:
                logger.error(f"Failed to load local GeoIP database: {e}")
        else:
            logger.warning(f"GeoIP database NOT FOUND at {MMDB_PATH}. Automatic detection will fail.")
    return _reader

async def get_country_from_ip(ip: str) -> Optional[str]:
    """
    Looks up the country code for an IP address using a local GeoLite2-Country database.
    Returns 2-letter ISO country code (e.g. 'KE', 'US') or None on failure.
    """
    if not ip or ip in ("127.0.0.1", "localhost", "::1"):
        logger.debug("GeoIP lookup: Skipping loopback IP %s", ip)
        return None

    try:
        ip_obj = ipaddress.ip_address(ip)
        if ip_obj.is_private or ip_obj.is_loopback or ip_obj.is_reserved:
            logger.info("GeoIP lookup: IP %s is private/reserved, detection skipping.", ip)
            return None
    except ValueError:
        logger.warning("GeoIP lookup skipped for invalid IP value: %s", ip)
        return None
        
    reader = get_reader()
    if not reader:
        return None

    try:
        # geoip2 database lookup is extremely fast (mmap)
        response = reader.country(ip)
        country_code = response.country.iso_code
        if country_code and len(country_code) == 2:
            return country_code.upper()
    except Exception as e:
        # This will catch addresses not in the database (common for internal IPs if not filtered above)
        logger.debug("Local GeoIP lookup fail for %s: %s", ip, e)
        
    return None
