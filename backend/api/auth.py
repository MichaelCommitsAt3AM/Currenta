import random
import logging
from fastapi import APIRouter, Request, HTTPException
from pydantic import BaseModel
from typing import Optional
from ..services.email import email_service
from ..core.security import limiter

logger = logging.getLogger(__name__)

router = APIRouter()

class OTPRequest(BaseModel):
    email: str
    name: Optional[str] = None

@router.post("/send-otp")
@limiter.limit("3/5minutes")
async def send_otp_endpoint(request: Request, otp_req: OTPRequest):
    """
    Generates and sends a 6-digit OTP to the provided email address.
    Rate-limited to 3 requests per 5 minutes per IP address to prevent abuse.
    """
    if not otp_req.email or "@" not in otp_req.email:
        raise HTTPException(status_code=400, detail="Invalid email address")

    # Generate a random 6-digit OTP
    otp = str(random.randint(100000, 999999))
    
    logger.info(f"Sending OTP to {otp_req.email}")
    
    # Trigger the email sending via Mailtrap
    result = await email_service.send_otp(
        to_email=otp_req.email,
        otp=otp,
        user_name=otp_req.name
    )
    
    # Handle potential errors from the email service
    if isinstance(result, dict) and "error" in result:
        logger.error(f"Error in send-otp endpoint: {result['error']}")
        raise HTTPException(status_code=500, detail="Failed to send verification email")
    
    return {
        "status": "success", 
        "message": "Verification code has been sent successfully."
    }
