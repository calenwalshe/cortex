# Spec: operational-map-layer

**Slug:** operational-map-layer
**Timestamp:** 2026-04-13T19:35:00Z
**Status:** draft

---

## 1. Problem

Cortex intelligence phases (clarify, research, spec) make scope decisions blind to operational reality. The structural map layer surfaces symbol graphs; the distilled layer surfaces architectural intent — but neither answers: which files are edited frequently, and which files change together? Without edit-frequency and co-change data, clarify briefs under-weight volatile files, specs pick write roots without knowing which paths are coupled, and risk sections miss the highest-churn areas. The result is scope decisions informed by structure and intent but not by actual development patterns.

---

## 2. Acceptance Criteria

- [ ] AC1: Making an Edit or Write tool call causes `scripts/cortex/operational-indexer.py --hook` to append one JSONL entry to `.cortex/edit-ledger.jsonl` containing `{timestamp, session_id, file_path, tool_name, slug}` — verifiable by reading the last line of the ledger after a live Edit
- [ ] AC2: Non-edit tools (Bash, Read, Glob, Grep) do not produce ledger entries — verified by running those tools and confirming ledger line count does not increase
- [ ] AC3: The hook always exits 0 — verified by piping a valid PostToolUse payload to the script and confirming exit code 0
- [ ] AC4: When the ledger exceeds 500 entries, the oldest entries are dropped and the file is rewritten to exactly 500 entries — verified by writing 502 test entries and confirming `wc -l .cortex/edit-ledger.jsonl` returns 500
- [ ] AC5: `python3 scripts/cortex/operational-indexer.py --summary` outputs valid JSON containing `hotspots` (list of `{file_path, edit_count}`) and `co_change_pairs` (list of `{files: [a, b], session_count}`)
- [ ] AC6: `--summary` applies a noise filter: files with `edit_count < 2` do not appear in `hotspots`; the threshold is configurable via `--min-count N` (default: 2)
- [ ] AC7: `~/.claude/skills/cortex-clarify/SKILL.md` contains an operational-context read step — verifiable by: (a) `grep -c "operational-indexer\|edit-ledger" ~/.claude/skills/cortex-clarify/SKILL.md` returns ≥ 1; AND (b) temporarily renaming `.cortex/edit-ledger.jsonl` and running `/cortex-clarify` on a throwaway slug — the skill must complete without error (soft-fail confirmed)
- [ ] AC8: `~/.claude/skills/cortex-spec/SKILL.md` contains an operational-context read step — verifiable by: (a) `grep -c "operational-indexer\|edit-ledger" ~/.claude/skills/cortex-spec/SKILL.md` returns ≥ 1; AND (b) same soft-fail test: rename ledger, run `/cortex-spec`, confirm it proceeds without blocking
- [ ] AC9: `.claude/hooks/cortex-session-start.sh` emits a ≤50-char staleness anchor in its `additionalContext` output — format: `OP-LEDGER: N entries, YYYY-MM-DD`; verified by `grep -c "OP-LEDGER" <(bash .claude/hooks/cortex-session-start.sh | python3 -m json.tool)` returns 1
- [ ] AC10: `--summary` output on a ledger seeded with fixture data (≥3 simulated sessions, ≥2 files edited in multiple sessions) produces at least one entry with `edit_count ≥ 2` in `hotspots` and at least one `co_change_pair` with `session_count ≥ 2` — verifiable via unit test with fixture JSONL data; post-deployment behavior under real sessions is a monitoring concern, not an AC

> **Post-deployment validation (non-blocking):** After 5 real editing sessions, run `python3 scripts/cortex/operational-indexer.py --summary` and verify at least one file with `edit_count ≥ 2` appears. This is observational — the slug closes when AC1–AC10 pass, not when production data accumulates.

---

## 3. Scope

### In Scope

- `scripts/cortex/operational-indexer.py` — new script with `--hook` (capture) and `--summary` (aggregate) modes
- `.cortex/edit-ledger.jsonl` — new rolling ledger file; created on first hook fire
- PostToolUse hook registration in `.claude/settings.json` (async, alongside structural-indexer entry)
- Injection step in `~/.claude/skills/cortex-clarify/SKILL.md` — reads operational context before brief population *(global skill file — intentional: matches structural-map-layer pattern; skills are global by design in this environment; mutation is additive-only)*
- Injection step in `~/.claude/skills/cortex-spec/SKILL.md` — reads operational context before spec synthesis *(same pattern; additive-only)*
- Staleness anchor in `.claude/hooks/cortex-session-start.sh` — ≤50-char "OP-LEDGER: N entries, YYYY-MM-DD" pointer

