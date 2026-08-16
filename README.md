# Currenta

**Currenta** is an AI-first news platform designed to deliver high-signal, localized, and personalized news without the noise of clickbait or redundant headlines. 

By combining **Flutter**'s cross-platform reach with a powerful **FastAPI** backend and **pgvector**-driven recommendations, Currenta ensures you see the stories that matter most to you, summarized for quick reading.

---

## Key Features

*   **AI-Powered Summarization**: Every article is processed via Gemini or local LLMs (Ollama) to generate factual, 65-word "5Ws" summaries.
*   **Vector Personalization**: Uses `pgvector` to build an interest profile based on your interactions (likes, views), matching articles semantically rather than just by keywords.
*   **Intelligent Localization**: Automatic Geo-IP detection serves local news for your region on-demand, with dedicated "Local News" ingestion logic.
*   **Noise & Junk Filtering**: Multi-stage pipeline filters out betting odds, sports previews, live-blogs, and "fluff" to maintain a high-quality feed.
*   **Smart Deduplication**: Near-duplicate headlines from multiple sources are collapsed using Jaccard similarity scoring.
*   **Hybrid Architecture**: A "Portfolio Interleave" strategy mixes personalized, trending, and discovery content to break filter bubbles.
*   **Cache-First Strategy**: Real-time reactive streams from a local SQLite (Drift) database for instant UI response, synced with a remote Supabase backend.

---

## Tech Stack

### Frontend
- **Flutter**: Cross-platform mobile application.
- **Drift**: High-performance local SQL storage.
- **Riverpod/Notifiers**: Robust state management.

### Backend
- **FastAPI**: High-performance Python 3.11+ web framework.
- **Supabase**: PostgreSQL database with **pgvector** and Auth.
- **Redis**: Low-latency caching for rate limiting and session management.
- **Worker**: Dedicated ingestion pipeline for RSS and scraping.

### AI / ML
- **Ollama**: Local LLM hosting for embeddings and privacy-centric summarization.
- **Voyage AI**: Professional-grade text embeddings.
- **Google Gemini/Vertex AI**: High-quality news analysis and summarization.

---

## Getting Started

### Prerequisites
- **Docker & Docker Compose**
- **Ollama** (for running local AI models)
- **ngrok** 
- **Flutter SDK**

### Quick Launch
The project includes a robust set of scripts to handle the complex dev environment:

1.  **Initialize Environment**:
    ```bash
    cp .env.template .env
    # Fill in your Supabase and API keys
    ```

2.  **Start Services**:
    This script handles Docker, ngrok, and Ollama setup in one shot:
    ```bash
    bash scripts/dev-start.sh
    ```

3.  **Run the App**:
    ```bash
    flutter run --dart-define-from-file=config/dev.json
    ```

---

## Project Structure

```text
├── admin/            # Lightweight JS portal for DB exploration
├── backend/          # FastAPI server, ingestion worker, and AI services
├── lib/              # Flutter application (Feature-first architecture)
│   ├── core/         # Global themes, configs, and network clients
│   └── features/     # Encapsulated modules (Auth, News, Profile)
├── scripts/          # Dev-ops and environment management scripts
├── supabase/         # Migrations, schema, and edge functions
└── test/             # Flutter unit and widget tests
```

---

## Documentation
- **Architecture**: See [ARCHITECTURE.md](ARCHITECTURE.md) for a deep dive into the data pipeline.


## License
This project is proprietary and for internal development use only.
