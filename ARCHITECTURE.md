# Currenta System Architecture

This document describes the high-level architecture of Currenta, the data flow, and the technical decisions behind the core engine.

---

## 🏗️ High-Level System Overview

Currenta follows a modern, decoupled architecture centered around a high-performance news pipeline and a vector-aware mobile application.

```mermaid
graph TD
    subgraph "External Sources"
        RSS["RSS Feeds"]
        SCR["Web Scrapers"]
    end

    subgraph "Backend Engine (Python/FastAPI)"
        ING["Ingestion Worker"]
        API["FastAPI App"]
        LLM["AI Summarizer (Gemini/Ollama)"]
        VEC["Vector Engine (Voyage/Voyage-Lite)"]
    end

    subgraph "Data & Cache Layer"
        PG["PostgreSQL (pgvector)"]
        RD["Redis (Rate Limiting/Cache)"]
        S3["Supabase Storage (Images)"]
    end

    subgraph "Client App (Flutter)"
        MOB["Mobile App"]
        LDB["Local Drift DB (Cache-First)"]
    end

    RSS --> ING
    SCR --> ING
    ING --> LLM
    ING --> VEC
    LLM --> ING
    VEC --> ING
    ING --> PG
    PG <--> API
    RD <--> API
    API <--> MOB
    MOB <--> LDB
```

---

## 🌪️ The Ingestion Pipeline

The ingestion engine is a multi-stage pipeline designed for **high precision** and **low noise**.

1.  **Discovery**: Tracks 180+ RSS feeds and custom scrapers (e.g., TechCrunch).
2.  **Junk Filtering**: A regex-based "Deterministic Gate" blocks betting, sports previews, and live-blogs before they hit the LLM.
3.  **AI Processing**:
    *   **Summarization**: Generates a strict 65-word summary (5Ws) and extracts metadata.
    *   **Classification**: Assigns multiple categories and identifies content "type" (Analysis, Hard News, etc.).
    *   **Locality Detection**: Determines if an article is locally relevant to specific regions (e.g., Kenya).
4.  **Embedding**: Generates a 1024-dimensional vector representation of the content.
5.  **Deduplication**: Uses Jaccard similarity to collapse near-duplicate headlines across sources.
6.  **Ranking**: Calculates an initial `ranking_score` using time-decay and trend signals.

---

## 🎯 Recommendation & Personalization

Currenta uses a "Bucketized Interleave" strategy to maintain feed quality and variety.

### 1. Vector Similarity (`pgvector`)
User interactions (likes, views) are used to compute an "Interest Vector." When fetching the feed, the system performs a cosine similarity search against the `articles` table to find stories semantically similar to the user's past interests.

### 2. Portfolio Interleave
To prevent filter bubbles, the `Diversifier` engine interleaves articles from four distinct buckets:
-   **Personalized (70%)**: Vector-matched stories.
-   **Trending (20%)**: High-momentum stories across all categories.
-   **Discovery (10%)**: Random high-quality stories from outside the user's primary interests.
-   **Global Trending (Fallback)**: Top-tier global news used during cold starts.

---

## ⚡ Cache-First Strategy

The Flutter application implements a strict cache-first architecture:
-   **Immediate Load**: The UI pulls from a local **Drift (SQLite)** database for sub-100ms startup.
-   **Background Sync**: A reactive repository fetches fresh data from the API and upserts it into local storage.
-   **Reactive Streams**: Any change to the local database (via background sync or user interaction) automatically triggers a UI refresh via Dart Streams.

---

## 🛡️ Security & Scalability

-   **Supabase Auth**: Secure JWT-based authentication for both guest and registered users.
-   **Redis Rate Limiting**: Protects the feed and search endpoints from abuse.
-   **ngrok Tunneling**: Facilitates secure, local-to-remote development without manual IP configuration.
-   **Dockerized Services**: The entire backend (API, Worker, Redis, Caddy) is containerized for consistent deployment.
