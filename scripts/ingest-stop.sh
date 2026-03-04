#!/usr/bin/env bash
# scripts/ingest-stop.sh
# Signals the background orchestrator to stop processing feeds.

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
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

echo -e "${CYAN}🛑 Sending stop signal to news ingestion orchestrator...${RESET}"

RESPONSE=$(curl -s -X POST "${BACKEND_URL}/api/ingest/cancel" \
     -H "X-API-Key: ${ADMIN_KEY}" \
     -H "Content-Type: application/json")

if [[ $? -eq 0 ]]; then
    echo -e "${YELLOW}⚠️  Stop signal sent!${RESET}"
    echo -e "Response: ${BOLD}${RESPONSE}${RESET}"
    echo ""
    echo -e "The orchestrator will stop after finishing the current article/feed."
    echo -e "Monitor: ${BOLD}tail -f .backend.log${RESET}"
else
    echo -e "${RED}❌ Failed to reach the backend at ${BACKEND_URL}${RESET}"
    exit 1
fi
