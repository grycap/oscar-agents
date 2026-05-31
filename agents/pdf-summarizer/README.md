# PDF Summarizer Agent

This OSCAR agent processes PDF files on demand. It extracts readable text with
the shared Hermes PDF runtime and asks Hermes Agent to produce a concise,
factual plain-text summary.

## Files

- `fdl.yml`: OSCAR deployment definition.
- `SOUL.md`: identity and behavior contract.
- `ro-crate-metadata.json`: machine-readable package metadata.
- `icon.png`: agent icon.
- `../../frameworks/hermes/script.sh`: shared Hermes bootstrap script.
- `../../skills/pdf-extract/SKILL.md`: reusable PDF extraction skill.

## Deploy

The FDL resolves the shared Hermes bootstrap script relative to this agent
directory as `../../frameworks/hermes/script.sh`, matching the RO-Crate
references used by OSCAR Hub tooling.

Use the Hermes image referenced by `fdl.yml`, or replace the image with one
available in your registry:

```bash
docker pull ghcr.io/grycap/hermes-agent:v2026.5.29.2
```

Then deploy:

```bash
ocli-dev hub deploy --local-path $HOME/Documents/GitHub/grycap/oscar-agents -c localhost-oidc-grycap -n hermes-agent-00 agents/pdf-summarizer
```

## Run synchronously

```bash
oscar-cli service run pdf-summarizer --file-input ./paper.pdf --decode-output --output ./paper-summary.txt
```

## Run asynchronously

```bash
oscar-cli service put-file pdf-summarizer minio.default ./paper.pdf pdf-summarizer/input/paper.pdf
oscar-cli service get-file pdf-summarizer minio.default pdf-summarizer/output/paper-result.txt ./paper-summary.txt
```
