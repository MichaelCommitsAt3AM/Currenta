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
# ── Show what's currently running ────────────────────────────────────────────
NGROK_API_PORT="${NGROK_API_PORT:-4040}"

if curl -sf "http://localhost:${NGROK_API_PORT}/api/tunnels" >/dev/null 2>&1; then
  BACKEND_URL=$(curl -sf "http://localhost:${NGROK_API_PORT}/api/tunnels" \
    | grep -oP '"name":"backend".*?"public_url":"\K[^"]+' 2>/dev/null | head -1 || echo "unknown")
  echo -e "${CYAN}  Active Tunnels:${RESET}"
  echo -e "    🌐  Backend    →  ${BACKEND_URL}"
  echo ""
else
  info "ngrok was not running"
fi


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

# ── Admin Portal Server ───────────────────────────────────────────────────────
ADMIN_PID_FILE="${PROJECT_ROOT}/.admin.pid"
if [[ -f "${ADMIN_PID_FILE}" ]]; then
  ADMIN_PID=$(cat "${ADMIN_PID_FILE}")
  if kill "${ADMIN_PID}" 2>/dev/null; then
    ok "Stopped Admin Portal server (PID ${ADMIN_PID})"
  else
    warn "Admin Portal server PID ${ADMIN_PID} was not running"
  fi
  rm -f "${ADMIN_PID_FILE}"
elif lsof -i :3000 -t >/dev/null 2>&1; then
  fuser -k 3000/tcp && ok "Stopped process running on port 3000" || warn "Could not stop process on port 3000"
else
  info "Admin Portal server was not running"
fi

# ── Backend & Redis (Docker) ──────────────────────────────────────────────────
info "Stopping Docker services (API, Worker, Redis, Caddy)..."
if docker compose ps >/dev/null 2>&1; then
  docker compose down && ok "Stopped Docker services" || warn "Failed to stop Docker services"
else
  info "Backend services were not running in Docker"
fi

# Cleanup log files
rm -f "${PROJECT_ROOT}/.ngrok.log" "${PROJECT_ROOT}/.ollama.log" "${PROJECT_ROOT}/.backend.log" "${PROJECT_ROOT}/.scraper.log" "${PROJECT_ROOT}/.admin.log"

echo ""
ok "All done. Have a good one! 👋"
echo ""
