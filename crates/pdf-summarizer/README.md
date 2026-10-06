# PDF Summarizer Agent

This OSCAR agent processes PDF files on demand. It extracts readable text and
asks Hermes Agent to produce a concise, factual plain-text summary.

## Files

- `fdl.yml`: OSCAR deployment definition with `AGENT_SOUL` and `AGENT_SKILLS`
  placeholders; it contains no embedded Markdown guidance.
- `SOUL.md`: identity and behavior contract.
- `ro-crate-metadata.json`: machine-readable package metadata and default guidance references.
- `icon.png`: agent icon.
- `script.sh`: crate-local Hermes bootstrap script (no embedded SOUL or skill).
- `skills/pdf-extract/SKILL.md`: skill owned by this crate.

## Guidance references (not yet deployable as-is)

The FDL references the local `script.sh` and declares placeholder values
`YOUR_AGENT_SOUL` and `YOUR_AGENT_SKILLS`. The metadata's `agentSoul` and
`agentSkills` identify the local Markdown files supplying their respective
default values. A supporting client must read those UTF-8 files verbatim,
reject missing files and paths escaping the crate, show editable values, and
replace the placeholders before deployment. With multiple active skills, sort
by `@id` and join their contents with two newlines. Explicit user overrides
take precedence. Every active skill is packaged in this crate and listed in
`hasPart`; no external skill is fetched or installed at deployment.

**Current `oscar-cli` does not read guidance references from RO-Crate metadata.**
Without a manual override, it transmits the `YOUR_AGENT_*` placeholders.
Do not run `hub deploy` or `apply` on this crate until the CLI supports the
metadata contract (or you manually supply complete guidance values). The
dashboard also needs materialization and an editor for preview. `script.sh`
rejects known unresolved values at runtime, but service creation itself is
not prevented.

Edit `script.sh`, `skills/pdf-extract/SKILL.md`, `fdl.yml`,
`ro-crate-metadata.json`, and `SOUL.md` directly inside this crate. No generation step or shared root
copy is needed. The script contains no duplicate guidance.

Use the Hermes image referenced by `fdl.yml`, or choose another image in the
FDL when deployment support is available:

```bash
docker pull ghcr.io/grycap/hermes-agent:v2026.5.29.2
```

Once clients support the metadata references, configure the provider values at
deployment and provide an OSCAR secret for `OPENAI_API_KEY`. This crate has
no executable Hub acceptance tests yet.

## Run synchronously

Only after a valid deployment with resolved agent guidance, on a cluster with
a synchronous Serverless backend (such as Knative):

```bash
oscar-cli service run pdf-summarizer --file-input ./paper.pdf --decode-output --output ./paper-summary.txt
```

`serviceType: asynchronous` describes the primary bucket/job workflow; it does
not disable synchronous invocation on a compatible cluster.

## Run asynchronously via the input bucket

After a valid deployment, upload the input to the configured input path. The
bucket notification triggers the job; **do not invoke `service job` as well**,
which would be a separate invocation. Check job logs and retrieve the output
only after completion:

```bash
oscar-cli service put-file pdf-summarizer minio.default ./paper.pdf pdf-summarizer/input/paper.pdf
oscar-cli service logs list pdf-summarizer
oscar-cli service logs get pdf-summarizer --latest
oscar-cli service get-file pdf-summarizer minio.default pdf-summarizer/output/paper-result.txt ./paper-summary.txt
```

The output object name assumes the input is named `paper.pdf`; check the
service output path and completed job before downloading. For explicit
asynchronous invocation instead of a bucket trigger, `oscar-cli service job`
requires either `--file-input` or `--text-input`; it cannot be called without
input.
