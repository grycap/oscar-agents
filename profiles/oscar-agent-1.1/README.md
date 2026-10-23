# OSCAR Agent Profile 1.1

This is the sole OSCAR Agent profile in this repository. Its
`ro-crate-metadata.json` is a Profile Crate conforming to RO-Crate 1.2; the root
uses `isProfileOf` to reference the base specification and describes the
profile terms as `DefinedTerm` entities. This README is the human-readable
profile description. The additional terms cover agent identity (`Agent`,
`AgentSoul`, `agentSoul`), packaged skills (`AgentSkill`, `agentSkills`) and
lifecycle (`agentMode`). Each agent crate's root entity
references this profile through `conformsTo` and describes the profile as an
entity in its metadata graph.

The local validator checks the base RO-Crate 1.2 requirements. The offline
Python tests check additional OSCAR Agent profile conventions; the profile's
metadata alone is not an executable set of validation constraints. The
`datePublished` in the draft metadata must be checked when publishing.

Use `serviceType` for the primary OSCAR execution mode (`exposed` or
`asynchronous`); `agentMode` describes the agent-facing lifecycle (`exposed`
or `on-demand`). The crate's RO-Crate metadata is the sole source for
`agentMode`; SOUL frontmatter must not duplicate it. `AgentSkill` identifies
a local Markdown file packaged in the crate. `agentSoul` points to exactly one
local `AgentSoul` Markdown file that is also a crate `hasPart`.
`agentSkills`, when present, lists only local `AgentSkill` Markdown files in
`hasPart`; these are the active skills. An absent property means no active
skills. Clients must not download external skills as part of this profile.

Clients supporting this profile should read only the declared local guidance,
reject missing files and paths outside the crate, and keep the exact UTF-8
contents (including trailing newlines). For multiple active skills, sort by
`@id` and join the contents with `\n\n`. Map `agentSoul` to `AGENT_SOUL` and
`agentSkills` to `AGENT_SKILLS` **only when those variables are declared in the
FDL**. Show the materialized values for editing before deployment; explicit
user overrides take precedence. Do not infer an order from JSON-LD array
positions. The `hermes-dashboard` FDL currently declares neither guidance
variable, so its `agentSoul` is descriptive and must not be injected into its
runtime implicitly.

The current CLI and dashboard do not perform this materialization; profile
metadata alone does not change deployed FDL values. Do not deploy an FDL with
unresolved guidance placeholders.
