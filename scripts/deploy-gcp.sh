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
RUNTIME_SA="${RUNTIME_SA:-currenta-runtime@${PROJECT_ID}.iam.gserviceaccount.com}"
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
  echo "[deploy] Pre-deploy checks passed."
else
  echo "[deploy] SKIP_PRECHECKS=true, skipping pre-deploy checks."
fi

if [[ "${SKIP_BUILD}" != "true" ]]; then
  echo "[deploy] Building image with Cloud Build: ${IMAGE}"
  gcloud builds submit "${ROOT_DIR}" \
    --config="${ROOT_DIR}/cloudbuild.yaml" \
    --substitutions="_TAG=${IMAGE}"
else
  echo "[deploy] SKIP_BUILD=true, using existing image: ${IMAGE}"
fi

echo "[deploy] Deploying Cloud Run service: ${SERVICE}"
gcloud run deploy "${SERVICE}" \
  --image "${IMAGE}" \
  --platform managed \
  --region "${REGION}" \
  --service-account "${RUNTIME_SA}" \
  --no-allow-unauthenticated \
  --set-env-vars="ENABLE_INTERNAL_SCHEDULER=false,LLM_PROVIDER=vertex,TRUST_PROXY_HEADERS=true" \
  --update-secrets="DATABASE_URL=DATABASE_URL:latest,SUPABASE_URL=SUPABASE_URL:latest,SUPABASE_SERVICE_ROLE_KEY=SUPABASE_SERVICE_ROLE_KEY:latest,ADMIN_API_KEY=ADMIN_API_KEY:latest,REDIS_URL=REDIS_URL:latest,VERTEX_PROJECT=VERTEX_PROJECT:latest,VERTEX_LOCATION=VERTEX_LOCATION:latest"

if [[ "${VERIFY}" == "true" ]]; then
  echo "[deploy] Service summary"
  gcloud run services describe "${SERVICE}" \
    --region "${REGION}" \
    --format="table(metadata.name,status.url,status.latestReadyRevisionName)"

  echo "[deploy] Recent Cloud Run logs"
  gcloud logging read \
    "resource.type=cloud_run_revision AND resource.labels.service_name=${SERVICE}" \
    --limit=20 \
    --format="value(timestamp, severity, textPayload)"
fi

echo "[deploy] Done."
