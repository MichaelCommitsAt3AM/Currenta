#!/usr/bin/env bash
# scripts/dev-start.sh
# ─────────────────────────────────────────────────────────────────────────────
# One-shot dev environment launcher for Currenta.
#
#   1. Ensures Ollama is running (starts / restarts the service if needed)
#   2. Starts ngrok with the project config (scripts/ngrok.yml)
#   3. Waits for ngrok to be ready and extracts the public HTTPS URL
#   4. Optionally updates the Supabase edge-function secret automatically
#   5. Prints a summary with everything you need to start coding
#
# Usage:
#   bash scripts/dev-start.sh               # interactive
#   AUTO_UPDATE_SECRET=1 bash scripts/dev-start.sh  # auto-push secret, no prompts
#
# Prerequisites (run once beforehand):
#   sudo bash scripts/setup-ollama.sh       # sets OLLAMA_ORIGINS=* in systemd
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Colour helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

ok()   { echo -e "${GREEN}✅  $*${RESET}"; }
info() { echo -e "${CYAN}ℹ️   $*${RESET}"; }
warn() { echo -e "${YELLOW}⚠️   $*${RESET}"; }
die()  { echo -e "${RED}❌  $*${RESET}"; exit 1; }
hr()   { echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; }

# ── Config ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
NGROK_CONFIG="${SCRIPT_DIR}/ngrok.yml"
OLLAMA_MODEL="${OLLAMA_MODEL:-llama3.1}"
OLLAMA_EMBED_MODEL="${OLLAMA_EMBED_MODEL:-nomic-embed-text}"  # 768-dim, for pgvector
OLLAMA_PORT="${OLLAMA_PORT:-11434}"
NGROK_API_PORT="${NGROK_API_PORT:-4040}"      # ngrok local API for URL extraction
AUTO_UPDATE_SECRET="${AUTO_UPDATE_SECRET:-0}" # set to 1 to skip the prompt

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
hr
echo -e "${BOLD}  🚀  Currenta Dev Environment${RESET}"
hr
echo ""

# ── 1. Dependency checks ──────────────────────────────────────────────────────
info "Checking dependencies..."

command -v ollama >/dev/null 2>&1 || die "ollama not found. Install from https://ollama.com/"
command -v ngrok  >/dev/null 2>&1 || die "ngrok not found. Install from https://ngrok.com/download"
command -v curl   >/dev/null 2>&1 || die "curl not found. Please install curl."
command -v jq     >/dev/null 2>&1 || warn "jq not found — ngrok URL extraction may fall back to grep. (sudo apt install jq)"

[[ -f "${NGROK_CONFIG}" ]] || die "ngrok config not found at ${NGROK_CONFIG}"

[[ -f "${NGROK_CONFIG}" ]] || die "ngrok config not found at ${NGROK_CONFIG}"

# Ensure python backend requirements are installed
if [[ -d "${PROJECT_ROOT}/backend" ]]; then
  info "Checking Backend dependencies..."
  if [[ ! -d "${PROJECT_ROOT}/venv" ]]; then
    warn "Virtual env not found for backend. Please run 'python3 -m venv venv && source venv/bin/activate && pip install -r backend/requirements.txt'"
  fi
fi

ok "All dependencies found"
echo ""

# ── 2. Ollama ─────────────────────────────────────────────────────────────────
hr
echo -e "${BOLD}  Step 1 · Ollama${RESET}"
hr

OLLAMA_READY=false

# Check if Ollama is already responding
if curl -sf "http://localhost:${OLLAMA_PORT}/api/tags" >/dev/null 2>&1; then
  ok "Ollama is already running on port ${OLLAMA_PORT}"
  OLLAMA_READY=true
else
  # Try to start via systemd (preferred — ensures OLLAMA_ORIGINS=* is set)
  if systemctl is-active --quiet ollama 2>/dev/null; then
    info "Restarting Ollama service..."
    sudo systemctl restart ollama
  elif systemctl list-unit-files ollama.service >/dev/null 2>&1; then
    info "Starting Ollama service..."
    sudo systemctl start ollama
  else
    # Fallback: start ollama serve in the background
    warn "Ollama systemd service not found — starting 'ollama serve' in background."
    warn "OLLAMA_ORIGINS may not be set. Run 'sudo bash scripts/setup-ollama.sh' if you see CORS errors."
    OLLAMA_ORIGINS="*" OLLAMA_KEEP_ALIVE="-1" nohup ollama serve \
      >"${PROJECT_ROOT}/.ollama.log" 2>&1 &
    echo $! >"${PROJECT_ROOT}/.ollama.pid"
    info "Ollama PID $(cat "${PROJECT_ROOT}/.ollama.pid") — logs: .ollama.log"
  fi

  # Wait up to 20 s for Ollama to respond
  info "Waiting for Ollama to be ready..."
  for i in $(seq 1 20); do
    if curl -sf "http://localhost:${OLLAMA_PORT}/api/tags" >/dev/null 2>&1; then
      OLLAMA_READY=true
      break
    fi
    sleep 1
  done
