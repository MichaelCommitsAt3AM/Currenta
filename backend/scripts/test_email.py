import os
import asyncio
from dotenv import load_dotenv

# Load .env before imports
load_dotenv()

import sys
from pathlib import Path

# Add project root to sys.path
sys.path.append(str(Path(__file__).parent.parent.parent))

from backend.services.email import email_service

async def test_send_otp():
    print("🚀 Starting Mailtrap OTP test...")
    
    test_email = "michaelnjonge905@gmail.com" # Using user's email from snippet
    test_otp = "123456"
    test_name = "Michael"
    
    print(f"📧 Attempting to send '{test_otp}' to {test_email}...")
    
    result = await email_service.send_otp(
        to_email=test_email,
        otp=test_otp,
        user_name=test_name
    )
    
    if isinstance(result, dict) and "error" in result:
        print(f"❌ Test Failed: {result['error']}")
    else:
        print(f"✅ Test Successful! Response: {result}")
        print("💡 Check your Mailtrap dashboard (or your email if using production) to verify delivery.")

if __name__ == "__main__":
    asyncio.run(test_send_otp())
