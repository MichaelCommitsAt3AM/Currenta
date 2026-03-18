import asyncio
import os
import httpx
from dotenv import load_dotenv

load_dotenv()

OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "")
OPENAI_EMBED_MODEL = os.environ.get("OPENAI_EMBED_MODEL", "text-embedding-3-small")

async def test_embed():
    print(f"Testing OpenAI embedding model: {OPENAI_EMBED_MODEL}...")
    if not OPENAI_API_KEY:
        raise ValueError("OPENAI_API_KEY is required for this test.")
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            res = await client.post(
                "https://api.openai.com/v1/embeddings",
                headers={
                    "Authorization": f"Bearer {OPENAI_API_KEY}",
                    "Content-Type": "application/json",
                },
                json={"model": OPENAI_EMBED_MODEL, "input": "Hello world"}
            )
            print(f"Status: {res.status_code}")
            if res.status_code == 200:
                data = res.json()
                embedding = data["data"][0]["embedding"]
                print(f"Success! Embedding length: {len(embedding)}")
            else:
                print(f"Error: {res.text}")
    except Exception as e:
        print(f"Exception: {e}")

if __name__ == "__main__":
    asyncio.run(test_embed())
