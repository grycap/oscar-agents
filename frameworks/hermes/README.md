# Hermes Framework

This directory contains runtime-image definitions for OSCAR agents that run on
Hermes Agent. Each crate maintains its own script and guidance.

## Files

- `runtimes/base/Dockerfile`: base Hermes runtime image used by Hermes-based
  agents.

Agent-specific scripts, identity, skills, deployment defaults, and RO-Crate
metadata live in their respective `crates/` directories.
