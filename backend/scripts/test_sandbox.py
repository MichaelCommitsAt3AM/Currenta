import os
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from dotenv import load_dotenv

# Load .env
load_dotenv()

def test_sandbox_email():
    print("🧪 Starting Mailtrap Sandbox test...")
    
    # Credentials from .env
    host = os.getenv("MAILTRAP_SANDBOX_HOST", "sandbox.smtp.mailtrap.io")
    port = int(os.getenv("MAILTRAP_SANDBOX_PORT", 2525))
    user = os.getenv("MAILTRAP_SANDBOX_USER")
    password = os.getenv("MAILTRAP_SANDBOX_PASS")
    
    if not user or not password:
        print("❌ Error: Sandbox credentials not found in .env")
        return

    sender = "no-reply@mail.currenta.tech"
    receiver = "test-user@example.com"
    
    # Create message
    message = MIMEMultipart("alternative")
    message["Subject"] = "Currenta Sandbox Test"
    message["From"] = f"Currenta (Dev) <{sender}>"
    message["To"] = receiver

    text = "This is a test email sent to the Mailtrap Sandbox."
    html = """
    <html>
      <body style="font-family: sans-serif; background-color: #0A0C14; color: white; padding: 20px;">
        <h1 style="color: #6C63FF;">Currenta Sandbox</h1>
        <p>This is a test verification email sent via the <b>Mailtrap Sandbox</b>.</p>
        <div style="background: #171B2F; padding: 20px; border-radius: 10px; text-align: center;">
          <h2 style="margin-bottom: 5px;">Your OTP Code</h2>
          <span style="font-size: 32px; font-weight: bold; letter-spacing: 5px;">654321</span>
        </div>
      </body>
    </html>
    """

    message.attach(MIMEText(text, "plain"))
    message.attach(MIMEText(html, "html"))

    try:
        print(f"📧 Connecting to {host}:{port}...")
        with smtplib.SMTP(host, port) as server:
            server.starttls()
            server.login(user, password)
            server.sendmail(sender, receiver, message.as_string())
        print("✅ Test Successful! The email has been sent to your Mailtrap Sandbox inbox.")
    except Exception as e:
        print(f"❌ Test Failed: {e}")

if __name__ == "__main__":
    test_sandbox_email()
