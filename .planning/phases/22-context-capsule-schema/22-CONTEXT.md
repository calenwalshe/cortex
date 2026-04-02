# Phase 22: Context Capsule and Result Schema - Context

**Gathered:** 2026-04-02
**Status:** Ready for planning
**Source:** Auto-populated from Cortex artifacts via /cortex-bridge

<domain>
## Phase Boundary

Create templates/cortex/task-capsule.md and schemas/task-result.schema.json. The capsule is piped to Codex via stdin. The schema constrains Codex's final response via --output-schema.

</domain>

<decisions>
## Implementation Decisions

- Capsule sections: Identity, Task Definition, Deviation Rules, Commit Instructions, File Context, Result Format
- File context: include existing files truncated to 200 lines, 12KB cap, omit if total exceeds limit
- Size budget: ~1KB overhead + ~1-3KB task + ~0-12KB file context = under 16KB
- Result schema fields: status (complete/failed/checkpoint), files_changed, tests_passed, test_output_summary, deviations, commit_hash, error_message, checkpoint_detail
- Deviation rules 1-3 (bug, missing critical, blocking) are auto-permitted; Rule 4 (architectural) triggers checkpoint status

### Claude's Discretion

- Exact markdown formatting of the capsule template
- Whether to include example JSON in the capsule's "Result Format" section
- File content truncation strategy (first N lines vs relevant sections)

</decisions>

<canonical_refs>
## Canonical References

- docs/cortex/specs/token-efficiency/spec.md
- docs/cortex/contracts/token-efficiency/contract-001.md
- docs/cortex/research/token-efficiency/implementation-20260402T225932Z.md (Sections 2-3: Capsule + Schema)

</canonical_refs>

<specifics>
## Specific Ideas

- Full capsule template and JSON Schema are designed in the implementation research dossier
- commit_hash pattern: ^[a-f0-9]{7,12}$
- test_output_summary maxLength: 500 chars
- additionalProperties: false on the schema

</specifics>

<deferred>
## Deferred Ideas

- Binary capsule serialization for efficiency
- Capsule versioning for schema evolution
- Capsule validation tooling

</deferred>

---

*Phase: 22-context-capsule-schema*
*Context gathered: 2026-04-02 via /cortex-bridge*
