# Hermes Framework

This directory contains shared infrastructure for OSCAR agents that run on
Hermes Agent.

## Files

- `script.sh`: common bootstrap script referenced by agent FDL files.
- `runtimes/base/Dockerfile`: base Hermes runtime image used by Hermes-based
  agents.

Agent-specific identity, skills, deployment defaults, and RO-Crate metadata live
outside this framework directory.
