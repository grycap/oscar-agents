# Hermes Dashboard

This OSCAR agent deploys [Hermes Agent](https://github.com/NousResearch/hermes-agent) as an exposed service using the `nousresearch/hermes-agent` Docker image. It starts the Hermes web dashboard with the embedded TUI chat enabled and can preconfigure an OpenAI-compatible LLM provider from the FDL.

The service does not deploy an LLM. Hermes should be configured to use an external or already deployed OpenAI-compatible provider such as OpenAI, OpenRouter, a vLLM service running in OSCAR, or PoliGPT.

## Deployment defaults

- `name: hermes-dashboard`
- `memory: 2Gi`
- `cpu: 2.0`
- `image: nousresearch/hermes-agent:v2026.5.7`
- `api_port: 9119`
- `health_path: /api/status`
- `set_auth: true` with `auth_type: forward`

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

The service is exposed at:

```text
/system/services/hermes-dashboard/exposed/
```

Access is protected by OSCAR through Traefik ForwardAuth. The OSCAR Dashboard
can open the service with:

```text
/system/services/hermes-dashboard/exposed/?token=YOUR_OSCAR_SERVICE_TOKEN
```

OSCAR validates the service token and returns a scoped authentication cookie for
subsequent dashboard asset and WebSocket requests.

The dashboard is started with:

```bash
hermes dashboard --host 0.0.0.0 --port 9119 --no-open --tui --insecure
```

Use the dashboard to review the configured LLM provider and then open the Chat/TUI view.

The official dashboard is built to run at `/`. OSCAR exposes services under a path prefix such as `/system/services/<service-name>/exposed/` and injects that prefix as `OSCAR_SERVICE_BASE_PATH`. The Gateway API route strips the prefix before requests reach Hermes, while the startup script makes Hermes generate prefixed public asset URLs and patches the dashboard WebSocket URLs. This keeps the official image unchanged while making the web UI work behind the OSCAR route prefix, even when the service is renamed.

## Provider configuration

The startup script can generate a Hermes `config.yaml` from deployment variables before starting the dashboard. The sample uses an OpenAI-compatible EGI endpoint:

```yaml
environment:
  variables:
    LLM_PROVIDER_NAME: egi
    OPENAI_BASE_URL: https://llm.ai.egi.eu/v1
    OPENAI_MODEL: agentic
  secrets:
    OPENAI_API_KEY: change-me
```

Set provider API keys as OSCAR secrets instead of committing them to the FDL. If `OPENAI_API_KEY` is not set, the script leaves any existing Hermes provider configuration in the persistent data directory untouched.

For PoliGPT or other OpenAI-compatible endpoints, update `LLM_PROVIDER_NAME`, `OPENAI_BASE_URL`, and `OPENAI_MODEL` in the FDL. If the provider requires custom headers beyond `Authorization: Bearer`, an adapter or proxy may be needed.

## Notes

- Hermes requires `--insecure` when the dashboard binds to `0.0.0.0`. Keep OSCAR authentication enabled; this crate uses `auth_type: forward` so the Gateway/Traefik layer delegates authorization to OSCAR.
- The dashboard can edit configuration and secrets stored in the Hermes data directory.
- The service uses the `nousresearch/hermes-agent` image, which includes Hermes dependencies, Node.js/npm, Playwright/Chromium, ripgrep, ffmpeg, and volume bootstrapping for `/opt/data`.
