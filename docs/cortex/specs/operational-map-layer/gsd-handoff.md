# GSD Handoff: operational-map-layer

**Slug:** operational-map-layer
**Timestamp:** 2026-04-13T19:45:00Z
**Status:** draft

---

## Objective

Build an edit-tracking operational layer for the Cortex system map — a PostToolUse hook that appends file-edit events to a rolling JSONL ledger, a summary CLI that aggregates hotspot and co-change data, and injection steps in the clarify and spec skills — so that intelligence phases know which files are volatile and which are coupled before making scope decisions.

---

## Deliverables

- `scripts/cortex/operational-indexer.py` — new script (hook + summary modes)
- `.cortex/edit-ledger.jsonl` — new rolling ledger (created on first hook fire)
- `.claude/settings.json` — additive PostToolUse hook registration
- `~/.claude/skills/cortex-clarify/SKILL.md` — additive operational-context read step
- `~/.claude/skills/cortex-spec/SKILL.md` — additive operational-context read step
- `.claude/hooks/cortex-session-start.sh` — additive op-ledger staleness anchor

---

## Requirements

- None formalized

---

## Tasks

- [ ] Write `scripts/cortex/operational-indexer.py` — `--hook` mode: read PostToolUse stdin, extract session_id/file_path/tool_name, filter to Edit/Write, read slug from state.json, append to `.cortex/edit-ledger.jsonl`, prune to 500 entries; exits 0 always
- [ ] Write `--summary` mode in `operational-indexer.py` — reads all ledger entries, groups by session_id for co-change pairs, aggregates edit_count per file_path, applies `--min-count` filter (default 2), outputs JSON `{hotspots, co_change_pairs, entry_count, as_of, caveat}`
- [ ] Write unit tests for `--hook` (fixture payloads for Edit, Write, Bash — only Edit/Write produce entries) and `--summary` (fixture JSONL with known hotspot patterns — AC10 verifiable via fixture)
- [ ] Register PostToolUse hook in `.claude/settings.json` with `async: true` alongside structural-indexer entry
- [ ] Add Phase 2d operational-context read step to `~/.claude/skills/cortex-clarify/SKILL.md` — reads `--summary` JSON; "### Operational Context (auto-indexed):"; soft-fail if ledger absent
- [ ] Add Phase 1e operational-context read step to `~/.claude/skills/cortex-spec/SKILL.md` — same pattern; soft-fail if absent
- [ ] Add op-ledger staleness anchor to `.claude/hooks/cortex-session-start.sh` — follow structural-graph anchor pattern; format: `OP-LEDGER: {N} entries, {last-entry-date}`; ≤50 chars
- [ ] Verify AC7/AC8 soft-fail: temporarily rename `.cortex/edit-ledger.jsonl`, run clarify and spec on throwaway slugs, confirm both complete without error

---

## Acceptance Criteria

- [ ] AC1: Edit/Write call appends one entry to `.cortex/edit-ledger.jsonl` with `{timestamp, session_id, file_path, tool_name, slug}`
- [ ] AC2: Bash, Read, Glob, Grep calls do not produce ledger entries
- [ ] AC3: Hook exits 0 when given a valid PostToolUse JSON payload
- [ ] AC4: Writing 502 entries to ledger results in exactly 500 entries (oldest 2 dropped)
- [ ] AC5: `python3 scripts/cortex/operational-indexer.py --summary` outputs valid JSON with `hotspots` and `co_change_pairs` fields
- [ ] AC6: `--summary` filters out files with `edit_count < 2` (default `--min-count 2`); threshold is overridable via `--min-count N`
- [ ] AC7: `grep -c "operational-indexer\|edit-ledger" ~/.claude/skills/cortex-clarify/SKILL.md` returns ≥ 1; AND soft-fail test passes (rename ledger, run clarify, confirm completion)
- [ ] AC8: `grep -c "operational-indexer\|edit-ledger" ~/.claude/skills/cortex-spec/SKILL.md` returns ≥ 1; AND soft-fail test passes
- [ ] AC9: `grep -c "OP-LEDGER" .claude/hooks/cortex-session-start.sh` returns ≥ 1; anchor is ≤50 chars
- [ ] AC10: `--summary` on fixture JSONL (≥3 simulated sessions, ≥2 files in multiple sessions) produces `hotspots` entry with `edit_count ≥ 2` and `co_change_pairs` entry with `session_count ≥ 2`

---

## Contract Link

docs/cortex/contracts/operational-map-layer/contract-001.md
