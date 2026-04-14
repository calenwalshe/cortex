# Phase 1: Core Script and Hook Registration - Context

**Gathered:** 2026-04-14
**Status:** Ready for planning
**Source:** Auto-populated from Cortex artifacts via /cortex-bridge

<domain>
## Phase Boundary

Implement `scripts/cortex/operational-indexer.py` with `--hook` and `--summary` modes, write unit tests for both modes, and register the async PostToolUse hook in `.claude/settings.json`. At the end of this phase, the ledger is being written by real tool calls and `--summary` returns valid JSON.

</domain>

<decisions>
## Implementation Decisions

### PostToolUse is the only viable capture hook

Stop fires after every agent response turn (not session end) and has no file-path payload. TaskCompleted has no file-edit data and only fires when a contract is active. PreToolUse is wrong timing. PostToolUse is the only hook with both `session_id` (confirmed: `token-ledger.js:39: const sessionId = data.session_id`) and `tool_input.file_path` in its stdin payload.

### Filter in --hook, not --summary

Filter to Edit/Write only at write time (in `--hook` mode). This keeps the ledger clean — Bash/Read/Glob/Grep events never enter the ledger, simplifying `--summary` logic.

### Prune at append time, not via cron

The 500-entry cap is enforced synchronously at the end of each `--hook` invocation: read current entries, append new entry, slice to last 500, rewrite. This keeps the ledger bounded without any scheduled job.

### JSONL schema

Each entry: `{"timestamp": "ISO8601", "session_id": "str", "file_path": "str", "tool_name": "str", "slug": "str"}`. Read slug from `.cortex/state.json` → `slug` field. Soft-fail if absent (default to empty string).

### Exit 0 always

The hook must never block tool execution. All exception paths must be wrapped in try/except that exits 0. Log warnings to stderr only.

### --summary output schema

```json
{
  "hotspots": [{"file_path": "str", "edit_count": N}],
  "co_change_pairs": [{"files": ["a", "b"], "session_count": N}],
  "entry_count": N,
  "as_of": "ISO8601",
  "caveat": "co-change pairs are session-scoped; /clear within a task will split the session and undercount coupling"
}
```

`hotspots` filtered to `edit_count >= min_count` (default 2). `co_change_pairs` derived by grouping entries by session_id and finding file pairs that co-appear.

### Claude's Discretion

- Exact arg parsing structure (argparse subcommands vs flags)
- Whether to support `--ledger <path>` override for testing (recommended for AC validators)
- Test fixture format and file location (`test/test_operational_indexer.py`)
- Internal helper functions and decomposition

</decisions>

<canonical_refs>
## Canonical References

- docs/cortex/specs/operational-map-layer/spec.md
- docs/cortex/specs/operational-map-layer/gsd-handoff.md
- docs/cortex/contracts/operational-map-layer/contract-001.md
- docs/cortex/research/operational-map-layer/concept-20260413T193000Z.md
- docs/cortex/clarify/operational-map-layer/20260413T200000Z-clarify-brief.md

</canonical_refs>

<specifics>
## Specific Ideas

- `.claude/settings.json` PostToolUse entry: `{"type": "command", "command": "python3 \"$CLAUDE_PROJECT_DIR/scripts/cortex/operational-indexer.py\" --hook", "async": true}` — alongside existing structural-indexer entry
- Checkpoint after hook registration: `tail -1 .cortex/edit-ledger.jsonl | python3 -c "import json,sys; e=json.load(sys.stdin); assert all(k in e for k in ['timestamp','session_id','file_path','tool_name','slug']); print('OK')"`
- AC validator fixture command (from contract): `python3 -c "import json; [print(json.dumps({'timestamp':'2026-01-01T00:00:0'+str(i)+'Z','session_id':'s'+str(i%3),'file_path':'/f'+str(i%5)+'.py','tool_name':'Edit','slug':'test'})) for i in range(502)]" > /tmp/fixture.jsonl && python3 scripts/cortex/operational-indexer.py --summary --ledger /tmp/fixture.jsonl | python3 -c "import json,sys; d=json.load(sys.stdin); assert len([e for e in d['hotspots'] if e['edit_count']>=2])>0; print('AC5/AC6/AC10 pass')"`

</specifics>

<deferred>
## Deferred Ideas

- Modifications to `~/.claude/skills/cortex-research/SKILL.md` (out of scope)
- Git log-based co-change analysis (out of scope)
- Cross-session analysis beyond 500-entry window (out of scope)
- Multi-project ledger tracking (out of scope)
- Hotspot threshold empirical calibration (deferred to post-deployment)

</deferred>

---

*Phase: 01-operational-map-layer*
*Context gathered: 2026-04-14 via /cortex-bridge*
