# Phase 23: Codex Execution Wrapper - Context

**Gathered:** 2026-04-02
**Status:** Ready for planning
**Source:** Auto-populated from Cortex artifacts via /cortex-bridge

<domain>
## Phase Boundary

Create scripts/cortex/codex-exec-wrapper.sh handling the full lifecycle: worktree creation, capsule generation, Codex invocation with timeout, JSONL parsing for token usage, result validation, worktree merge on success / cleanup on failure, and token ledger write.

</domain>

<decisions>
## Implementation Decisions

- Git worktree for isolation: `git worktree add /tmp/gsd-codex-{phase}-{plan} -b codex/{phase}-{plan}`
- Invoke: `cat capsule.md | timeout ${T} codex exec --full-auto --json --output-schema schema.json -C /worktree -`
- Timeouts: TDD tasks 180s, auto <5 files 300s, auto 5-8 files 450s
- Parse JSONL post-hoc (tee to file, then process) — simpler than streaming parse
- Extract token usage from turn.completed events, sum across all turns
- Parse result JSON from last turn.completed message
- Merge on success: `git merge codex/{phase}-{plan} --no-edit`
- Cleanup: `git worktree remove --force` + `git branch -D`
- Every failure → reclassify as claude-required, no Codex retries

### Claude's Discretion

- Temp file naming convention for capsules and JSONL output
- Whether to use Python or jq for JSONL parsing
- Error message formatting for failure reports
- Whether to capture and log Codex's intermediate tool use events

</decisions>

<canonical_refs>
## Canonical References

- docs/cortex/specs/token-efficiency/spec.md
- docs/cortex/contracts/token-efficiency/contract-001.md
- docs/cortex/research/token-efficiency/implementation-20260402T225932Z.md (Section C: Execution Flow + Failure Handling)

</canonical_refs>

<specifics>
## Specific Ideas

- Full execution flow (9 steps a-i) documented in implementation research
- 6 failure modes with detection and response documented
- Parent Claude session passes session_id, phase, project_slug as env vars
- Codex pricing for ledger: o4-mini ($1.10/$4.40 per 1M in/out), o3 ($10/$40)

</specifics>

<deferred>
## Deferred Ideas

- Parallel Codex execution across tasks (worktree per task)
- Codex retry with backoff
- Streaming progress display during Codex execution

</deferred>

---

*Phase: 23-codex-execution-wrapper*
*Context gathered: 2026-04-02 via /cortex-bridge*
