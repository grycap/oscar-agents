#!/usr/bin/env bash
set -euo pipefail

# OSCAR injects the service token; never fall back to an unrelated password.
export HERMES_DASHBOARD_BASIC_AUTH_USERNAME="admin"
export HERMES_DASHBOARD_BASIC_AUTH_PASSWORD="${OSCAR_SERVICE_TOKEN:?OSCAR_SERVICE_TOKEN must be set and non-empty}"

export HERMES_DATA_DIR="${HERMES_DATA_DIR:-/opt/data}"
export HERMES_HOME="${HERMES_HOME:-$HERMES_DATA_DIR}"
export OPENAI_BASE_URL="${OPENAI_BASE_URL:-https://api.openai.com/v1}"
export OPENAI_MODEL="${OPENAI_MODEL:-gpt-4o-mini}"
export LLM_PROVIDER_NAME="${LLM_PROVIDER_NAME:-${HERMES_PROVIDER_NAME:-openai-compatible}}"

HERMES_HOST="${HERMES_HOST:-0.0.0.0}"
HERMES_PORT="${HERMES_PORT:-9119}"

mkdir -p "$HERMES_DATA_DIR"
mkdir -p "$HERMES_HOME"

# The OSCAR supervisor starts the script as root, while the Hermes image runs
# the dashboard as UID/GID 10000. Do not recursively chown the volume: an old
# replica may still be updating SQLite WAL files during a rolling deployment.
if [ "$(id -u)" -eq 0 ]; then
  chown "${HERMES_RUNTIME_UID:-10000}:${HERMES_RUNTIME_GID:-10000}" "$HERMES_HOME"
fi

echo "Starting Hermes Agent dashboard"
echo "Hermes data: $HERMES_DATA_DIR"
echo "Dashboard bind: ${HERMES_HOST}:${HERMES_PORT}"
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
  config_tmp="$(mktemp "$HERMES_HOME/.config.yaml.XXXXXX")"
  cat > "$config_tmp" <<EOF
custom_providers:
  - name: ${LLM_PROVIDER_NAME}
    base_url: ${OPENAI_BASE_URL}
    api_key: ${OPENAI_API_KEY}
    model: ${OPENAI_MODEL}
model: ${OPENAI_MODEL}
provider: ${LLM_PROVIDER_NAME}
hooks_auto_accept: true
EOF
  chmod 600 "$config_tmp"
  if [ "$(id -u)" -eq 0 ]; then
    chown "${HERMES_RUNTIME_UID:-10000}:${HERMES_RUNTIME_GID:-10000}" "$config_tmp"
  fi
  mv "$config_tmp" "$HERMES_HOME/config.yaml"
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

dashboard_args=(
  dashboard
  --host "$HERMES_HOST"
  --port "$HERMES_PORT"
  --no-open
)

if [ "${HERMES_DASHBOARD_TUI:-true}" = "true" ]; then
  dashboard_args+=(--tui)
fi

exec "$HERMES_BIN" "${dashboard_args[@]}"
