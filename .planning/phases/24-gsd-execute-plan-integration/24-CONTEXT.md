# Phase 24: GSD Execute-Plan Integration - Context

**Gathered:** 2026-04-02
**Status:** Ready for planning
**Source:** Auto-populated from Cortex artifacts via /cortex-bridge

<domain>
## Phase Boundary

Modify execute-plan.md to add task classification step (4.5) and Codex execution step (5a) before Claude executor spawn (5b). Add codex config section to .planning/config.json schema.

</domain>

<decisions>
## Implementation Decisions

- Step 4.5 (NEW): Read plan, run task router, partition into codex_tasks[] + claude_tasks[]
- Step 5a (NEW): If codex_tasks non-empty AND Codex available: create worktree → execute via wrapper → merge results
- Step 5b (MODIFIED): Spawn Claude executor for remaining claude_tasks with `<completed_tasks>` context from 5a
- If all tasks completed by Codex: skip executor spawn, go straight to SUMMARY creation
- Config: `codex.enabled: false` disables router entirely — all tasks to Claude as today
- Config section in .planning/config.json: `enabled`, `timeout_seconds`, `max_file_count`, `fallback_on_failure`
- Drive workflow needs no changes — consumes SUMMARY.md artifacts regardless of execution model

### Claude's Discretion

- Exact XML format for `<completed_tasks>` context passed to Claude executor
- How to present mixed execution results in SUMMARY.md (Codex vs Claude sections?)
- Whether to add codex execution stats to STATE.md performance metrics

</decisions>

<canonical_refs>
## Canonical References

- docs/cortex/specs/token-efficiency/spec.md
- docs/cortex/contracts/token-efficiency/contract-001.md
- docs/cortex/research/token-efficiency/implementation-20260402T225932Z.md (Section C: Integration Point)
- upstream/gsd/commands/gsd/execute-plan.md (current Step 5)

</canonical_refs>

<specifics>
## Specific Ideas

- For execute-phase.md wave execution: 100% codex-safe plans can run in parallel (separate worktrees)
- Mixed plans: Codex first, then Claude for remainder
- 100% claude-required: unchanged from today

</specifics>

<deferred>
## Deferred Ideas

- Automatic codex.enabled based on task type distribution in plan
- Cost comparison reporting (Claude vs Codex per task type)
- Smart timeout escalation based on task complexity

</deferred>

---

*Phase: 24-gsd-execute-plan-integration*
*Context gathered: 2026-04-02 via /cortex-bridge*