### Out of Scope

- Injection into `~/.claude/skills/cortex-research/SKILL.md` — research questions are pre-classified; operational context is less relevant to question routing than to scope decisions
- Stop, TaskCompleted, PreToolUse hooks — PostToolUse is the only hook with both session_id and file_path in payload
- Git log-based co-change analysis — explicitly excluded by clarify brief non-goals
- Modifications to `dirty-files.json`, `token-ledger.db`, or `token-ledger.js` — operational indexer is fully additive
- `dirty-files.json` mode-gating — operational ledger captures all modes (clarify, research, spec, execute)
- Cross-session analysis beyond the 500-entry rolling window
- Multi-project ledger tracking
- Hotspot threshold empirical calibration — deferred to AC10 live validation

---

## 4. Architecture Decision

**Chosen approach:** PostToolUse async hook (`operational-indexer.py --hook`) captures Edit/Write events to `.cortex/edit-ledger.jsonl`. The `--summary` mode aggregates hotspot counts and co-change pairs for per-skill inline reads. Session_id from the PostToolUse payload is the co-change grouping key.

**Rationale:** PostToolUse is the only existing hook event delivering both `session_id` and `tool_input.file_path` in its stdin payload (confirmed: `token-ledger.js:39 const sessionId = data.session_id`). JSONL append matches the established `facts.jsonl` pattern. Per-skill inline reads bypass the 1,604-char additionalContext worst-case budget constraint (proven pattern from structural-map-layer and system-map-memory). The `async: true` flag ensures the hook never adds latency to tool execution.

### Alternatives Considered

- **Stop hook as co-change grouping boundary:** Fires after every agent response turn, not at session termination; carries no file-path payload; produces hundreds of meaningless 1-3 file "sessions" — rejected
- **TaskCompleted hook for co-change grouping:** No file-edit data in payload; fires only when a contract is active; misses all intelligence-phase edits — rejected
- **dirty-files.json as ledger seed:** Only populated in execute/repair mode; no timestamps; no session_id segmentation — rejected
- **Per-session JSON files (`.cortex/edit-ledger/{session_id}.json`):** Clean pruning but directory proliferation (17 sessions already in 10 days); more complex read path (list dir + merge) with no meaningful benefit at current velocity — rejected
- **SessionStart additionalContext injection:** 1,604-char worst-case budget headroom would require truncation; per-skill inline reads use the 200K context window instead — rejected for delivery channel

---

## 5. Interfaces

- **`scripts/cortex/operational-indexer.py`** — new file; written by this spec; CLI modes: `--hook` (reads PostToolUse stdin, appends to ledger, prunes); `--summary [--min-count N] [--top-files N] [--top-pairs N]` (reads ledger, outputs JSON); exits 0 always
- **`.cortex/edit-ledger.jsonl`** — new file; written by `--hook` mode; read by `--summary` mode and skill injection steps; schema: one JSON object per line, fields: `{timestamp: ISO8601, session_id: str, file_path: str, tool_name: str, slug: str}`
- **`.claude/settings.json`** — existing file; this spec adds one PostToolUse entry: `{"type": "command", "command": "python3 \"$CLAUDE_PROJECT_DIR/scripts/cortex/operational-indexer.py\" --hook", "async": true}`
- **`~/.claude/skills/cortex-clarify/SKILL.md`** — existing file; this spec adds an operational-context read step (Phase 2d) before brief population; soft-fail if ledger absent
- **`~/.claude/skills/cortex-spec/SKILL.md`** — existing file; this spec adds an operational-context read step (Phase 1e) before spec synthesis; soft-fail if ledger absent
- **`.claude/hooks/cortex-session-start.sh`** — existing file; this spec adds an op-ledger staleness anchor block; pattern follows the existing structural-graph anchor (lines 84–93)

---

## 6. Dependencies

- **Python `json`, `os`, `datetime`, `collections`, `argparse` modules** — stdlib; no pip dependencies; confirmed available in this environment
- **`.cortex/state.json`** — read by `--hook` mode to extract the current `slug` field for ledger tagging; soft-fail if absent (slug defaults to empty string)
- **`structural-map-layer`** (shipped) — operational layer follows the same PostToolUse hook pattern; both are registered as separate async PostToolUse entries in `.claude/settings.json`
- **`.claude/hooks/cortex-session-start.sh`** — must exist; modified by this spec's staleness anchor step

---

## 7. Risks

