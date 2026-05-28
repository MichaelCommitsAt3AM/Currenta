import asyncio
import os
import sys

sys.path.append(os.path.join(os.path.dirname(__file__), ".."))

from core.geo import get_country_from_ip

async def test():
    # Test a few known public IPs:
    ips = {
        "8.8.8.8": "US",
        "197.232.0.1": "KE",
        "102.89.1.1": "NG",
    }
    
    print("Testing local GeoIP database lookup...")
    for ip, expected in ips.items():
        res = await get_country_from_ip(ip)
        print(f"IP: {ip} -> Detected: {res} (Expected: {expected})")
        if res == expected:
            print("  ✅ Match!")
        else:
            print("  ❌ Mismatch or detection failed.")

if __name__ == "__main__":
    asyncio.run(test())
