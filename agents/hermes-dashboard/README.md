# Hermes Dashboard

This OSCAR agent deploys [Hermes Agent](https://github.com/NousResearch/hermes-agent) as an exposed service using the `nousresearch/hermes-agent` Docker image. It starts the Hermes web dashboard with the embedded TUI chat enabled and can preconfigure an OpenAI-compatible LLM provider from the FDL.

The service does not deploy an LLM. Hermes should be configured to use an external or already deployed OpenAI-compatible provider such as OpenAI, OpenRouter, a vLLM service running in OSCAR, or PoliGPT.

## Deployment defaults

- `name: hermes-dashboard`
- `memory: 2Gi`
- `cpu: 2.0`
- `image: nousresearch/hermes-agent:v2026.9.7`
- `api_port: 9119`
- `health_path: /api/health`
- `set_auth: false`: authentication is handled by Hermes itself

## Persistent volume

The official Hermes image stores all user data in `/opt/data`. The example FDL mounts an existing OSCAR volume there:

```yaml
volume:
  name: your-volume-name
  mount_path: /opt/data
```

The mounted directory contains Hermes configuration, credentials, sessions, memories, skills, hooks, logs, and related runtime state:

```text
/opt/data
```

Before deploying, replace `volume.name` with the OSCAR volume that should persist Hermes configuration, sessions, memory, installed skills, and workspace files.

## Access

With OSCAR DNS-based routing enabled, the service is exposed at the root of its
own subdomain:

```text
https://hermes-dashboard.<OSCAR_INGRESS_HOST>/
```

Access is protected by Hermes, not by OSCAR ForwardAuth. The pinned image
requires an internal dashboard authentication provider for non-loopback binds.
This definition enables the bundled username/password provider through
`HERMES_DASHBOARD_BASIC_AUTH_*` variables.

Sign in to Hermes with username **`admin`** and the **OSCAR service token** as
the password (use **Copy token** in OSCAR Dashboard). The startup script reads
`OSCAR_SERVICE_TOKEN`, which OSCAR injects automatically, and refuses to start
if it is missing or empty. No separate dashboard username/password is required
in the FDL. Use HTTPS and never put the token in a URL.

Keep `HERMES_DASHBOARD_BASIC_AUTH_SECRET` stable to preserve Hermes sessions
across restarts; it is the session-signing secret, not the login password.

**Security boundary:** OSCAR does not check user identity or service permissions
on requests to this exposed endpoint. Anyone holding the service token can sign
in as `admin`; Hermes public endpoints remain reachable without OSCAR login.
This configuration targets a personal, access-restricted deployment. Review
network exposure before using it on a public or shared cluster. Disabling
ForwardAuth also avoids forwarding an OIDC bearer that Hermes would reject
before checking its own session cookie.

The dashboard is started with:

```bash
hermes dashboard --host 0.0.0.0 --port 9119 --no-open --tui
```

Use the dashboard to review the configured LLM provider and then open the Chat/TUI view.

The official dashboard runs at `/`, matching OSCAR's DNS-based exposed-service
routing. No asset, WebSocket, or server-source rewriting is required.

## Provider configuration

The startup script can generate a Hermes `config.yaml` from deployment variables before starting the dashboard. The sample uses an OpenAI-compatible EGI endpoint:

```yaml
environment:
  variables:
    LLM_PROVIDER_NAME: egi
    OPENAI_BASE_URL: https://llm.ai.egi.eu/v1
    OPENAI_MODEL: qwen3.5
  secrets:
    OPENAI_API_KEY: change-me
    HERMES_DASHBOARD_BASIC_AUTH_SECRET: change-me-to-32-or-more-random-bytes
```

Set provider API keys as OSCAR secrets instead of committing them to the FDL. If `OPENAI_API_KEY` is not set, the script leaves any existing Hermes provider configuration in the persistent data directory untouched.

For PoliGPT or other OpenAI-compatible endpoints, update `LLM_PROVIDER_NAME`, `OPENAI_BASE_URL`, and `OPENAI_MODEL` in the FDL. If the provider requires custom headers beyond the standard `Authorization: Bearer` header, an adapter or proxy may be needed.

## Notes

- Keep Hermes authentication enabled. `set_auth: false` disables only the
  external OSCAR authentication layer, not Hermes's own authentication gate.
- The dashboard can edit configuration and secrets stored in the Hermes data directory.
- The service uses the `nousresearch/hermes-agent` image, which includes Hermes dependencies, Node.js/npm, Playwright/Chromium, ripgrep, ffmpeg, and volume bootstrapping for `/opt/data`.
