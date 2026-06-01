#!/usr/bin/env bash
set -euo pipefail

export HERMES_DATA_DIR="${HERMES_DATA_DIR:-/opt/data}"
export HERMES_BASE_PATH="${OSCAR_SERVICE_BASE_PATH:-${HERMES_BASE_PATH:-/}}"
export HERMES_HOME="${HERMES_HOME:-$HERMES_DATA_DIR}"
export OPENAI_BASE_URL="${OPENAI_BASE_URL:-https://api.openai.com/v1}"
export OPENAI_MODEL="${OPENAI_MODEL:-gpt-4o-mini}"
export LLM_PROVIDER_NAME="${LLM_PROVIDER_NAME:-${HERMES_PROVIDER_NAME:-openai-compatible}}"

HERMES_HOST="${HERMES_HOST:-0.0.0.0}"
HERMES_PORT="${HERMES_PORT:-9119}"

mkdir -p "$HERMES_DATA_DIR"
mkdir -p "$HERMES_HOME"

echo "Starting Hermes Agent dashboard"
echo "Hermes data: $HERMES_DATA_DIR"
echo "Dashboard bind: ${HERMES_HOST}:${HERMES_PORT}"
echo "Base path: $HERMES_BASE_PATH"
echo "Provider: $LLM_PROVIDER_NAME"
echo "Model: $OPENAI_MODEL"

if command -v hermes >/dev/null 2>&1; then
  HERMES_BIN="hermes"
elif [ -x /opt/hermes/.venv/bin/hermes ]; then
  HERMES_BIN="/opt/hermes/.venv/bin/hermes"
else
  echo "Hermes executable not found" >&2
  exit 1
fi

if [ -n "${OPENAI_API_KEY:-}" ]; then
  cat > "$HERMES_HOME/config.yaml" <<EOF
custom_providers:
  - name: ${LLM_PROVIDER_NAME}
    base_url: ${OPENAI_BASE_URL}
    api_key: ${OPENAI_API_KEY}
    model: ${OPENAI_MODEL}
model: ${OPENAI_MODEL}
provider: ${LLM_PROVIDER_NAME}
hooks_auto_accept: true
EOF
  chmod 600 "$HERMES_HOME/config.yaml"
else
  echo "OPENAI_API_KEY is not set; keeping any existing Hermes provider configuration"
fi

if [ -d /opt/hermes/ui-tui/packages/hermes-ink ]; then
  echo "Preparing Hermes TUI dependencies"
  (
    cd /opt/hermes/ui-tui
    npm run build --prefix packages/hermes-ink
    mkdir -p node_modules/@hermes/ink
    for file in index.js index.d.ts text-input.js text-input.d.ts; do
      src="packages/hermes-ink/$file"
      dst="node_modules/@hermes/ink/$file"
      if [ ! -e "$dst" ] || [ "$src" -ef "$dst" ]; then
        continue
      fi
      cp "$src" "$dst"
    done
    if [ ! -e node_modules/@hermes/ink/dist ] || [ ! packages/hermes-ink/dist -ef node_modules/@hermes/ink/dist ]; then
      rm -rf node_modules/@hermes/ink/dist
      cp -R packages/hermes-ink/dist node_modules/@hermes/ink/dist
    fi
  )
fi

python3 - <<'PY'
import os
import re
from pathlib import Path

base = os.environ.get("HERMES_BASE_PATH", "/").rstrip("/")
if not base or base == "/":
    raise SystemExit(0)

web_dist = Path(os.environ.get("HERMES_WEB_DIST", "/opt/hermes/hermes_cli/web_dist"))
server_path = Path("/opt/hermes/hermes_cli/web_server.py")

for js_path in web_dist.glob("assets/index-*.js"):
    js = js_path.read_text()
    js = re.sub(
        r'(\$\{[^}]+\}//\$\{(?:window\.)?location\.host\})(?!\$\{[^}]+BASE_PATH[^}]*\})(/api/(?:ws|events|pty)\?)',
        r'\1${window.__HERMES_BASE_PATH__||""}\2',
        js,
    )
    js_path.write_text(js)

if server_path.exists():
    server = server_path.read_text()
    server = server.replace(
        'prefix = _normalise_prefix(request.headers.get("x-forwarded-prefix"))',
        'prefix = _normalise_prefix(request.headers.get("x-forwarded-prefix") or os.getenv("HERMES_BASE_PATH", ""))',
    )
    server_path.write_text(server)
PY

dashboard_args=(
  dashboard
  --host "$HERMES_HOST"
  --port "$HERMES_PORT"
  --no-open
)

if [ "${HERMES_DASHBOARD_TUI:-true}" = "true" ]; then
  dashboard_args+=(--tui)
fi

if [ "${HERMES_DASHBOARD_INSECURE:-false}" = "true" ]; then
  dashboard_args+=(--insecure)
fi

exec "$HERMES_BIN" "${dashboard_args[@]}"
