# Phase 2: Skill Read Integration - Context

**Gathered:** 2026-04-20
**Status:** Ready for planning
**Source:** Auto-populated from Cortex artifacts via /cortex-bridge

<domain>
## Phase Boundary

Wire belief queries into 3 Cortex skills (clarify, research, spec) at specific insertion points so each skill checks "what do we already know?" before operating.

</domain>

<decisions>
## Implementation Decisions

- **cortex-clarify Phase 3.5** — query prior constraints/exclusions before writing brief
- **cortex-research Phase 0.5** — query beliefs before question routing (replaces unimplemented facts.jsonl query)
- **cortex-spec Phase 1d.5** — query architecture decisions and failed approaches before synthesizing
- **Injection format** — "Known Beliefs" section in working context, max 2000 chars, compact bullets

### Claude's Discretion

- Exact wording of the skill SKILL.md phase instructions
- Whether to query by topic, by slug, or both
- How to handle zero results gracefully (skip section vs "no prior beliefs found")

</decisions>

<canonical_refs>
## Canonical References

- docs/cortex/specs/cortex-belief-memory/spec.md (Section 8, Step 3)
- docs/cortex/research/cortex-belief-memory/concept-20260420T020000Z.md (F2: insertion points)
- ~/.claude/skills/cortex-clarify/SKILL.md
- ~/.claude/skills/cortex-research/SKILL.md
- ~/.claude/skills/cortex-spec/SKILL.md

</canonical_refs>

<specifics>
## Specific Ideas

- cortex-research Phase 0 already says "Query knowledge engine" but has no implementation — this phase implements it
- Query pattern: bridge.query_beliefs(topic=slug_topic, slug=current_slug) → formatted bullet list
- Inject before the skill's main operation, not after

</specifics>

<deferred>
## Deferred Ideas

- Belief-aware question routing (skip questions whose answers are already stable beliefs)
- Automatic belief injection into agent prompts during --team research

</deferred>

---

*Phase: 02-skill-reads*
*Context gathered: 2026-04-20 via /cortex-bridge*
