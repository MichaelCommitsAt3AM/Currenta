#!/usr/bin/env bash
# scripts/dev-stop.sh
# Stops ngrok (and any background ollama started by dev-start.sh).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RESET='\033[0m'
ok()   { echo -e "${GREEN}✅  $*${RESET}"; }
info() { echo -e "${CYAN}ℹ️   $*${RESET}"; }
warn() { echo -e "${YELLOW}⚠️   $*${RESET}"; }

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${CYAN}  🛑  Stopping Currenta Dev Services${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

# ── ngrok ─────────────────────────────────────────────────────────────────────
NGROK_PID_FILE="${PROJECT_ROOT}/.ngrok.pid"
if [[ -f "${NGROK_PID_FILE}" ]]; then
  NGROK_PID=$(cat "${NGROK_PID_FILE}")
  if kill "${NGROK_PID}" 2>/dev/null; then
    ok "Stopped ngrok (PID ${NGROK_PID})"
  else
    warn "ngrok PID ${NGROK_PID} was not running"
  fi
  rm -f "${NGROK_PID_FILE}"
elif pgrep -x ngrok >/dev/null 2>&1; then
  pkill -x ngrok && ok "Stopped ngrok" || warn "Could not stop ngrok"
else
  info "ngrok was not running"
fi

# ── Background ollama (only if started without systemd) ───────────────────────
OLLAMA_PID_FILE="${PROJECT_ROOT}/.ollama.pid"
if [[ -f "${OLLAMA_PID_FILE}" ]]; then
  OLLAMA_PID=$(cat "${OLLAMA_PID_FILE}")
  if kill "${OLLAMA_PID}" 2>/dev/null; then
    ok "Stopped background ollama (PID ${OLLAMA_PID})"
  else
    warn "Ollama PID ${OLLAMA_PID} was not running"
  fi
  rm -f "${OLLAMA_PID_FILE}"
else
  info "No background ollama PID file found (systemd-managed Ollama is left running)"
fi

# ── Scraper Service ─────────────────────────────────────────────────────────────
SCRAPER_PID_FILE="${PROJECT_ROOT}/.scraper.pid"
if [[ -f "${SCRAPER_PID_FILE}" ]]; then
  SCRAPER_PID=$(cat "${SCRAPER_PID_FILE}")
  if kill -9 "${SCRAPER_PID}" 2>/dev/null; then
    ok "Stopped Scraper Service (PID ${SCRAPER_PID})"
  else
    warn "Scraper Service PID ${SCRAPER_PID} was not running"
  fi
  rm -f "${SCRAPER_PID_FILE}"
elif pgrep -f "uvicorn main:app" >/dev/null 2>&1; then
  pkill -f "uvicorn main:app" && ok "Stopped Scraper Service" || warn "Could not stop Scraper Service"
else
  info "Scraper Service was not running"
fi

# Cleanup log files
rm -f "${PROJECT_ROOT}/.ngrok.log" "${PROJECT_ROOT}/.ollama.log" "${PROJECT_ROOT}/.scraper.log"

echo ""
ok "All done. Have a good one! 👋"
echo ""
