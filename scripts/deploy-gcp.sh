#!/usr/bin/env bash
set -euo pipefail

# Currenta GCP deploy helper.
# Usage:
#   ./scripts/deploy-gcp.sh
#   PROJECT_ID=my-project REGION=europe-west3 ./scripts/deploy-gcp.sh
#   SKIP_BUILD=true ./scripts/deploy-gcp.sh
#   SKIP_PRECHECKS=true ./scripts/deploy-gcp.sh

PROJECT_ID="${PROJECT_ID:-gen-lang-client-0685906896}"
REGION="${REGION:-europe-west3}"
SERVICE="${SERVICE:-currenta-backend}"
REPO="${REPO:-currenta-repo}"
# Optional: set RUNTIME_SA="" to keep existing Cloud Run runtime service account.
RUNTIME_SA="${RUNTIME_SA-currenta-runtime@${PROJECT_ID}.iam.gserviceaccount.com}"
IMAGE="${IMAGE:-${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO}/backend}"
SKIP_BUILD="${SKIP_BUILD:-false}"
SKIP_PRECHECKS="${SKIP_PRECHECKS:-false}"
PRECHECK_TEST_PATH="${PRECHECK_TEST_PATH:-backend/test_ingestion_pipeline.py}"
VERIFY="${VERIFY:-true}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v gcloud >/dev/null 2>&1; then
  echo "[deploy] gcloud is not installed or not in PATH."
  exit 1
fi

if [[ ! -f "${ROOT_DIR}/cloudbuild.yaml" ]]; then
  echo "[deploy] cloudbuild.yaml not found at repo root: ${ROOT_DIR}"
  exit 1
fi

if [[ "${SKIP_PRECHECKS}" != "true" ]]; then
  if [[ -x "${ROOT_DIR}/venv/bin/python" ]]; then
    PYTHON_BIN="${ROOT_DIR}/venv/bin/python"
  elif command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="$(command -v python3)"
  elif command -v python >/dev/null 2>&1; then
    PYTHON_BIN="$(command -v python)"
  else
    echo "[deploy] Python not found. Cannot run pre-deploy checks."
    exit 1
  fi

  echo "[deploy] Running pre-deploy checks: ${PRECHECK_TEST_PATH}"
  if ! (cd "${ROOT_DIR}" && "${PYTHON_BIN}" -m pytest "${PRECHECK_TEST_PATH}" -q); then
    echo "[deploy] Pre-deploy checks failed. Aborting build/deploy."
    exit 1
  fi
  
  # Optional: Run pip-audit locally if available
  if command -v pip-audit >/dev/null 2>&1; then
    echo "[deploy] Running local security audit..."
    pip-audit -r "${ROOT_DIR}/backend/requirements.txt" || { echo "[deploy] Security audit failed!"; exit 1; }
  fi

  echo "[deploy] Pre-deploy checks passed."
else
  echo "[deploy] SKIP_PRECHECKS=true, skipping pre-deploy checks."
fi

if [[ "${SKIP_BUILD}" != "true" ]]; then
  echo "[deploy] Building image with Kaniko (optimized caching): ${IMAGE}"
  # Note: --no-source is not used here as we need to upload the context
  gcloud builds submit "${ROOT_DIR}" \
    --project="${PROJECT_ID}" \
    --config="${ROOT_DIR}/cloudbuild.yaml" \
    --substitutions="_TAG=${IMAGE}" \
    --quiet
else
  echo "[deploy] SKIP_BUILD=true, using existing image: ${IMAGE}"
fi

echo "[deploy] Deploying Cloud Run service: ${SERVICE}"
DEPLOY_ARGS=(
  "${SERVICE}"
  --image "${IMAGE}"
  --platform managed
  --region "${REGION}"
  --allow-unauthenticated
  --set-env-vars="ENABLE_INTERNAL_SCHEDULER=false,LLM_PROVIDER=vertex,TRUST_PROXY_HEADERS=true,ALLOWED_ORIGINS=https://hidden-paper-0d93.michaelnjonge905.workers.dev,FIREBASE_PROJECT_NUMBER=1061629660004"
  --update-secrets="DATABASE_URL=DATABASE_URL:latest,SUPABASE_URL=SUPABASE_URL:latest,SUPABASE_SERVICE_ROLE_KEY=SUPABASE_SERVICE_ROLE_KEY:latest,ADMIN_API_KEY=ADMIN_API_KEY:latest,REDIS_URL=REDIS_URL:latest,VERTEX_PROJECT=VERTEX_PROJECT:latest,VERTEX_LOCATION=VERTEX_LOCATION:latest,VOYAGE_API_KEY=VOYAGE_API_KEY:latest,VOYAGE_EMBED_MODEL=VOYAGE_EMBED_MODEL:latest"
  --quiet
)

if [[ -n "${RUNTIME_SA}" ]]; then
  DEPLOY_ARGS+=(--service-account "${RUNTIME_SA}")
fi

gcloud run deploy "${DEPLOY_ARGS[@]}" --project="${PROJECT_ID}"

if [[ "${VERIFY}" == "true" ]]; then
  echo "[deploy] Service is live! Verifying health..."
  
  SERVICE_URL="$(gcloud run services describe "${SERVICE}" --region="${REGION}" --project="${PROJECT_ID}" --format='value(status.url)')"
  if [[ -z "${SERVICE_URL}" ]]; then
    echo "[deploy] Could not determine service URL."
    exit 1
  fi

  echo "[deploy] URL: ${SERVICE_URL}"
  # Quick ping before deep check
  if ! curl -fsSL --max-time 10 "${SERVICE_URL}/openapi.json" > /dev/null; then
      echo "[deploy] Waiting for service to wake up..."
      sleep 2
  fi

  echo "[deploy] Verifying endpoints..."
  OPENAPI_JSON="$(curl -fsSL --max-time 15 "${SERVICE_URL}/openapi.json")"
  if ! python3 - "${OPENAPI_JSON}" <<'PY'
import json
import sys

try:
    data = json.loads(sys.argv[1])
except Exception:
    print("[deploy] Failed to parse OpenAPI JSON.")
    sys.exit(1)

paths = data.get("paths", {})
if "/api/admin/session/check" not in paths:
    print("[deploy] Missing required path: /api/admin/session/check")
    sys.exit(1)

print("[deploy] Endpoint check passed: /api/admin/session/check")
PY
  then
    echo "[deploy] Post-deploy endpoint verification failed."
    exit 1
  fi

  echo "[deploy] Fetching recent logs..."
  # Only fetch logs from the last 2 minutes to keep it snappy
  gcloud logging read \
    "resource.type=cloud_run_revision AND resource.labels.service_name=${SERVICE} timestamp>=\"$(date -u -d '2 minutes ago' +%Y-%m-%dT%H:%M:%SZ)\"" \
    --project="${PROJECT_ID}" \
    --limit=10 \
    --format="value(timestamp, severity, textPayload)"
fi

echo "[deploy] Done. Total time: $SECONDS seconds."