fi

if [[ "${OLLAMA_READY}" != "true" ]]; then
  die "Ollama did not become ready within 20 seconds. Check 'journalctl -u ollama -n 50' or .ollama.log"
fi

# Verify LLM model is available
info "Checking for LLM model '${OLLAMA_MODEL}'..."
if ollama list 2>/dev/null | grep -q "^${OLLAMA_MODEL}"; then
  ok "LLM model '${OLLAMA_MODEL}' is available"
else
  warn "LLM model '${OLLAMA_MODEL}' not found locally."
  read -rp "  Pull it now? [Y/n] " pull_llm_answer
  if [[ "${pull_llm_answer:-Y}" =~ ^[Yy]$ ]]; then
    info "Pulling '${OLLAMA_MODEL}'..."
    ollama pull "${OLLAMA_MODEL}"
    ok "LLM model ready"
  else
    warn "Skipping — summarization will fail at runtime."
  fi
fi

# Verify embedding model is available
info "Checking for embedding model '${OLLAMA_EMBED_MODEL}'..."
if ollama list 2>/dev/null | grep -q "^${OLLAMA_EMBED_MODEL}"; then
  ok "Embedding model '${OLLAMA_EMBED_MODEL}' is available"
else
  warn "Embedding model '${OLLAMA_EMBED_MODEL}' not found."
  read -rp "  Pull it now? [Y/n] " pull_embed_answer
  if [[ "${pull_embed_answer:-Y}" =~ ^[Yy]$ ]]; then
    info "Pulling '${OLLAMA_EMBED_MODEL}' (~274 MB)..."
    ollama pull "${OLLAMA_EMBED_MODEL}"
    ok "Embedding model ready"
  else
    warn "Skipping — deduplication embeddings will fail at runtime."
  fi
fi
echo ""

# ── 1.5 Currenta Backend ──────────────────────────────────────────────────────
hr
echo -e "${BOLD}  Step 1.5 · FastAPI Backend Service${RESET}"
hr

BACKEND_PORT=8000
BACKEND_READY=false

# Check if Backend is already running
if curl -sf "http://localhost:${BACKEND_PORT}/health" > /dev/null 2>&1; then
  ok "Backend Service is already running on port ${BACKEND_PORT}"
  BACKEND_READY=true
else
  info "Starting FastAPI Backend in background..."
  # Use the root venv and run from project root to ensure module resolution
  source "${PROJECT_ROOT}/venv/bin/activate"
  PYTHONPATH="${PROJECT_ROOT}" nohup uvicorn backend.main:app --port ${BACKEND_PORT} --host 0.0.0.0 \
    >"${PROJECT_ROOT}/.backend.log" 2>&1 &
  echo $! >"${PROJECT_ROOT}/.backend.pid"
  info "Backend PID $(cat "${PROJECT_ROOT}/.backend.pid") — logs: .backend.log"

  info "Waiting for Backend Service to be ready..."
  HEALTH_JSON=""
  for i in $(seq 1 20); do
    # Use /health so we know DB + scheduler are actually up, not just uvicorn
    HTTP_CODE=$(curl -s -o /tmp/.currenta_health.json -w "%{http_code}" \
      "http://localhost:${BACKEND_PORT}/health" 2>/dev/null || echo "000")
    if [[ "${HTTP_CODE}" == "200" ]]; then
      HEALTH_JSON=$(cat /tmp/.currenta_health.json 2>/dev/null || echo "")
      BACKEND_READY=true
      break
    elif [[ "${HTTP_CODE}" == "503" ]]; then
      # uvicorn is up but a dependency failed — capture and continue waiting
      HEALTH_JSON=$(cat /tmp/.currenta_health.json 2>/dev/null || echo "")
    fi
    sleep 1
  done
fi

if [[ "${BACKEND_READY}" != "true" ]]; then
  warn "Backend Service did not become fully healthy. Check .backend.log."
  [[ -n "${HEALTH_JSON:-}" ]] && echo -e "    Health report: ${HEALTH_JSON}"
