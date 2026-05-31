# OSCAR Agents

This repository contains OSCAR service definitions and supporting files for deploying AI agents on OSCAR clusters, including exposed services and file-processing agents that can run synchronously or from storage events.

The repository is moving toward a layered layout where deployable agents live under `agents/`, reusable skills live under `skills/`, and framework-specific runtime infrastructure lives under `frameworks/`.

## Agents

- [`agents/pdf-summarizer`](./agents/pdf-summarizer): On-demand Hermes-based agent that extracts readable PDF text and returns a concise summary.

## Shared Resources

- [`frameworks/hermes`](./frameworks/hermes): Common Hermes bootstrap script and runtime definitions.
- [`frameworks/hermes/hermes-dashboard`](./frameworks/hermes/hermes-dashboard): Special Hermes dashboard service definition with its own startup script.
- [`skills/pdf-extract`](./skills/pdf-extract): Reusable skill for extracting readable text from PDFs.

## Usage

Review the agent-specific README, adapt the FDL to your OSCAR cluster, and deploy it with the OSCAR CLI or dashboard workflow that supports external service definitions.

Agent definitions should avoid committing provider credentials. Use OSCAR secrets or runtime configuration for API keys and other sensitive values.
