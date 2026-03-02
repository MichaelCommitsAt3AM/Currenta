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

# Verify model is available
info "Checking for model '${OLLAMA_MODEL}'..."
if ollama list 2>/dev/null | grep -q "^${OLLAMA_MODEL}"; then
  ok "Model '${OLLAMA_MODEL}' is available"
else
  warn "Model '${OLLAMA_MODEL}' not found locally."
  read -rp "  Pull it now? [Y/n] " pull_answer
  if [[ "${pull_answer:-Y}" =~ ^[Yy]$ ]]; then
    echo ""
    info "Pulling '${OLLAMA_MODEL}' (this may take several minutes)..."
    ollama pull "${OLLAMA_MODEL}"
    ok "Model '${OLLAMA_MODEL}' ready"
  else
    warn "Skipping model pull — summarisation will fail at runtime."
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

# Start ngrok in the background
info "Starting ngrok with config: ${NGROK_CONFIG}"
nohup ngrok start --config "/home/linux/.config/ngrok/ngrok.yml" --config "${NGROK_CONFIG}" ollama \
  >"${PROJECT_ROOT}/.ngrok.log" 2>&1 &
NGROK_PID=$!
echo "${NGROK_PID}" >"${PROJECT_ROOT}/.ngrok.pid"
info "ngrok PID ${NGROK_PID} — logs: .ngrok.log"

# Wait for ngrok local API to become available
info "Waiting for ngrok to establish tunnel..."
NGROK_URL=""
for i in $(seq 1 20); do
  if command -v jq >/dev/null 2>&1; then
    NGROK_URL=$(curl -sf "http://localhost:${NGROK_API_PORT}/api/tunnels" 2>/dev/null \
      | jq -r '.tunnels[]? | select(.proto=="https") | .public_url' 2>/dev/null | head -1 || echo "")
  else
    # Fallback without jq
    NGROK_URL=$(curl -sf "http://localhost:${NGROK_API_PORT}/api/tunnels" 2>/dev/null \
      | grep -oP '"public_url":"https://[^"]+' 2>/dev/null | head -1 | cut -d'"' -f4 || echo "")
  fi
  [[ -n "${NGROK_URL}" ]] && break
  sleep 1
done

if [[ -z "${NGROK_URL}" ]]; then
  die "Could not extract ngrok URL after 20 seconds. Check .ngrok.log for errors.\n    Make sure your ngrok auth token is set: ngrok config add-authtoken <TOKEN>"
fi

ok "ngrok tunnel active: ${NGROK_URL}"
echo ""

# ── 4. Update Supabase secret ─────────────────────────────────────────────────
hr
echo -e "${BOLD}  Step 3 · Supabase Secret${RESET}"
hr

UPDATE_SECRET=false
if [[ "${AUTO_UPDATE_SECRET}" == "1" ]]; then
  UPDATE_SECRET=true
else
  echo -e "  New ngrok URL: ${BOLD}${NGROK_URL}${RESET}"
  echo ""
  read -rp "  Update LOCAL_LLM_BASE_URL secret in Supabase now? [Y/n] " secret_answer
  [[ "${secret_answer:-Y}" =~ ^[Yy]$ ]] && UPDATE_SECRET=true
fi

if [[ "${UPDATE_SECRET}" == "true" ]]; then
  if command -v npx >/dev/null 2>&1 && [[ -f "${PROJECT_ROOT}/package.json" ]]; then
    npx --prefix "${PROJECT_ROOT}" supabase secrets set \
      --project-ref trfqhobnkgtfccrdsexa \
      "LOCAL_LLM_BASE_URL=${NGROK_URL}" \
      && ok "Supabase secret updated ✓" \
      || warn "Failed to update secret — run manually:\n    npx supabase secrets set --project-ref trfqhobnkgtfccrdsexa LOCAL_LLM_BASE_URL=${NGROK_URL}"
  else
    warn "npx or package.json not found. Update manually:"
    echo -e "    ${BOLD}npx supabase secrets set LOCAL_LLM_BASE_URL=${NGROK_URL}${RESET}"
  fi
else
  info "Skipped. Run manually if needed:"
  echo -e "    ${BOLD}npx supabase secrets set LOCAL_LLM_BASE_URL=${NGROK_URL}${RESET}"
fi
echo ""

# ── 5. Summary ────────────────────────────────────────────────────────────────
hr
echo -e "${BOLD}  🎉  Dev environment is ready!${RESET}"
hr
echo ""
echo -e "  ${BOLD}Ollama${RESET}         http://localhost:${OLLAMA_PORT}"
echo -e "  ${BOLD}ngrok (public)${RESET} ${NGROK_URL}"
echo -e "  ${BOLD}ngrok (UI)${RESET}     http://localhost:${NGROK_API_PORT}"
echo -e "  ${BOLD}Model (LLM)${RESET}     ${OLLAMA_MODEL}"
echo -e "  ${BOLD}Model (Embed)${RESET}   ${OLLAMA_EMBED_MODEL}  (768-dim for pgvector)"
echo ""
echo -e "  ${BOLD}Flutter${RESET}  →  lib/core/config/app_config.dart"
echo -e "           localLlmBaseUrl = '$(echo "${NGROK_URL}")/v1'  (for direct phone access)"
echo -e "           localLlmBaseUrl = 'http://localhost:${OLLAMA_PORT}/v1'  (for emulator)"
echo ""
echo -e "  To stop all services:  ${BOLD}bash scripts/dev-stop.sh${RESET}"
echo ""
hr
echo ""
