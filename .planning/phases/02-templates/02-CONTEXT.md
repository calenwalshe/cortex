# Phase 2: Templates - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning
**Source:** Auto-populated from Cortex artifacts via /cortex-bridge

<domain>
## Phase Boundary

Add the new `current-understanding.md` template and document the new YAML frontmatter convention for clarify briefs. No skill changes yet — pure additive template work. Phase 2 is gated by Phase 1 passing.

</domain>

<decisions>
## Implementation Decisions

Two file changes:

1. **`templates/cortex/clarify-brief.md`** — add documentation for two optional YAML frontmatter fields: `initial_terminal_set:` (list, default = all six non-transitional terminals) and `ruled_out:` (list, default = empty). Include a worked example block referencing the iter-3 brief of *this* slug as the canonical pattern. Backward-compatible — existing briefs without these fields use the defaults.

2. **`templates/cortex/current-understanding.md`** — net-new file, ~50 lines, with sections in this order: Possible Terminals (Markdown table with columns Terminal, Status, Ruled-Out Reason, Evidence), Durable Findings, Provisional Thoughts, Open Questions, Iteration History (table with columns Iteration, Brief, Dossier, Reframe Reason). YAML frontmatter at top: `slug:`, `brief_iteration:`, `last_updated:`.

### Claude's Discretion

Exact prose for comments and section headers in the new template. The Iteration History table column ordering and the wording of the Possible Terminals "Status" enum (live | ruled-out vs alive | dead etc.) is at executor's discretion as long as it's internally consistent and matches the verbatim text in DISCOVERY_LOOP.md §7 (which Phase 4 will write).

</decisions>

<canonical_refs>
## Canonical References

- docs/cortex/specs/clarify-research-loop/spec.md (§4 Interfaces lists template paths)
- docs/cortex/specs/clarify-research-loop/gsd-handoff.md
- docs/cortex/contracts/clarify-research-loop/contract-001.md (Done Criteria 3 and 4)
- docs/cortex/clarify/clarify-research-loop/20260412T011953Z-clarify-brief.md (canonical example of `initial_terminal_set:` frontmatter)
- templates/cortex/clarify-brief.md (the file being modified)
- templates/cortex/spec.md (style reference for template structure)

</canonical_refs>

<specifics>
## Specific Ideas

The seven terminal slugs that must be enumerated somewhere in the new template (and matched against in cortex-close validation in Phase 3): `commit-to-build`, `kill-with-learning`, `decompose`, `experiment-required`, `already-exists`, `hold-on-dependency`, `reframe-and-continue`.

The first six are non-transitional (the slug ends there). The seventh (`reframe-and-continue`) is transitional — it loops back into the same slug as iteration N+1. For the Possible Terminals table in current-understanding.md, only the six non-transitional terminals appear as rows.

</specifics>

<deferred>
## Deferred Ideas

- Per-terminal artifact templates (`kill-rationale.md`, `decomposition.md`, `use-existing.md`, `hold-trigger.md`) — not in scope; deferred to follow-up slugs when first needed
- Cross-artifact frontmatter sync mechanism — manual update only for the pilot

</deferred>

---

*Phase: 02-templates*
*Context gathered: 2026-04-12 via /cortex-bridge*
