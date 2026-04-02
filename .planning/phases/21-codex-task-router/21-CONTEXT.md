# Phase 21: Codex Task Router - Context

**Gathered:** 2026-04-02
**Status:** Ready for planning
**Source:** Auto-populated from Cortex artifacts via /cortex-bridge

<domain>
## Phase Boundary

Create scripts/cortex/task-router.js with a 9-rule static decision tree. Input: PLAN.md task XML. Output: per-task classification (codex-safe vs claude-required).

</domain>

<decisions>
## Implementation Decisions

9-rule decision tree (first match wins):
1. Plan has `autonomous: false` → ALL claude-required
2. Task type is `checkpoint:*` → claude-required
3. Action references auth patterns → claude-required
4. File count > 8 → claude-required
5. Acceptance criteria has subjective language → claude-required
6. Action references architectural changes → claude-required
7. Task is `type="auto"` with `tdd="true"` → codex-safe
8. Task is `type="auto"` with automated `<verify>` → codex-safe
9. Task is `type="auto"` but no automated verify → claude-required
10. Fallback → claude-required (conservative)

- Classification logged to stdout for traceability
- Failed Codex tasks become claude-required on retry (no re-routing)

### Claude's Discretion

- XML parsing approach (regex vs proper XML parser)
- Output format (JSON array vs JSONL vs human-readable table)
- Pattern matching for auth/architectural keywords (exact list)

</decisions>

<canonical_refs>
## Canonical References

- docs/cortex/specs/token-efficiency/spec.md
- docs/cortex/contracts/token-efficiency/contract-001.md
- docs/cortex/research/token-efficiency/concept-codex-handoff-20260402T225257Z.md (Section C: Task Classification)
- docs/cortex/research/token-efficiency/implementation-20260402T225932Z.md (Section C: Task Router)

</canonical_refs>

<specifics>
## Specific Ideas

- Auth patterns: "login", "authenticate", "API key", "deploy", "publish"
- Architectural patterns: "new table", "schema change", "new service", "switch to", "breaking change"
- Subjective language: "looks right", "feels good", "user-friendly", "appropriate", "reasonable"

</specifics>

<deferred>
## Deferred Ideas

- Dynamic routing (AST complexity analysis, test coverage inspection)
- ML-based classification trained on execution outcomes
- Confidence scores per classification

</deferred>

---

*Phase: 21-codex-task-router*
*Context gathered: 2026-04-02 via /cortex-bridge*