else
  ok "Backend Service ready on port ${BACKEND_PORT}"
fi
echo ""

# ── 3. ngrok ─────────────────────────────────────────────────────────────────
hr
echo -e "${BOLD}  Step 2 · ngrok${RESET}"
hr

# Kill any existing ngrok process (stale tunnel → old URL)
if pgrep -x ngrok >/dev/null 2>&1; then
  warn "Found a running ngrok process — killing it to get a fresh URL..."
  pkill -x ngrok || true
  sleep 1
fi

# Start ngrok in the background for the backend
info "Starting ngrok tunnel for backend (port ${BACKEND_PORT})..."
nohup ngrok start --config "/home/linux/.config/ngrok/ngrok.yml" --config "${NGROK_CONFIG}" backend \
  >"${PROJECT_ROOT}/.ngrok.log" 2>&1 &
NGROK_PID=$!
echo "${NGROK_PID}" >"${PROJECT_ROOT}/.ngrok.pid"
info "ngrok PID ${NGROK_PID} — logs: .ngrok.log"

# Wait for ngrok local API to become available
info "Waiting for ngrok to establish tunnel..."
BACKEND_NGROK_URL=""
for i in $(seq 1 20); do
  if command -v jq >/dev/null 2>&1; then
    BACKEND_NGROK_URL=$(curl -sf "http://localhost:${NGROK_API_PORT}/api/tunnels" 2>/dev/null \
      | jq -r '.tunnels[]? | select(.name=="backend") | .public_url' 2>/dev/null | head -1 || echo "")
  else
    BACKEND_NGROK_URL=$(curl -sf "http://localhost:${NGROK_API_PORT}/api/tunnels" 2>/dev/null \
      | grep -oP '"name":"backend","[^"]+","public_url":"https://[^"]+' 2>/dev/null | head -1 | cut -d'"' -f5 || echo "")
  fi
  [[ -n "${BACKEND_NGROK_URL}" ]] && break
  sleep 1
done

if [[ -z "${BACKEND_NGROK_URL}" ]]; then
  die "Could not extract ngrok URL after 20 seconds. Check .ngrok.log for errors."
fi

ok "ngrok tunnel active:"
echo -e "    Backend: ${BOLD}${BACKEND_NGROK_URL}${RESET}"
echo ""

# ── 4. Update Flutter Config ──────────────────────────────────────────────────
hr
echo -e "${BOLD}  Step 3 · App Configuration${RESET}"
hr

info "Updating Flutter app config with new ngrok URL..."
CONFIG_FILE="${PROJECT_ROOT}/lib/core/config/app_config.dart"
if [[ -f "${CONFIG_FILE}" ]]; then
  # More robust regex that handles potential multiline or trailing whitespace from formatters (.app or .dev)
  sed -i "s|static const String apiBaseUrl =.*'https://.*.ngrok-free\..*';|static const String apiBaseUrl = '${BACKEND_NGROK_URL}';|g" "${CONFIG_FILE}"
  # Check if the file actually contains the new URL to confirm update
  if grep -q "${BACKEND_NGROK_URL}" "${CONFIG_FILE}"; then
    ok "Updated apiBaseUrl in app_config.dart ✓"
  else
    warn "Failed to update apiBaseUrl in app_config.dart (check if the pattern in the script matches your file structure)"
  fi

else
  warn "app_config.dart not found at ${CONFIG_FILE}. Please update manualy."
fi
echo ""

# ── 5. Summary ────────────────────────────────────────────────────────────────
hr
echo -e "${BOLD}  🎉  Currenta Dev setup is live!${RESET}"
hr
echo ""
echo -e "  ${BOLD}Ollama (Local)${RESET}   http://localhost:${OLLAMA_PORT}"
echo -e "  ${BOLD}Backend (Local)${RESET}  http://localhost:${BACKEND_PORT}"
echo -e "  ${BOLD}Backend (Public)${RESET} ${BOLD}${BACKEND_NGROK_URL}${RESET}"
echo -e "  ${BOLD}ngrok Dashboard${RESET}  http://localhost:${NGROK_API_PORT}"
echo ""
echo -e "  ${BOLD}App Details:${RESET}"
echo -e "    📁  Config:    lib/core/config/app_config.dart"
echo -e "    🌐  Base URL:  ${BACKEND_NGROK_URL}"
echo -e "    💊  Health:    http://localhost:${BACKEND_PORT}/health"
echo ""
echo -e "  To stop all services:  ${BOLD}bash scripts/dev-stop.sh${RESET}"
echo ""
hr
echo ""
