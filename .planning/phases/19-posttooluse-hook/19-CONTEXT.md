# Phase 19: PostToolUse Token Tracking Hook - Context

**Gathered:** 2026-04-02
**Status:** Ready for planning
**Source:** Auto-populated from Cortex artifacts via /cortex-bridge

<domain>
## Phase Boundary

Create ~/.claude/hooks/token-ledger.js PostToolUse hook. Register in settings.json. Tail-reads session JSONL transcript (last 8KB), extracts per-turn usage, deduplicates by message_id, computes cost, writes to ledger. Also create ~/.cortex/pricing.json.

</domain>

<decisions>
## Implementation Decisions

- Use better-sqlite3 for synchronous SQLite writes (~0.5ms vs ~50ms Python subprocess)
- Read last 8KB of transcript via fs.openSync + fs.readSync with offset (O(1) regardless of file size)
- Deduplicate via message_id stored in /tmp/ledger-last-{session_id}
- Compute cost_usd using pricing from ~/.cortex/pricing.json
- Extract phase from .planning/STATE.md at cwd
- Extract project_slug from transcript_path directory name
- Empty matcher = fires on all tool uses
- Not every PostToolUse produces a new assistant turn — message_id dedup handles this naturally

### Claude's Discretion

- Pricing.json format (flat object vs nested by provider)
- Error handling for missing better-sqlite3 (graceful skip vs Python fallback)
- Whether to log warnings when JSONL schema is unrecognized

</decisions>

<canonical_refs>
## Canonical References

- docs/cortex/specs/token-efficiency/spec.md
- docs/cortex/contracts/token-efficiency/contract-001.md
- docs/cortex/research/token-efficiency/implementation-20260402T225932Z.md (Section B: PostToolUse hook design)
- ~/.claude/hooks/gsd-context-monitor.js (existing PostToolUse hook pattern)

</canonical_refs>

<specifics>
## Specific Ideas

- Hook pseudocode is fully designed in the implementation research dossier
- Compaction detection: if remaining_pct jumps >30 points, set sessions.compacted = 1
- Session end detection: lazy — mark ended if no turn for >30 minutes

</specifics>

<deferred>
## Deferred Ideas

- Using Node 22's built-in node:sqlite instead of better-sqlite3
- Skill-level tracking (requires transcript parsing beyond tool_name)

</deferred>

---

*Phase: 19-posttooluse-hook*
*Context gathered: 2026-04-02 via /cortex-bridge*
