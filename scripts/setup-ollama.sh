#!/usr/bin/env bash
# scripts/setup-ollama.sh
# Configures Ollama for use with Supabase edge functions via ngrok.
# Run once with: sudo bash scripts/setup-ollama.sh
# Safe to re-run — all steps are idempotent.

set -euo pipefail

OLLAMA_MODEL="${1:-llama3.1}"
OVERRIDE_DIR="/etc/systemd/system/ollama.service.d"
OVERRIDE_FILE="${OVERRIDE_DIR}/currenta.conf"

# ── Must run as root ──────────────────────────────────────────────
if [[ "${EUID}" -ne 0 ]]; then
  echo "❌  Please run with sudo: sudo bash scripts/setup-ollama.sh"
  exit 1
fi

echo "🔧  Setting up Ollama for Currenta..."

# ── 1. Create drop-in override directory ─────────────────────────
mkdir -p "${OVERRIDE_DIR}"
echo "✅  Drop-in directory: ${OVERRIDE_DIR}"

# ── 2. Write the override file ────────────────────────────────────
cat > "${OVERRIDE_FILE}" << 'EOF'
[Service]
# Allow requests from any origin (required for Supabase edge functions via ngrok)
Environment="OLLAMA_ORIGINS=*"
# Keep Ollama alive even when idle (prevents auto-shutdown)
Environment="OLLAMA_KEEP_ALIVE=-1"
EOF
echo "✅  Written override: ${OVERRIDE_FILE}"

# ── 3. Reload systemd and restart Ollama ─────────────────────────
systemctl daemon-reload
systemctl restart ollama
echo "✅  Ollama service restarted"

# ── 4. Wait for Ollama to be ready ───────────────────────────────
echo "⏳  Waiting for Ollama to be ready..."
for i in $(seq 1 15); do
  if curl -sf http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "✅  Ollama is up"
    break
  fi
  sleep 1
done

# ── 5. Pull the required model if not already present ────────────
echo "📦  Checking for model: ${OLLAMA_MODEL}"
if ollama list | grep -q "^${OLLAMA_MODEL}"; then
  echo "✅  Model '${OLLAMA_MODEL}' already present"
else
  echo "⬇️   Pulling '${OLLAMA_MODEL}' (this may take a few minutes)..."
  ollama pull "${OLLAMA_MODEL}"
  echo "✅  Model '${OLLAMA_MODEL}' ready"
fi

# ── 6. Verify OLLAMA_ORIGINS is applied ──────────────────────────
APPLIED=$(systemctl show ollama --property=Environment | grep OLLAMA_ORIGINS || true)
if [[ -n "${APPLIED}" ]]; then
  echo "✅  OLLAMA_ORIGINS confirmed: ${APPLIED}"
else
  echo "❌  OLLAMA_ORIGINS not found in service environment — check ${OVERRIDE_FILE}"
  exit 1
fi

# ── 7. Smoke-test CORS ────────────────────────────────────────────
echo "🧪  Testing CORS with Supabase origin..."
STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST http://localhost:11434/v1/embeddings \
  -H "Content-Type: application/json" \
  -H "Origin: https://trfqhobnkgtfccrdsexa.supabase.co" \
  -d "{\"model\":\"${OLLAMA_MODEL}\",\"input\":\"test\"}")

if [[ "${STATUS}" == "200" ]]; then
  echo "✅  CORS smoke test passed (200 OK)"
else
  echo "⚠️   CORS smoke test returned HTTP ${STATUS} — investigate further"
fi

echo ""
echo "🎉  Ollama setup complete!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚠️   IMPORTANT: You must restart ngrok using the project config"
echo "    so it strips the Origin header (fixes Ollama 403 errors)."
echo ""
echo "    Run in a new terminal (without sudo):"
echo "    ngrok start --config scripts/ngrok.yml ollama"
echo ""
echo "    Then update your Supabase secret with the new URL:"
echo "    npx supabase secrets set LOCAL_LLM_BASE_URL=https://<new-ngrok-url>"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