- **`tool_input.file_path` confirmed from token-ledger.js source but not from official SDK documentation** — Mitigation: hook always exits 0; test immediately after wiring with a live Edit; if field is absent, log a warning and exit 0 (never block); run `--summary` manually to verify entries are accumulating
- **`/clear` fragments session_id** — edits before and after `/clear` in the same logical task receive different session_ids and won't be co-grouped — Mitigation: the injection text delivered to intelligence phases must include the explicit caveat "co-change pairs are session-scoped; /clear within a task will split the session and undercount coupling"; the `--summary` output JSON includes a `caveat` field with this warning text so every consumer receives the signal
- **Ledger growth during high-frequency worktree sessions** — worktree agents can produce 50+ edits per session — Mitigation: 500-entry hard cap enforced at append time; at 230 bytes/entry, max ledger size is ~115KB
- **Hotspot threshold miscalibration** — default `min_count=2` may be too low (noisy) or too high (misses real hotspots) — Mitigation: threshold is configurable via `--min-count`; AC10 live validation defers the final calibration decision to observed data after 5 production sessions
- **SKILL.md injection breaks existing skill flow** — Mitigation: each operational-context read step is wrapped in a `try/soft-fail` guard in the SKILL.md text; AC7 and AC8 include an explicit soft-fail test (rename ledger, run skill, confirm completion); revert the SKILL.md edit if AC7/AC8 soft-fail tests fail

---

## 8. Sequencing

1. Write `scripts/cortex/operational-indexer.py` with `--hook` and `--summary` modes; write unit tests for both modes using fixture JSONL data — checkpoint: `python3 scripts/cortex/operational-indexer.py --summary` exits 0 with valid JSON
2. Register async PostToolUse hook in `.claude/settings.json`; make a live Edit to any file; confirm `.cortex/edit-ledger.jsonl` entry appears with correct schema — checkpoint: `tail -1 .cortex/edit-ledger.jsonl | python3 -c "import json,sys; e=json.load(sys.stdin); assert all(k in e for k in ['timestamp','session_id','file_path','tool_name','slug']); print('OK')"`
3. Add operational-context read step to `~/.claude/skills/cortex-clarify/SKILL.md`; run throwaway clarify; confirm step fires and soft-fails gracefully when ledger is absent — checkpoint: clarify runs without error; step is present in SKILL.md
4. Add operational-context read step to `~/.claude/skills/cortex-spec/SKILL.md` — checkpoint: `grep -c "edit-ledger\|op-ledger\|operational" ~/.claude/skills/cortex-spec/SKILL.md` ≥ 1
5. Add op-ledger staleness anchor to `.claude/hooks/cortex-session-start.sh` — checkpoint: hook output contains "OP-LEDGER" when ledger exists; anchor is ≤50 chars
6. Accumulate 5 real editing sessions; run `--summary` and confirm live validation AC10 passes

---

## 9. Tasks

- [ ] Write `scripts/cortex/operational-indexer.py` — `--hook` mode: read stdin JSON, extract `session_id`/`file_path`/`tool_name`, filter to Edit/Write only, read `slug` from `.cortex/state.json`, append to `.cortex/edit-ledger.jsonl`, prune to 500 entries; exits 0 always
- [ ] Write `--summary` mode in `operational-indexer.py` — read all ledger entries, group by session_id for co-change pairs, aggregate edit_count per file_path, apply `--min-count` filter (default 2), output JSON with `{hotspots, co_change_pairs, entry_count, as_of}`
- [ ] Write unit tests for `--hook` mode (fixture payloads for Edit, Write, Bash — verify only Edit/Write produce entries) and `--summary` mode (fixture JSONL with known hotspot patterns)
- [ ] Register PostToolUse hook entry in `.claude/settings.json` with `async: true` alongside structural-indexer
- [ ] Add Phase 2d operational-context read step to `~/.claude/skills/cortex-clarify/SKILL.md` — reads `operational-indexer.py --summary` output (or falls back to raw `tail -20` of ledger); presents as "### Operational Context (auto-indexed):"; soft-fail if ledger absent
- [ ] Add Phase 1e operational-context read step to `~/.claude/skills/cortex-spec/SKILL.md` — same pattern; soft-fail if absent
- [ ] Add op-ledger staleness anchor block to `.claude/hooks/cortex-session-start.sh` — follow structural-graph anchor pattern (lines 84–93); format: `OP-LEDGER: {N} entries, {last-entry-date}`
- [ ] Live validation (AC10): after 5+ real editing sessions, run `--summary` and verify at least one file has edit_count ≥ 2 and at least one co_change_pair has session_count ≥ 2
