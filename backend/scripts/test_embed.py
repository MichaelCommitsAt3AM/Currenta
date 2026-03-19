import asyncio
import os
import httpx
from dotenv import load_dotenv

load_dotenv()

EMBEDDING_PROVIDER = os.environ.get("EMBEDDING_PROVIDER", "voyage").strip().lower()
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "")
OPENAI_EMBED_MODEL = os.environ.get("OPENAI_EMBED_MODEL", "text-embedding-3-small")
VOYAGE_API_KEY = os.environ.get("VOYAGE_API_KEY", "")
VOYAGE_EMBED_MODEL = os.environ.get("VOYAGE_EMBED_MODEL", "voyage-3.5-lite")

async def test_embed():
    print(f"Testing embedding provider: {EMBEDDING_PROVIDER}")
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            if EMBEDDING_PROVIDER == "voyage":
                if not VOYAGE_API_KEY:
                    raise ValueError("VOYAGE_API_KEY is required when EMBEDDING_PROVIDER=voyage.")
                print(f"Testing Voyage embedding model: {VOYAGE_EMBED_MODEL}...")
                res = await client.post(
                    "https://api.voyageai.com/v1/embeddings",
                    headers={
                        "Authorization": f"Bearer {VOYAGE_API_KEY}",
                        "Content-Type": "application/json",
                    },
                    json={"model": VOYAGE_EMBED_MODEL, "input": ["Hello world"], "input_type": "document"}
                )
            elif EMBEDDING_PROVIDER == "local":
                LOCAL_LLM_BASE_URL = os.environ.get("LOCAL_LLM_BASE_URL", "http://localhost:11434/v1")
                OLLAMA_EMBED_MODEL = os.environ.get("OLLAMA_EMBED_MODEL", "nomic-embed-text")
                print(f"Testing local embedding model: {OLLAMA_EMBED_MODEL} via {LOCAL_LLM_BASE_URL}...")
                res = await client.post(
                    f"{LOCAL_LLM_BASE_URL}/embeddings",
                    headers={"Content-Type": "application/json"},
                    json={"model": OLLAMA_EMBED_MODEL, "input": "Hello world"}
                )
            else:
                raise ValueError(f"Unsupported EMBEDDING_PROVIDER: {EMBEDDING_PROVIDER}")
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
