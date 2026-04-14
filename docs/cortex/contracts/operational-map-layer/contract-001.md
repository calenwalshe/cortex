# Contract: operational-map-layer — execute

**ID:** operational-map-layer-001
**Slug:** operational-map-layer
**Phase:** execute
**Created:** 2026-04-13T19:45:00Z
**Status:** draft
**Repair Budget:** max_repair_contracts: 3, cooldown_between_repairs: 1

---

## Objective

Build the operational map layer — a PostToolUse hook, rolling edit ledger, and summary CLI — so that Cortex intelligence phases receive hotspot and co-change context before making scope decisions.

---

## Deliverables

- `scripts/cortex/operational-indexer.py` — hook and summary mode implementation
- Unit tests for both modes (fixture-based)
- `.claude/settings.json` — additive PostToolUse hook registration
- `~/.claude/skills/cortex-clarify/SKILL.md` — additive Phase 2d operational-context read step
- `~/.claude/skills/cortex-spec/SKILL.md` — additive Phase 1e operational-context read step
- `.claude/hooks/cortex-session-start.sh` — additive op-ledger staleness anchor

---

## Scope

### In Scope

- `scripts/cortex/operational-indexer.py` — new Python script
- `.cortex/edit-ledger.jsonl` — new rolling ledger file
- PostToolUse hook registration in `.claude/settings.json` (async: true, additive)
- Operational-context injection step in `~/.claude/skills/cortex-clarify/SKILL.md`
- Operational-context injection step in `~/.claude/skills/cortex-spec/SKILL.md`
- Op-ledger staleness anchor in `.claude/hooks/cortex-session-start.sh`

### Out of Scope

- Modifications to `~/.claude/skills/cortex-research/SKILL.md`
- Modifications to `dirty-files.json`, `token-ledger.db`, or `token-ledger.js`
- Stop, TaskCompleted, PreToolUse hooks
- Git log-based co-change analysis
- Cross-session analysis beyond the 500-entry rolling window
- Multi-project ledger tracking

---

## Write Roots

- `scripts/cortex/operational-indexer.py`
- `.cortex/edit-ledger.jsonl`
- `.claude/settings.json`
- `~/.claude/skills/cortex-clarify/SKILL.md`
- `~/.claude/skills/cortex-spec/SKILL.md`
- `.claude/hooks/cortex-session-start.sh`
- `test/test_operational_indexer.py` (or equivalent test file path)

---

## Done Criteria

- [ ] AC1: Edit/Write call appends one JSONL entry to `.cortex/edit-ledger.jsonl` with `{timestamp, session_id, file_path, tool_name, slug}`
- [ ] AC2: Bash, Read, Glob, Grep calls do not produce ledger entries
- [ ] AC3: Hook exits 0 when given a valid PostToolUse JSON payload (exit code confirmed mechanically)
- [ ] AC4: Writing 502 entries to ledger results in exactly 500 entries (oldest 2 dropped)
- [ ] AC5: `python3 scripts/cortex/operational-indexer.py --summary` outputs valid JSON with `hotspots` and `co_change_pairs` fields
- [ ] AC6: `--summary` filters out files with `edit_count < 2`; threshold overridable via `--min-count N`
- [ ] AC7: `grep -c "operational-indexer\|edit-ledger" ~/.claude/skills/cortex-clarify/SKILL.md` returns ≥ 1; soft-fail test passes (rename ledger, run clarify, confirm completion without error)
- [ ] AC8: `grep -c "operational-indexer\|edit-ledger" ~/.claude/skills/cortex-spec/SKILL.md` returns ≥ 1; soft-fail test passes
- [ ] AC9: `grep -c "OP-LEDGER" .claude/hooks/cortex-session-start.sh` returns ≥ 1; anchor string is ≤50 chars
- [ ] AC10: `--summary` on fixture JSONL (≥3 simulated sessions, ≥2 files in multiple sessions) produces `hotspots` entry with `edit_count ≥ 2` and `co_change_pairs` entry with `session_count ≥ 2`

---

## Validators

- [ ] [external] `echo '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/x.py"},"session_id":"test-123","cwd":"'$(pwd)'"}' | python3 scripts/cortex/operational-indexer.py --hook; echo $?` — output must be 0 AND a new line appears in `.cortex/edit-ledger.jsonl`
- [ ] [external] `echo '{"tool_name":"Bash","tool_input":{"command":"ls"},"session_id":"test-123","cwd":"'$(pwd)'"}' | python3 scripts/cortex/operational-indexer.py --hook` — line count of `.cortex/edit-ledger.jsonl` must NOT increase
- [ ] [external] `python3 -c "import json; [print(json.dumps({'timestamp':'2026-01-01T00:00:0'+str(i)+'Z','session_id':'s'+str(i%3),'file_path':'/f'+str(i%5)+'.py','tool_name':'Edit','slug':'test'})) for i in range(502)]" > /tmp/fixture.jsonl && python3 scripts/cortex/operational-indexer.py --summary --ledger /tmp/fixture.jsonl | python3 -c "import json,sys; d=json.load(sys.stdin); assert len([e for e in d['hotspots'] if e['edit_count']>=2])>0; print('AC5/AC6/AC10 pass')"` — must print "AC5/AC6/AC10 pass"
- [ ] [external] `grep -c "operational-indexer\|edit-ledger" ~/.claude/skills/cortex-clarify/SKILL.md` — must return ≥ 1
- [ ] [external] `grep -c "operational-indexer\|edit-ledger" ~/.claude/skills/cortex-spec/SKILL.md` — must return ≥ 1
- [ ] [external] `grep -c "OP-LEDGER" .claude/hooks/cortex-session-start.sh` — must return ≥ 1
- [ ] [external] `python3 -m pytest test/test_operational_indexer.py -v` — all tests pass
- [ ] [judgment] After making 3 Edits to different files, `python3 scripts/cortex/operational-indexer.py --summary` output visually shows those files in `hotspots` (or approaching threshold) — spot check that the data is sensible

---

## Eval Plan

docs/cortex/evals/operational-map-layer/eval-plan.md (pending)

---

## Approvals

- [ ] Contract approval
- [ ] Evals approval

---

## Completion Promise

CORTEX_PROMISE: operational-map-layer-001 COMPLETE

---

## Failed Approaches

(none — initial contract)

---

## Why Previous Approach Failed

N/A — initial contract

---

## Rollback Hints

- Delete `scripts/cortex/operational-indexer.py`
- Delete `.cortex/edit-ledger.jsonl`
- Remove the PostToolUse entry for `operational-indexer.py` from `.claude/settings.json`
- Revert `~/.claude/skills/cortex-clarify/SKILL.md` to remove Phase 2d operational-context step
- Revert `~/.claude/skills/cortex-spec/SKILL.md` to remove Phase 1e operational-context step
- Revert `.claude/hooks/cortex-session-start.sh` to remove op-ledger anchor block

---

## Repair Budget

**max_repair_contracts:** 3
**cooldown_between_repairs:** 1
