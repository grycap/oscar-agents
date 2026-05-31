# OSCAR Agent Profile 1.0

This directory defines the OSCAR Agent RO-Crate profile used by deployable
agent crates in this repository.

The profile extends RO-Crate 1.1 with a small set of OSCAR Agent terms:

- `Agent`: root type for a deployable AI agent packaged as an OSCAR service.
- `AgentSoul`: Markdown file containing agent identity, behavior, and
  instructions.
- `AgentSkill`: reusable skill used by an agent.
- `agentMode`: execution mode, currently `exposed` or `on-demand`.
- `agentSkills`: local or external skills used by the agent.
- `skillSource`: origin of a skill reference, such as `local`, `marketplace`,
  or `external`.

Agent RO-Crates should reference this profile from the root entity with
`conformsTo`.
