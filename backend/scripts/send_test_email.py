import asyncio
import os
import sys
from dotenv import load_dotenv

# Add backend directory to path so we can import services
sys.path.append(os.path.join(os.path.dirname(__file__), ".."))

# Load .env BEFORE importing services that initialize on import
load_dotenv()

from services.email import email_service

async def main():
    test_email = "test@example.com"
    if len(sys.argv) > 1:
        test_email = sys.argv[1]
        
    print(f"📧 Attempting to send a test OTP email to: {test_email}")
    print(f"🔑 Using Mailtrap Token: {os.getenv('MAILTRAP_TOKEN')[:4]}...{os.getenv('MAILTRAP_TOKEN')[-4:] if os.getenv('MAILTRAP_TOKEN') else 'None'}")
    
    response = await email_service.send_otp(
        to_email=test_email,
        otp="123456",
        user_name="Test User"
    )
    
    if isinstance(response, dict) and "error" in response:
        print(f"❌ Failed to send email: {response['error']}")
    else:
        print(f"✅ Email sent successfully! Response: {response}")

if __name__ == "__main__":
    asyncio.run(main())
