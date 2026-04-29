# Hermes Agent

This definition deploys [Hermes Agent](https://github.com/NousResearch/hermes-agent) as an OSCAR exposed service using the official `nousresearch/hermes-agent` Docker image. It starts the Hermes web dashboard with the embedded TUI chat enabled, so users can configure providers and chat with the agent from the browser.

The service does not deploy an LLM. Hermes should be configured to use an external or already deployed OpenAI-compatible provider such as OpenAI, OpenRouter, a vLLM service running in OSCAR, or PoliGPT.

## Deployment defaults

- `name: hermes-agent`
- `memory: 4Gi`
- `cpu: 2.0`
- `image: nousresearch/hermes-agent:latest`
- `api_port: 9119`
- `health_path: /api/status`

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
/system/services/hermes-agent/exposed/
```

The dashboard is started with:

```bash
hermes dashboard --host 0.0.0.0 --port 9119 --no-open --tui --insecure
```

Use the dashboard to configure an LLM provider and then open the Chat/TUI view.

The official dashboard is built to run at `/`. OSCAR exposes services under a path prefix such as `/system/services/<service-name>/exposed/`, so the startup script patches the dashboard assets and backend routing at container start. This keeps the official image unchanged while making the web UI work behind the OSCAR ingress prefix.

## Provider configuration

The official image reads API keys from `/opt/data/.env`. You can also pass keys as environment variables; direct environment variables override values from `.env`. Set provider API keys as OSCAR secrets instead of committing them to the FDL. The sample includes an `OPENAI_API_KEY` placeholder only:

```yaml
environment:
  secrets:
    OPENAI_API_KEY: change-me
```

For PoliGPT or other OpenAI-compatible endpoints, configure the base URL and model in Hermes after deployment. If the provider requires custom headers beyond `Authorization: Bearer`, an adapter or proxy may be needed.

## Notes

- Hermes requires `--insecure` when the dashboard binds to `0.0.0.0`. Keep OSCAR authentication enabled unless the service is protected by another access control layer.
- The dashboard can edit configuration and secrets stored in the Hermes data directory.
- The service uses the official `nousresearch/hermes-agent` image, which includes Hermes dependencies, Node.js/npm, Playwright/Chromium, ripgrep, ffmpeg, and volume bootstrapping for `/opt/data`.
