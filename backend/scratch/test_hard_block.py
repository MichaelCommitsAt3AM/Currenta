import asyncio
import sys
import os

# Add the project root to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))

from backend.services.ingestion import is_junk_url

def test_hard_block():
    print("Testing hard block logic...")
    
    # Test forbidden domain
    forbidden_url = "https://streamlinefeed.co.ke/article/123"
    reason = is_junk_url(forbidden_url)
    print(f"URL: {forbidden_url}")
    print(f"Blocked: {reason is not None}")
    print(f"Reason: {reason}")
    assert reason is not None
    assert "Globally forbidden domain" in reason
    
    # Test betting domain (existing logic)
    betting_url = "https://www.bet365.com/soccer"
    reason = is_junk_url(betting_url)
    print(f"\nURL: {betting_url}")
    print(f"Blocked: {reason is not None}")
    print(f"Reason: {reason}")
    assert reason is not None
    assert "betting domain hint" in reason
    
    # Test allowed domain
    allowed_url = "https://www.reuters.com/world/news"
    reason = is_junk_url(allowed_url)
    print(f"\nURL: {allowed_url}")
    print(f"Blocked: {reason is not None}")
    assert reason is None
    
    print("\nAll tests passed!")

if __name__ == "__main__":
    test_hard_block()
