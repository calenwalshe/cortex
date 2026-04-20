# Phase 4: Promotion + Close - Context

**Gathered:** 2026-04-20
**Status:** Ready for planning
**Source:** Auto-populated from Cortex artifacts via /cortex-bridge

<domain>
## Phase Boundary

Wire promotion logic into cortex-close so that when a slug closes, durable beliefs (lessons, design rules) promote to the global scope and everything else is archived.

</domain>

<decisions>
## Implementation Decisions

- **Selective promotion** — only derived objects where type IN ('lesson', 'design_rule', 'anti_pattern', 'heuristic') AND not contradicted by global memory
- **Promotion mechanism** — change scope_type from 'project' to 'global', set scope_id=NULL
- **Never promote** — project-specific tasks, deadlines, transient implementation details, contested/rejected forms
- **6-month test** — "Would I want this retrieved as prior knowledge six months later in a different project?"
- **cortex-close Phase 5.5** — new phase after existing Phase 5 (append decisions)

### Claude's Discretion

- Whether to run a final L3 inference pass before promotion (to catch any last-minute derivations)
- Whether to log promoted beliefs to decisions.md
- Exact archive treatment of non-promoted project-scoped forms (leave in place vs mark archived)

</decisions>

<canonical_refs>
## Canonical References

- docs/cortex/specs/cortex-belief-memory/spec.md (Section 8, Step 5)
- docs/cortex/research/cortex-belief-memory/concept-20260420T020000Z.md (F4: promotion policy)
- ~/.claude/skills/cortex-close/SKILL.md

</canonical_refs>

<specifics>
## Specific Ideas

- bridge.promote_on_close(slug) → finds qualifying derived objects, changes scope, logs to inference_log
- Run l3_engine.run_inference() one final time before promotion to ensure all derivations are current

</specifics>

<deferred>
## Deferred Ideas

- Candidate-promote raw forms with 3+ scope recurrence (v2)
- utility_score with periodic decay on promoted beliefs

</deferred>

---

*Phase: 04-promotion-close*
*Context gathered: 2026-04-20 via /cortex-bridge*
