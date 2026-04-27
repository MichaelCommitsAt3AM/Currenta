import os
import logging
import asyncio
import smtplib
from typing import Optional
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import mailtrap as mt

logger = logging.getLogger(__name__)

class EmailService:
    def __init__(self):
        self.token = os.getenv("MAILTRAP_TOKEN")
        self.use_sandbox = os.getenv("USE_MAILTRAP_SANDBOX", "false").lower() == "true"
        
        # Sandbox credentials
        self.sb_host = os.getenv("MAILTRAP_SANDBOX_HOST", "sandbox.smtp.mailtrap.io")
        self.sb_port = int(os.getenv("MAILTRAP_SANDBOX_PORT", 2525))
        self.sb_user = os.getenv("MAILTRAP_SANDBOX_USER")
        self.sb_pass = os.getenv("MAILTRAP_SANDBOX_PASS")
        
        # Sender configuration
        sender_email = os.getenv("MAILTRAP_SENDER_EMAIL", "no-reply@currenta.tech")
        sender_name = os.getenv("MAILTRAP_SENDER_NAME", "Currenta")
        self.sender = mt.Address(email=sender_email, name=sender_name)
        
        if not self.use_sandbox:
            if not self.token:
                logger.error("MAILTRAP_TOKEN not found. Email service will fail in production mode.")
                self.client = None
            else:
                self.client = mt.MailtrapClient(token=self.token)
        else:
            logger.info("EmailService: Initialized in SANDBOX mode (SMTP)")
            self.client = None

    async def _send_via_smtp(self, to_email: str, subject: str, html_content: str, text_content: str):
        """Internal method to send email via Mailtrap Sandbox SMTP"""
        if not self.sb_user or not self.sb_pass:
            return {"error": "Sandbox credentials missing"}
            
        message = MIMEMultipart("alternative")
        message["Subject"] = subject
        message["From"] = f"{self.sender.name} <{self.sender.email}>"
        message["To"] = to_email
        
        message.attach(MIMEText(text_content, "plain"))
        message.attach(MIMEText(html_content, "html"))
        
        try:
            await asyncio.to_thread(self._smtp_sync_send, to_email, message.as_string())
            return {"status": "success", "mode": "sandbox"}
        except Exception as e:
            logger.error(f"SMTP Sandbox failed: {e}")
            return {"error": str(e)}

    def _smtp_sync_send(self, to_email: str, message_str: str):
        with smtplib.SMTP(self.sb_host, self.sb_port) as server:
            server.starttls()
            server.login(self.sb_user, self.sb_pass)
            server.sendmail(self.sender.email, to_email, message_str)

    async def send_otp(self, to_email: str, otp: str, user_name: Optional[str] = None):
        """
        Sends a 6-digit OTP to the specified email address using a premium HTML template.
        """
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
                    border: 2px solid #262A3E;
                    border-radius: 16px;
                    padding: 32px 10px;
                    margin-bottom: 32px;
                    text-align: center;
                }}
                .otp-code {{
                    font-size: 36px;
                    font-weight: 800;
                    color: #FFFFFF;
                    letter-spacing: 6px;
                    margin: 0;
                    white-space: nowrap;
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
        
        if self.use_sandbox:
            return await self._send_via_smtp(
                to_email=to_email,
                subject="Your Currenta Verification Code",
                html_content=html_content,
                text_content=f"Your verification code is: {otp}"
            )

        if not self.client:
            logger.error("EmailService: Mailtrap client not initialized (missing token)")
            return {"error": "Email service not configured"}

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
            # If production fails, try sandbox as a safety net if we are not in prod env
            if os.getenv("ENV", "development") != "production":
                logger.info("Production email failed, attempting Sandbox fallback...")
                return await self._send_via_smtp(
                    to_email=to_email,
                    subject="[Fallback] Your Currenta Verification Code",
                    html_content=html_content,
                    text_content=f"Your verification code is: {otp}"
                )
            return {"error": str(e)}

# Singleton instance
email_service = EmailService()
