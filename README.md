# OSCAR Agents

This repository contains OSCAR service definitions and supporting files for deploying browser-accessible AI agents on OSCAR clusters.

Each agent lives in its own directory and includes the Function Definition Language (FDL), startup script, metadata, icon, and deployment notes needed by OSCAR-compatible tooling.

## Agents

- [`hermes`](./hermes): Hermes Agent by Nous Research, deployed as an OSCAR exposed service with persistent volume-backed state and the dashboard TUI chat enabled.

## Usage

Review the agent-specific README, adapt the FDL to your OSCAR cluster, and deploy it with the OSCAR CLI or dashboard workflow that supports external service definitions.

Agent definitions should avoid committing provider credentials. Use OSCAR secrets or runtime configuration for API keys and other sensitive values.
