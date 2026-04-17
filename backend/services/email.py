import os
import logging
import asyncio
from typing import Optional
import mailtrap as mt

logger = logging.getLogger(__name__)

class EmailService:
    def __init__(self):
        token = os.getenv("MAILTRAP_TOKEN")
        if not token:
            logger.error("MAILTRAP_TOKEN not found in environment variables")
            # We don't raise error here to allow app to start even if mail is misconfigured, 
            # but methods will fail.
            self.client = None
        else:
            self.client = mt.MailtrapClient(token=token)
        
        self.sender = mt.Address(email="no-reply@mail.currenta.tech", name="Currenta")

    async def send_otp(self, to_email: str, otp: str, user_name: Optional[str] = None):
        """
        Sends a 6-digit OTP to the specified email address using a premium HTML template.
        """
        if not self.client:
            logger.error("EmailService: Mailtrap client not initialized (missing token)")
            return {"error": "Email service not configured"}

        user_display = user_name or "there"
        
        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Verification Code</title>
            <style>
                body {{
                    font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    background-color: #0A0C14;
                    color: #FFFFFF;
                    margin: 0;
                    padding: 0;
                }}
                .container {{
                    max-width: 600px;
                    margin: 0 auto;
                    padding: 40px 20px;
                }}
                .header {{
                    text-align: center;
                    margin-bottom: 40px;
                }}
                .logo {{
                    font-size: 28px;
                    font-weight: 800;
                    color: #6C63FF;
                    letter-spacing: -0.5px;
                }}
                .content {{
                    background-color: #171B2F;
                    border-radius: 24px;
                    padding: 40px;
                    text-align: center;
                    border: 1px solid #262A3E;
                }}
                h1 {{
                    font-size: 24px;
                    font-weight: 700;
                    margin-bottom: 16px;
                    color: #FFFFFF;
                }}
                p {{
                    color: #8890B5;
                    font-size: 16px;
                    line-height: 1.6;
                    margin-bottom: 32px;
                }}
                .otp-container {{
                    background-color: #0A0C14;
                    border: 2px dashed #6C63FF;
                    border-radius: 16px;
                    padding: 24px;
                    margin-bottom: 32px;
                }}
                .otp-code {{
                    font-size: 48px;
                    font-weight: 800;
                    color: #FFFFFF;
                    letter-spacing: 8px;
                    margin: 0;
                }}
                .footer {{
                    text-align: center;
                    margin-top: 40px;
                    color: #525C8B;
                    font-size: 14px;
                }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <div class="logo">Currenta</div>
                </div>
                <div class="content">
                    <h1>Verify your email</h1>
                    <p>Hi {user_display},<br>Your verification code is:</p>
                    <div class="otp-container">
                        <div class="otp-code">{otp}</div>
                    </div>
                    <p style="margin-bottom: 0;">This code expires in <strong>10 minutes</strong>.<br>If you didn't request this code, you can safely ignore this email.</p>
                </div>
                <div class="footer">
                    &copy; 2026 Currenta. All rights reserved.
                </div>
            </div>
        </body>
        </html>
        """
        
        mail = mt.Mail(
            sender=self.sender,
            to=[mt.Address(email=to_email)],
            subject="Your Currenta Verification Code",
            html=html_content,
            category="OTP Verification",
        )

        try:
            response = await asyncio.to_thread(self.client.send, mail)
            logger.info(f"Email sent successfully to {to_email}")
            return response
        except Exception as e:
            logger.error(f"Failed to send email to {to_email}: {e}")
            return {"error": str(e)}

# Singleton instance
email_service = EmailService()
