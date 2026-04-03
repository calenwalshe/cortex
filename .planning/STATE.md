---
gsd_state_version: 1.0
milestone: v1.1
milestone_name: milestone
status: token-ledger.db schema created with 4 tables, 8 indexes, WAL mode; 23/23 tests pass
stopped_at: Phase 18-01 complete — token ledger schema migration script + 23 integration tests
last_updated: "2026-04-03T02:57:06.709Z"
last_activity: 2026-04-03
progress:
  total_phases: 12
  completed_phases: 12
  total_plans: 26
  completed_plans: 26
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-01)

**Core value:** A stateless executor can read a Cortex handoff pack and start implementation without guessing architecture or definition of done.
**Current focus:** Phase 18 — Token Ledger Schema (v1.4 adaptive-autonomy)

## Current Position

Phase: 18
Plan: Not started
Status: token-ledger.db schema created with 4 tables, 8 indexes, WAL mode; 23/23 tests pass
Last activity: 2026-04-03

Progress: [█████████████████████] 27/27 plans; 13/13 phases complete

## Performance Metrics

**Velocity:**

- Total plans completed: 0
- Average duration: -
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

**Recent Trend:**

- Last 5 plans: n/a
- Trend: n/a

*Updated after each plan completion*
| Phase 01 P02 | 2 | 2 tasks | 2 files |
| Phase 01-core-docs-and-architecture-alignment P01 | 2 | 2 tasks | 2 files |
| Phase 02-artifact-scaffolding-and-templates P03 | 4 | 2 tasks | 15 files |
| Phase 02-artifact-scaffolding-and-templates P02 | 3 | 2 tasks | 7 files |
| Phase 02-artifact-scaffolding-and-templates P01 | 16min | 2 tasks | 9 files |
| Phase 02-artifact-scaffolding-and-templates P04 | 2 | 2 tasks | 1 files |
| Phase 03-new-and-updated-skills P01 | 2min | 2 tasks | 2 files |
| Phase 03-new-and-updated-skills P02 | 8min | 2 tasks | 2 files |
| Phase 03-new-and-updated-skills P03 | 18min | 3 tasks | 3 files |
| Phase 04-subagents-and-hooks P02 | 5min | 3 tasks | 5 files |
| Phase 04-subagents-and-hooks P04-01 | 26min | 3 tasks | 5 files |
| Phase 04-subagents-and-hooks P03 | 5min | 3 tasks | 6 files |
| Phase 04-subagents-and-hooks P04 | 4min | 2 tasks | 3 files |
| Phase 05-eval-subsystem P01 | 2min | 2 tasks | 1 files |
| Phase 06-installer-and-operational-cleanup P01 | 12min | 2 tasks | 1 files |
| Phase 06-installer-and-operational-cleanup P02 | 8min | 2 tasks | 2 files |
| Phase 18-token-ledger-schema P01 | 4min | 2 tasks | 2 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- GSD remains workflow owner (no dual-planner conflict)
- Runtime artifacts live in target project repo under docs/cortex/ and .cortex/
- /cortex-spec does not auto-invoke GSD import (explicit human step)
- Agent teams opt-in via --team only
- High-risk eval approval always requires human gate
- cortex-critic is strictly read-only — produces critique inline only, never writes files
- UX/taste eval dimension always requires human approval gate (hardcoded, not conditional)
- README Quick Start defers installer details to Phase 6 (npx promise removed)
- All eval artifacts live in target project repo, not cortex framework repo
- [Phase 01-core-docs-and-architecture-alignment]: 4-layer architecture: Workflow (GSD), Intelligence (Cortex), Discipline (Superpowers), Thinking (GStack)
- [Phase 01-core-docs-and-architecture-alignment]: Repair loop re-enters validate, never clarify — bounded convergence model
- [Phase 01]: Human-readable continuity files placed under docs/cortex/handoffs/ (resolves ambiguity from research)
- [Phase 01]: COMMANDS.md documents vNext interface explicitly noting SKILL.md legacy divergence — intentional until Phase 3
- [Phase 02-01]: eval_plan field is mandatory on every contract — contracts without it are incomplete and must not be approved
- [Phase 02-01]: Handoffs directory is flat (not slug-subdirectories) — 6 named files live directly in docs/cortex/handoffs/
- [Phase 02-01]: audits/README.md encodes not-applicable protocol — silence on a lens is not acceptable
- [Phase 02-artifact-scaffolding-and-templates]: Scratch .cortex/ files (runs/, tmp/, dirty-files.json, validator-results.json) excluded from git via .gitignore; durable state.json and compaction/ committed via negation rules
- [Phase 02-artifact-scaffolding-and-templates]: Continuity template placeholders use {UPPERCASE_FIELD} with lowercase schema field labels to preserve both CONTINUITY.md key names and template fill-in convention
- [Phase 02-artifact-scaffolding-and-templates]: contract.md eval_plan field marked Required with comment — contracts without it are incomplete per EVALS.md
- [Phase 02-artifact-scaffolding-and-templates]: spec.md has all 9 mandatory sections — omitting any section is an error by design
- [Phase 02-artifact-scaffolding-and-templates]: eval-proposal.md APPROVAL_REQUIRED is document-level flag — simplifies human approval flow
- [Phase 02-artifact-scaffolding-and-templates]: Idempotency guard uses [ -f dst ] pre-check, not cp -n — explicit and avoids portability warnings
- [Phase 03-new-and-updated-skills]: cortex-clarify is the mandatory gate: no research or spec without a clarify brief
- [Phase 03-new-and-updated-skills]: --phase evals branches to eval-proposal.md using a different template from research dossier
- [Phase 03-new-and-updated-skills]: Legacy cortex-research ~/research/ output path and --quick/--deep flags removed in favor of docs/cortex/ routing and --depth interface
- [Phase 03-new-and-updated-skills]: cortex-spec requires clarify brief AND research dossier — blocks with actionable error if either missing
- [Phase 03-new-and-updated-skills]: cortex-spec does NOT auto-invoke GSD; human must explicitly import gsd-handoff.md into GSD as separate step
- [Phase 03-new-and-updated-skills]: Old cortex-status system-health behavior (API keys, upstream versions, Python packages) fully retired in favor of continuity reconstruction from repo-local artifacts
- [Phase 03-03]: cortex-investigate blocks on null-slug/no-argument; cortex-review and cortex-audit fall back to "unknown" slug
- [Phase 03-03]: Contract Compliance section in cortex-review is mandatory and cannot be omitted
- [Phase 03-03]: 7-lens verification in cortex-audit enforced at write time — silence on any lens requires explicit no-issues note
- [Phase 03-03]: Repair contract in cortex-investigate is optional, gated on DONE_WITH_CONCERNS or BLOCKED status
- [Phase 04-subagents-and-hooks]: Stop hook registered async: true to avoid delaying agent responses
- [Phase 04-subagents-and-hooks]: CLAUDE_PROJECT_DIR used for all hook paths — no hardcoded machine paths
- [Phase 04-subagents-and-hooks]: python3 used for JSON construction in session-start hook to handle multiline strings without jq escaping issues
- [Phase 04-subagents-and-hooks]: Agent files live at .claude/agents/ (project-scope, checked into repo); Phase 6 installer symlinks to ~/.claude/agents/ for global use
- [Phase 04-subagents-and-hooks]: Write restriction requires both tools allowlist (tool type) AND PreToolUse hook (path enforcement) — allowlist alone is insufficient
- [Phase 04-subagents-and-hooks]: Single shared cortex-write-guard.sh dispatches by agent_name — avoids duplicating enforcement logic per agent
- [Phase 04-subagents-and-hooks P03]: phase-guard uses JSON permissionDecision deny (exit 0) not exit 2 — gives Claude an actionable reason rather than a terse failure
- [Phase 04-subagents-and-hooks P03]: validator-trigger is async PostToolUse — records dirty files only, never runs validators inline (timeout risk)
- [Phase 04-subagents-and-hooks P03]: teammate-idle uses exit 2 to signal continuation — keeps worker agents from silently completing
- [Phase 05-eval-subsystem P01]: 8-dimension enumeration is mandatory and inline — agent must decide INCLUDE/EXCLUDE for each dimension in the proposal text, not defer to human
- [Phase 05-eval-subsystem P01]: Phase 3b uses a separate --write-plan trigger, not auto-run after --phase evals — human controls when eval plan is written
- [Phase 05-eval-subsystem P01]: UX/taste hardcodes approval_required: true; Functional correctness and Style hardcode approval_required: false — not configurable per-proposal
- [Phase 06-01]: MANIFEST constant replaces readdirSync in dry-run path — installer can enumerate without repo present (fixes ENOENT crash on fresh machines)
- [Phase 06-01]: cortex-write-guard.sh is symlinked but NOT wired in settings.json — it is agent-invoked only, not a global Claude event hook
- [Phase 06-01]: All hooks use symlinkSync not copyFileSync — updates take effect immediately after git pull
- [Phase 06-01]: PostToolUse cortex-sync.sh entry preserved; cortex-validator-trigger.sh appended as separate entry — dedup check prevents duplicates on re-run
- [Phase 06-02]: dotfiles-setup.sh is intentionally minimal — 4 lines, zero logic, all delegation to bin/install.js
- [Phase 06-02]: Test HOME isolation via exported HOME=$TEST_HOME before node — works because install.js reads HOME via os.homedir()
- [Phase 06-02]: { grep ... || true; } | wc -l grouping pattern prevents set -euo pipefail abort on grep no-match
- [Phase 07-idea-stash]: Per-entry files chosen over flat file — discard/promote are atomic rm/read operations; no parser required; clean git history
- [Phase 07-idea-stash]: .cortex/stash/ location is already within phase guard permitted write root — no guard update needed
- [Phase 07-idea-stash]: disposition field defaults to explore at capture; updated only at triage — not at add time
- [Phase 07-idea-stash]: stash add prompts interactively for context if --context omitted; --no-context bypasses prompt entirely
- [Phase 08-discovery-loop]: experiment_complete gate is conditional — only checked by /cortex-spec when critical uncertainties have resolution_path: experiment; research-only slugs are unaffected
- [Phase 08-discovery-loop]: Backward-compat defaults for flat open-questions.md entries are explicit and documented inline (type: knowledge, severity: noncritical, resolution_path: research, status: open)
- [Phase 08-discovery-loop]: Appetite/Timebox is REQUIRED in learning-contract — marked in both body heading and introductory note; contract is incomplete without it
- [Phase 08-discovery-loop]: Decision outcomes are an exhaustive enum (promote | iterate | re-clarify | abandon) — documented in both templates with inline HTML comment
- [Phase 09-discovery-loop-infrastructure-patches]: experiments appended to DOCS_SUBDIRS — one-line patch, no surrounding changes
- [Phase 09-discovery-loop-infrastructure-patches]: EXPERIMENTS_ROOT follows existing CORTEX_ROOT variable pattern in cortex-phase-guard.sh
- [Phase 09-discovery-loop-infrastructure-patches]: Backward-compat defaults for flat open-questions.md entries documented inline (type: knowledge, severity: noncritical, resolution_path: research, status: open)
- [Phase 10-discovery-loop-cortex-experiment-skill]: experiment_complete: true written by close for ALL four decisions — the gate is satisfied regardless of decision taken
- [Phase 10-discovery-loop-cortex-experiment-skill]: /cortex-experiment run is read-only — no state.json writes, no artifact written; guidance-only reminder
- [Phase 18-token-ledger-schema]: Global DB at ~/.cortex/token-ledger.db — single query for cross-project totals, no .gitignore pollution
- [Phase 18-token-ledger-schema]: WAL mode enabled at creation time for concurrent hook writes
- [Phase 18-token-ledger-schema]: TOKEN_LEDGER_DB env var override for test isolation
- [Phase 18-token-ledger-schema]: bash + sqlite3 CLI for migration script (simpler than Node.js, no deps beyond sqlite3)

