# Roadmap: operational-map-layer — Operational Map Layer

## Overview

Build the operational map layer — a PostToolUse hook, rolling edit ledger, and summary CLI — so that Cortex intelligence phases receive hotspot and co-change context before making scope decisions.

## Phases

### Phase 1: Core Script and Hook Registration

**Goal**: Implement `scripts/cortex/operational-indexer.py` with `--hook` and `--summary` modes, write unit tests, and register the async PostToolUse hook in `.claude/settings.json`
**Depends on**: Nothing
**Requirements**: REQ-OML-1, REQ-OML-2, REQ-OML-3, REQ-OML-4, REQ-OML-5, REQ-OML-6
**Success Criteria** (what must be TRUE):
  1. AC1: Edit/Write call appends one JSONL entry to `.cortex/edit-ledger.jsonl` with `{timestamp, session_id, file_path, tool_name, slug}`
  2. AC2: Bash, Read, Glob, Grep calls do not produce ledger entries
  3. AC3: Hook exits 0 when given a valid PostToolUse JSON payload (exit code confirmed mechanically)
  4. AC4: Writing 502 entries to ledger results in exactly 500 entries (oldest 2 dropped)
  5. AC5: `python3 scripts/cortex/operational-indexer.py --summary` outputs valid JSON with `hotspots` and `co_change_pairs` fields
  6. AC6: `--summary` filters out files with `edit_count < 2`; threshold overridable via `--min-count N`
  10. AC10: `--summary` on fixture JSONL (≥3 simulated sessions, ≥2 files in multiple sessions) produces `hotspots` entry with `edit_count ≥ 2` and `co_change_pairs` entry with `session_count ≥ 2`
**Research**: Unlikely
**Plans**: 3 plans ✓ COMPLETE

### Phase 2: Skill Integration and Session-Start Anchor

**Goal**: Inject operational-context read steps into `~/.claude/skills/cortex-clarify/SKILL.md` and `~/.claude/skills/cortex-spec/SKILL.md`, add OP-LEDGER staleness anchor to `.claude/hooks/cortex-session-start.sh`, and verify soft-fail behavior
**Depends on**: Phase 1: Core Script and Hook Registration
**Requirements**: REQ-OML-7, REQ-OML-8
**Success Criteria** (what must be TRUE):
  7. AC7: `grep -c "operational-indexer\|edit-ledger" ~/.claude/skills/cortex-clarify/SKILL.md` returns ≥ 1; soft-fail test passes (rename ledger, run clarify, confirm completion without error)
  8. AC8: `grep -c "operational-indexer\|edit-ledger" ~/.claude/skills/cortex-spec/SKILL.md` returns ≥ 1; soft-fail test passes
  9. AC9: `grep -c "OP-LEDGER" .claude/hooks/cortex-session-start.sh` returns ≥ 1; anchor string is ≤50 chars
**Research**: Unlikely
**Plans**: 0 plans

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| Phase 1: Core Script and Hook Registration | 3/3 | ✓ Complete | 2026-04-14 |
| Phase 2: Skill Integration and Session-Start Anchor | 0/0 | Not started | - |
