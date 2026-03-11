#!/usr/bin/env bash
# scripts/ingest-now.sh
# Manually triggers the full news ingestion orchestrator on the local FastAPI backend.

# Config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

if [[ ! -f "${ENV_FILE}" ]]; then
    echo "❌ Error: .env file not found at ${ENV_FILE}"
    exit 1
fi

# Source .env but ignore comments/blank lines
export $(grep -v '^#' "${ENV_FILE}" | xargs)

if [[ -z "${ADMIN_API_KEY:-}" ]]; then
    echo "❌ Error: ADMIN_API_KEY is not defined in ${ENV_FILE}"
    exit 1
fi

BACKEND_URL="http://localhost:8000"
ADMIN_KEY="${ADMIN_API_KEY}"

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

echo -e "${CYAN}🚀 Triggering full news ingestion orchestrator...${RESET}"

RESPONSE=$(curl -s -X POST "${BACKEND_URL}/api/ingest/orchestrate" \
     -H "X-API-Key: ${ADMIN_KEY}" \
     -H "Content-Type: application/json")

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✅ Request successful!${RESET}"
    echo -e "Response: ${BOLD}${RESPONSE}${RESET}"
    echo ""
    echo -e "Ingestion is now running in the background on the server."
    echo -e "You can monitor progress with: ${BOLD}docker compose logs -f api${RESET}"
else
    echo -e "❌ Failed to reach the backend at ${BACKEND_URL}"
    exit 1
fi
