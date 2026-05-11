#!/usr/bin/env bash
set -euo pipefail

export HERMES_DATA_DIR="${HERMES_DATA_DIR:-/opt/data}"
export HERMES_BASE_PATH="${OSCAR_SERVICE_BASE_PATH:-${HERMES_BASE_PATH:-/}}"

HERMES_HOST="${HERMES_HOST:-0.0.0.0}"
HERMES_PORT="${HERMES_PORT:-9119}"

mkdir -p "$HERMES_DATA_DIR"

echo "Starting Hermes Agent dashboard"
echo "Hermes data: $HERMES_DATA_DIR"
echo "Dashboard bind: ${HERMES_HOST}:${HERMES_PORT}"
echo "Base path: $HERMES_BASE_PATH"

if command -v hermes >/dev/null 2>&1; then
  HERMES_BIN="hermes"
elif [ -x /opt/hermes/.venv/bin/hermes ]; then
  HERMES_BIN="/opt/hermes/.venv/bin/hermes"
else
  echo "Hermes executable not found" >&2
  exit 1
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

base_script = (
    f'<script>window.__HERMES_BASE_PATH__="{base}";</script>'
)
web_dist = Path(os.environ.get("HERMES_WEB_DIST", "/opt/hermes/hermes_cli/web_dist"))
index_path = web_dist / "index.html"
server_path = Path("/opt/hermes/hermes_cli/web_server.py")

if index_path.exists():
    html = index_path.read_text()
    html = html.replace(base_script, "")
    html = html.replace('href="/favicon.ico"', f'href="{base}/favicon.ico"')
    html = html.replace('src="/assets/', f'src="{base}/assets/')
    html = html.replace('href="/assets/', f'href="{base}/assets/')
    html = html.replace('src="/ds-assets/', f'src="{base}/ds-assets/')
    html = html.replace('href="/ds-assets/', f'href="{base}/ds-assets/')
    if "</head>" in html:
        html = html.replace(
            '<meta name="viewport" content="width=device-width, initial-scale=1.0" />',
            '<meta name="viewport" content="width=device-width, initial-scale=1.0" />\n'
            f'    {base_script}',
            1,
        )
    index_path.write_text(html)

for css_path in web_dist.glob("assets/*.css"):
    css = css_path.read_text()
    css = css.replace(f"url({base}/", "url(/")
    css = css.replace("url(/", f"url({base}/")
    css_path.write_text(css)

for js_path in web_dist.glob("assets/index-*.js"):
    js = js_path.read_text()
    js = js.replace(f'src:"{base}/ds-assets/', 'src:"/ds-assets/')
    js = js.replace('src:"/ds-assets/', f'src:"{base}/ds-assets/')
    js = re.sub(
        r'(\$\{[^}]+\}//\$\{(?:window\.)?location\.host\})(?!\$\{[^}]+BASE_PATH[^}]*\})(/api/(?:ws|events|pty)\?)',
        r'\1${window.__HERMES_BASE_PATH__||""}\2',
        js,
    )
    js_path.write_text(js)

if server_path.exists():
    server = server_path.read_text()
    marker = "class _HermesBasePathMiddleware:"
    if marker not in server:
        middleware = r'''

class _HermesBasePathMiddleware:
    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope.get("type") in ("http", "websocket"):
                base_path = os.getenv("HERMES_BASE_PATH", "").rstrip("/")
                path = scope.get("path", "")
                if base_path and base_path != "/" and (path == base_path or path.startswith(base_path + "/")):
                    scope = dict(scope)
                    scope["path"] = path[len(base_path):] or "/"
                    raw_path = scope.get("raw_path")
                    if isinstance(raw_path, (bytes, bytearray)):
                        raw_base = base_path.encode()
                        if raw_path == raw_base:
                            scope["raw_path"] = b"/"
                        elif raw_path.startswith(raw_base + b"/"):
                            scope["raw_path"] = raw_path[len(raw_base):] or b"/"
        await self.app(scope, receive, send)
'''
        server = server.replace(
            'app = FastAPI(title="Hermes Agent", version=__version__)\n',
            f'app = FastAPI(title="Hermes Agent", version=__version__)\n{middleware}\napp.add_middleware(_HermesBasePathMiddleware)\n',
            1,
        )
    server = server.replace(
        'if client_host and client_host not in _LOOPBACK_HOSTS:',
        'if os.getenv("HERMES_DASHBOARD_INSECURE", "").lower() not in ("1", "true", "yes", "on") and client_host and client_host not in _LOOPBACK_HOSTS:',
    )
    server = server.replace(
        'return f"ws://{netloc}/api/pub?{qs}"',
        'return f"ws://{netloc}{os.getenv(\'HERMES_BASE_PATH\', \'\').rstrip(\'/\')}/api/pub?{qs}"',
    )
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
