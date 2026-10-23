# OSCAR Agents

OSCAR service definitions and supporting files for deploying AI agents, including exposed services and PDF-processing agents.

## Crates

- [`crates/pdf-summarizer`](./crates/pdf-summarizer): On-demand Hermes-based agent that extracts PDF text and returns a concise summary.
- [`crates/hermes-dashboard`](./crates/hermes-dashboard): Exposed Hermes dashboard agent with persistent volume-backed state.

Each crate owns its FDL, script, SOUL and any local skills. `frameworks/hermes/runtimes/` contains runtime-image definitions; it is not required to assemble the crates.

## RO-Crate metadata

Both agent crates follow RO-Crate 1.2 and reference the sole [OSCAR Agent Profile 1.1](./profiles/oscar-agent-1.1/README.md). The profile itself is also a RO-Crate 1.2 Profile Crate. Validate the profile and agents from the repository root with the same validator version as CI:

```bash
for crate in profiles/oscar-agent-1.1/ crates/*/; do
  uvx --from roc-validator==0.12.2 rocrate-validator validate -p ro-crate-1.2 --verbose --no-paging "$crate"
done
```

This checks conformance to the **base** RO-Crate 1.2 specification, not to all
OSCAR Agent-specific rules. Offline Python tests check the additional local
contract:

```bash
python3 -m unittest discover -s tests -p 'test_*.py'
```

A separate Go harness exercises the local and remote Hub FDL loaders without a cluster. Run it from a local `oscar-cli` checkout:

```bash
go run ../oscar-agents/tests/hub_contract.go ../oscar-agents/crates
```

The PDF FDL keeps `AGENT_SOUL` and `AGENT_SKILLS` as placeholders. Its RO-Crate metadata declares `agentSoul` and the packaged local `agentSkills` as the single source of default guidance. **The current `oscar-cli` and dashboard do not reliably materialize these metadata references into FDL variables.** Do not deploy this FDL as-is: the current CLI sends unresolved strings to OSCAR, and the runtime guard does not prevent creation of a misconfigured service. Passing RO-Crate validation or loading the FDL is not an acceptance test.

Review the agent-specific README before deployment. Do not commit provider credentials; use OSCAR secrets or local ignored `.env` files for sensitive values.