### Pending Todos

None.

### Blockers/Concerns

None.

## Session Continuity

Last session: 2026-04-03
Stopped at: Phase 18-01 complete — token ledger schema migration script + 23 integration tests
Resume file: None

## Drive Log

| Timestamp | Phase | Step | Result |
|-----------|-------|------|--------|
| 2026-04-01T15:54:51Z | 7 | discuss (auto-context) | complete |
| 2026-04-01T15:54:51Z | 7 | plan | complete (1 plan) |
| 2026-04-01T15:54:51Z | 7 | verify-plans | PASS |
| 2026-04-01T16:15:00Z | 7 | execute (07-01) | COMPLETE — 4 tasks, 13 STSH reqs satisfied |
| 2026-04-01T17:00:00Z | 8 | execute (08-01) | COMPLETE — 3 tasks, DISC-01/02/03 satisfied; 3 files created |
| 2026-04-01T17:30:00Z | 8 | transition | COMPLETE — Phase 8 marked complete, advancing to Phase 9 |
| 2026-04-01T18:00:00Z | 9 | execute (09-01) | COMPLETE — 4 tasks, DISC-04/05/06 satisfied; commit f53d6df |
| 2026-04-01T18:00:00Z | 9 | transition | COMPLETE — Phase 9 marked complete, advancing to Phase 10 |
| 2026-04-01T18:49:37Z | 10 | research | complete — RESEARCH.md written (subcommands, state fields, decision outcomes, artifact paths, guardrails, DISC-07 definition) |
| 2026-04-01T18:49:37Z | 10 | plan | complete (1 plan) — 10-01-PLAN.md: T1 define DISC-07, T2 write skills/cortex-experiment/SKILL.md |
| 2026-04-01T18:49:37Z | 10 | verify-plans | PASS |
| 2026-04-01T19:00:00Z | 10 | execute (10-01) | COMPLETE — 2 tasks, DISC-07 satisfied; skills/cortex-experiment/SKILL.md written |
| 2026-04-01T19:30:00Z | 10 | transition | COMPLETE — Phase 10 marked complete, advancing to Phase 11 |
