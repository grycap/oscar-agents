# OSCAR Agents

This repository contains OSCAR service definitions and supporting files for deploying AI agents on OSCAR clusters, including exposed services and file-processing agents that can run synchronously or from storage events.

Each agent lives in its own directory and includes the Function Definition Language (FDL), startup script, metadata, icon, and deployment notes needed by OSCAR-compatible tooling.

## Agents

- [`hermes-dashboard`](./hermes-dashboard): Hermes Agent by Nous Research, deployed as an OSCAR exposed service with persistent volume-backed state and the dashboard TUI chat enabled.
- [`hermes-agent`](./hermes-agent): Generic Hermes-based OSCAR agent runtime for synchronous and asynchronous file processing according to the deployed `SOUL.md`.

## Usage

Review the agent-specific README, adapt the FDL to your OSCAR cluster, and deploy it with the OSCAR CLI or dashboard workflow that supports external service definitions.

Agent definitions should avoid committing provider credentials. Use OSCAR secrets or runtime configuration for API keys and other sensitive values.
