# Currenta: GCP Backend Migration Guide

This guide outlines how to migrate your backend to Google Cloud Platform (GCP) following the recommendations for a robust production setup.

## 1. Region Alignment
Your Supabase instance is in **AWS Frankfurt (`eu-central-1`)**.
**Recommendation:** Deploy all GCP resources in **`europe-west3` (Frankfurt)** to ensure sub-10ms latency between the backend and database.

## 2. Serverless Hosting (Cloud Run)
Use **Google Cloud Run** for the FastAPI backend. It scales to zero when not in use, saving costs.

### Prerequisites
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) installed and configured.
- A GCP Project created.

### Build and Deploy Command
Run this from the project root:
```bash
# Set variables
PROJECT_ID="gen-lang-client-0685906896"
REGION="europe-west3"
SERVICE="currenta-backend"
RUNTIME_SA="currenta-runtime@$PROJECT_ID.iam.gserviceaccount.com"

# Submit build to Artifact Registry (using cloudbuild.yaml to locate backend/Dockerfile)
gcloud builds submit . \
  --config=cloudbuild.yaml \
  --substitutions=_TAG=$REGION-docker.pkg.dev/$PROJECT_ID/currenta-repo/backend

# Deploy to Cloud Run (private service, no public ingress)
gcloud run deploy $SERVICE \
  --image $REGION-docker.pkg.dev/$PROJECT_ID/currenta-repo/backend \
  --platform managed \
  --region $REGION \
  --service-account $RUNTIME_SA \
  --no-allow-unauthenticated \
  --set-env-vars="ENABLE_INTERNAL_SCHEDULER=false,LLM_PROVIDER=vertex,TRUST_PROXY_HEADERS=true"

# Optional extra hardening: restrict ingress to internal + load balancer only
gcloud run services update $SERVICE \
  --region $REGION \
  --ingress internal-and-cloud-load-balancing
```

## 3. Managed Background Tasks (Cloud Scheduler)
Since Cloud Run scales to zero, the internal `APScheduler` is disabled in production (`ENABLE_INTERNAL_SCHEDULER=false`). 

**Setup Cloud Scheduler jobs to hit your API endpoints with OIDC auth:**

1. Create a dedicated scheduler service account:
```bash
SCHEDULER_SA="currenta-scheduler@$PROJECT_ID.iam.gserviceaccount.com"
gcloud iam service-accounts create currenta-scheduler --project $PROJECT_ID
```

2. Allow it to invoke the private Cloud Run service:
```bash
gcloud run services add-iam-policy-binding $SERVICE \
  --region $REGION \
  --member="serviceAccount:$SCHEDULER_SA" \
  --role="roles/run.invoker"
```

3. Create Scheduler jobs (OIDC token + admin key header):
```bash
SERVICE_URL="https://$SERVICE-<hash>-$REGION.a.run.app"

gcloud scheduler jobs create http currenta-orchestrate \
  --location=$REGION \
  --schedule="0 */3 * * *" \
  --uri="$SERVICE_URL/api/ingest/orchestrate" \
  --http-method=POST \
  --oidc-service-account-email="$SCHEDULER_SA" \
  --oidc-token-audience="$SERVICE_URL" \
  --headers="X-API-Key=<ADMIN_API_KEY>"

gcloud scheduler jobs create http currenta-trending \
  --location=$REGION \
  --schedule="*/15 * * * *" \
  --uri="$SERVICE_URL/api/trending/trigger" \
  --http-method=POST \
  --oidc-service-account-email="$SCHEDULER_SA" \
  --oidc-token-audience="$SERVICE_URL" \
  --headers="X-API-Key=<ADMIN_API_KEY>"
```

4. Keep the admin API key in Secret Manager and rotate it periodically.

| Task | Endpoint | Schedule (Cron) |
| :--- | :--- | :--- |
| News Orchestration | `/api/ingest/orchestrate` | `0 */3 * * *` (Every 3 hours) |
| Trending Update | `/api/trending/trigger` | `*/15 * * * *` (Every 15 mins) |

**Note:** Use both controls in production:
- OIDC identity token from Scheduler service account
- `X-API-Key` header for admin endpoints

## 4. Secure Secrets (Secret Manager)
Instead of a `.env` file in production, use **Google Secret Manager**.

Create and map all runtime secrets/env vars used by backend modules:
```bash
gcloud run deploy $SERVICE \
  --region $REGION \
  --update-secrets=DATABASE_URL=DATABASE_URL:latest,SUPABASE_URL=SUPABASE_URL:latest,SUPABASE_SERVICE_ROLE_KEY=SUPABASE_SERVICE_ROLE_KEY:latest,ADMIN_API_KEY=ADMIN_API_KEY:latest,REDIS_URL=REDIS_URL:latest,VERTEX_PROJECT=VERTEX_PROJECT:latest,VERTEX_LOCATION=VERTEX_LOCATION:latest \
  --set-env-vars="ENABLE_INTERNAL_SCHEDULER=false,LLM_PROVIDER=vertex,TRUST_PROXY_HEADERS=true"
```

If you keep OpenAI embeddings in production, also map:
- `OPENAI_API_KEY`
- `OPENAI_EMBED_MODEL`

## 5. IAM Authentication (Vertex AI)
No API Key is required for Vertex AI when running on GCP.
- Ensure the **Cloud Run Service Account** has the role `Vertex AI User` (`roles/aiplatform.user`).
- Your backend will automatically use its internal identity to call Gemini.

## 6. Deployment Quality Gates
`cloudbuild.yaml` now enforces quality gates before image build:
- Python bytecode compilation check (`compileall`)
- Backend tests (`pytest`)
- Dependency vulnerability scan (`pip-audit`)

Builds fail early if these checks fail.

---

## Local Development vs. Production Summary

| Feature | Local Development | GCP Production |
| :--- | :--- | :--- |
| **Scheduler** | Internal (`APScheduler`) | External (`Cloud Scheduler`) |
| **Secrets** | `.env` file | Google Secret Manager |
| **AI SDK** | Google AI Studio (API Key) | Vertex AI (IAM / Service Account) |
| **Redis** | Docker / Localhost | Memorystore / Upstash |
| **SSL** | N/A (or tunnel) | Managed by Cloud Run |
