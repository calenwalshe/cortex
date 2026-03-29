---
phase: 4
plan: 04-04
subsystem: hooks
tags: [hooks, continuity, cortex-sync, loop-enforcement]
dependency_graph:
  requires: [04-01, 04-02, 04-03]
  provides: [HOOK-10, LOOP-01, LOOP-02, LOOP-03, LOOP-04, CONT-01, CONT-02, CONT-03]
  affects: [docs/CONTINUITY.md, .claude/hooks/cortex-sync.sh, hooks/cortex-sync.sh]
tech_stack:
  added: []
  patterns: [soft-fail hooks, stdin-safe hook pattern, skill-layer loop enforcement]
key_files:
  created:
    - .claude/hooks/cortex-sync.sh
  modified:
    - hooks/cortex-sync.sh
    - docs/CONTINUITY.md
decisions:
  - "cortex-sync uses canonical local path ($HOME/projects/cortex) — no credential URL ever in hook scripts"
  - "LOOP-02 is skill-layer behavior (not a hook) — hooks are file-readers, skills are decision-makers"
  - "stdin captured via INPUT=$(cat) before any jq pipe to prevent pipe exhaustion"
  - "set -e removed from cortex-sync — per-command || exit 0 pattern used throughout"
metrics:
  duration: "4 minutes"
  completed: "2026-03-29T15:04:32Z"
  tasks_completed: 2
  files_modified: 3
---

# Phase 4 Plan 04: cortex-sync Fix + Continuity Wiring Summary

Fixed cortex-sync.sh (three confirmed bugs) and documented all four contract loop enforcement mechanisms in CONTINUITY.md, closing LOOP-01 through LOOP-04 and completing CONT-03.

## Tasks Completed

| Task | Description | Commit |
|------|-------------|--------|
| T1 | Fix cortex-sync.sh (credential URL, stdin parsing, hard-fail posture) | a03f806 |
| T2 | Document contract loop enforcement in CONTINUITY.md (LOOP-01–LOOP-04) | 9354a04 |

## What Was Built

### T1: cortex-sync.sh Bug Fixes

Three confirmed bugs resolved in `hooks/cortex-sync.sh`, copied to `.claude/hooks/cortex-sync.sh`:

1. **Credential URL removed** — `CORTEX_REMOTE="https://calenwalshe:${GH_TOKEN}@github.com/..."` replaced with `CORTEX_REPO_DIR="$HOME/projects/cortex"` (canonical local path).

2. **Stdin capture added** — `INPUT=$(cat)` now stored before any jq call. All jq reads use `echo "$INPUT" | jq ...` pattern.

3. **Hard-fail posture fixed** — `set -euo pipefail` changed to `set -uo pipefail`. Per-command `|| exit 0` or `|| true` on all git/cp/mkdir calls.

Additional cleanups: removed `git clone`, `git remote set-url`, `git config user.*` calls (all unnecessary for local-repo-only operation). Push gated on remote URL not containing `@`.

### T2: Contract Loop Enforcement Documentation

Appended "Contract Loop Enforcement (Phase 4)" section to `docs/CONTINUITY.md` documenting all four loop requirements:

- **LOOP-01** — `cortex-task-completed.sh` reads `eval-status.md` for FAIL entries; blocks with `continue: false` if any exist
- **LOOP-02** — Skill-layer behavior: `/cortex-review` and `/cortex-investigate` write repair contracts and transition `state.json` to `mode: repair`
- **LOOP-03** — `cortex-validator-trigger.sh` appends to `dirty-files.json` after each Write|Edit; skills update `current-state.md` per iteration
- **LOOP-04** — State machine (`clarify → research → spec → execute → validate → [pass|fail]`) enforced via `mode` field in `.cortex/state.json` + `cortex-phase-guard.sh`

Verified `docs/cortex/handoffs/next-prompt.md` exists with content (CONT-03 satisfied).

## Verification Results

All 16 checks passed:
- cortex-sync: no credential URL, INPUT=$(cat) present, no set -euo, local path present, executable
- source copy clean
- CONTINUITY.md has LOOP-01 through LOOP-04
- next-prompt.md non-empty
- All 9 hook scripts present in .claude/hooks/
- settings.json valid JSON

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check

- `/home/agent/projects/cortex/.claude/hooks/cortex-sync.sh` — exists
- `/home/agent/projects/cortex/hooks/cortex-sync.sh` — exists (fixed in place)
- `/home/agent/projects/cortex/docs/CONTINUITY.md` — LOOP-01 through LOOP-04 section appended
- Commits a03f806 and 9354a04 — verified in git log

## Self-Check: PASSED
