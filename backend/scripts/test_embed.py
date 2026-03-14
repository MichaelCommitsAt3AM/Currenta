import asyncio
import os
import httpx
from dotenv import load_dotenv

load_dotenv()

LOCAL_LLM_BASE_URL = os.environ.get("LOCAL_LLM_BASE_URL", "http://localhost:11434/v1")
LOCAL_EMBED_MODEL = os.environ.get("LOCAL_EMBED_MODEL", "nomic-embed-text")

async def test_embed():
    print(f"Testing embedding with {LOCAL_LLM_BASE_URL} and {LOCAL_EMBED_MODEL}...")
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            res = await client.post(
                f"{LOCAL_LLM_BASE_URL}/embeddings",
                headers={"Content-Type": "application/json"},
                json={"model": LOCAL_EMBED_MODEL, "input": "Hello world"}
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
