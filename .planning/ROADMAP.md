# Roadmap: Cortex vNext

## Overview

Cortex evolves from a layered wrapper with 5 utilities into a lifecycle intelligence system: 7 commands, hidden orchestration, contract-gated execution, a full eval subsystem, and compaction-proof continuity. Phases follow the natural delivery shape — docs first (alignment), then artifact scaffolding (substrate), then commands (capability), then agents/hooks (enforcement and automation), then evals (quality gates), then installer (operational closure). Phase 7 extends the system with the cortex-idea-stash capability (milestone v1.1).

## Phases

- [x] **Phase 1: Core Docs and Architecture Alignment** - Bring all documentation into agreement with vNext architecture before any code is written
- [x] **Phase 2: Artifact Scaffolding and Templates** - Establish the directory structure, schemas, and state file substrate that all commands write into (completed 2026-03-29)
- [x] **Phase 3: New and Updated Skills** - Implement or extend all 7 user-facing commands (completed 2026-03-29)
- [x] **Phase 4: Subagents and Hooks** - Install the enforcement and automation layer: agents, full hook bundle, continuity flow, and contract loop (completed 2026-03-29)
- [x] **Phase 5: Eval Subsystem** - Wire the eval lifecycle from research proposal through human approval to gated execution and repair (completed 2026-03-29)
- [x] **Phase 6: Installer and Operational Cleanup** - Deliver a clean, canonical installer that deploys skills, agents, and hooks with no credential debt (completed 2026-03-29)
- [x] **Phase 7: Idea Stash** - Deliver `/cortex-stash` with all six subcommands, YAML-fronted per-entry storage, staleness flagging, promote-to-clarify flow, and infrastructure for zero-friction mid-session idea capture (completed 2026-04-01)

## Phase Details

### Phase 1: Core Docs and Architecture Alignment
**Goal**: All architecture documentation reflects vNext reality — any reader understands the system without needing to read the code
**Depends on**: Nothing (first phase)
**Requirements**: DOCS-01, DOCS-02, DOCS-03, DOCS-04, DOCS-05, DOCS-06, DOCS-07
**Success Criteria** (what must be TRUE):
  1. `CORTEX.md` describes the vNext 7-command surface, artifact roots, ownership boundary, and layer architecture accurately
  2. `docs/INTELLIGENCE_FLOW.md` exists and shows the sequential clarify → research → spec → execute → validate → repair → assure → done spine with loops
  3. `docs/COMMANDS.md` documents all 7 commands with inputs, outputs, and rules — no command is undocumented
  4. `docs/CONTINUITY.md`, `docs/EVALS.md`, and `docs/AGENTS.md` exist with correct schemas and lifecycle descriptions
  5. README and source tree agree with docs — no stale references to old command names or architecture
**Research**: Unlikely (docs work only)
**Plans**: 3 plans

Plans:
- [x] 01-01-PLAN.md — Rewrite CORTEX.md (vNext architecture) + create docs/INTELLIGENCE_FLOW.md (sequential spine)
- [x] 01-02-PLAN.md — Create docs/COMMANDS.md (7-command reference) + docs/CONTINUITY.md (continuity schemas)
- [x] 01-03-PLAN.md — Create docs/EVALS.md + docs/AGENTS.md + update README.md

### Phase 2: Artifact Scaffolding and Templates
**Goal**: The `docs/cortex/` and `.cortex/` directory structures exist with correct schemas, templates, and a working state file — commands have a substrate to write into
**Depends on**: Phase 1
**Requirements**: ART-01, ART-02, ART-03, ART-04, ART-05, ART-06, ART-07, ART-08, CONT-04
**Success Criteria** (what must be TRUE):
  1. `docs/cortex/` subdirectories for clarify, research, specs, contracts, evals, investigations, reviews, and audits exist with placeholder READMEs and schema docs
  2. `.cortex/state.json` exists with the correct schema tracking mode, artifacts, approvals, and gates
  3. All 8 continuity files (`current-state.md`, `open-questions.md`, `next-prompt.md`, `decisions.md`, `eval-status.md`, `last-compact-summary.md`, and supporting files) have documented schemas with field definitions
  4. Template files exist for each artifact type (clarify brief, research dossier, spec, GSD handoff, contract, eval proposal, eval plan)
**Research**: Unlikely (schema design only)
**Plans**: 4 plans

Plans:
- [x] 02-01-PLAN.md — Create docs/cortex/ subdirectory READMEs (9 dirs: clarify, research, specs, contracts, evals, investigations, reviews, audits, handoffs)
- [ ] 02-02-PLAN.md — Create templates/cortex/ artifact templates (7 files: clarify-brief, research-dossier, spec, gsd-handoff, contract, eval-proposal, eval-plan)
- [ ] 02-03-PLAN.md — Create templates/cortex/ continuity templates + seed docs/cortex/handoffs/ + .cortex/ state files (ART-08, CONT-04)
- [ ] 02-04-PLAN.md — Write scripts/cortex/scaffold_runtime.sh (idempotent bootstrap script)

### Phase 3: New and Updated Skills
**Goal**: All 7 `/cortex-*` commands are installed, callable, and produce the correct artifacts when invoked
**Depends on**: Phase 2
**Requirements**: CMD-01, CMD-02, CMD-03, CMD-04, CMD-05, CMD-06, CMD-07
**Success Criteria** (what must be TRUE):
  1. `/cortex-clarify <idea>` writes a clarify brief to `docs/cortex/clarify/<slug>/` with all required sections (goal, non-goals, constraints, assumptions, open questions, next research steps)
  2. `/cortex-research` supports `--phase concept|implementation|evals` and `--depth quick|standard|deep` flags and writes a dossier to `docs/cortex/research/<slug>/`
  3. `/cortex-spec` produces a `spec.md` and `gsd-handoff.md` in `docs/cortex/specs/<slug>/` with all required schema fields populated
  4. `/cortex-investigate`, `/cortex-review`, and `/cortex-audit` write their artifacts to the correct `docs/cortex/` subdirectories
  5. `/cortex-status` reconstructs current state from repo-local artifacts and outputs an accurate continuity summary
**Research**: Likely (command design, flag parsing, artifact writing patterns)
**Research topics**: Existing skill file conventions, flag parsing approaches used in current cortex skills, handoff pack schema precedents
**Plans**: 3 plans

Plans:
- [x] 03-01-PLAN.md — Create cortex-clarify (new) + update cortex-research (new flags, new output paths)
- [x] 03-02-PLAN.md — Create cortex-spec (new) + replace cortex-status (continuity reconstruction)
- [x] 03-03-PLAN.md — Extend cortex-investigate + cortex-review + cortex-audit with artifact writing

### Phase 4: Subagents and Hooks
**Goal**: The enforcement and automation layer is live — agents, the full 10-hook bundle, continuity plumbing, and the contract loop all operate correctly
**Depends on**: Phase 3
**Requirements**: AGNT-01, AGNT-02, AGNT-03, AGNT-04, HOOK-01, HOOK-02, HOOK-03, HOOK-04, HOOK-05, HOOK-06, HOOK-07, HOOK-08, HOOK-09, HOOK-10, CONT-01, CONT-02, CONT-03, LOOP-01, LOOP-02, LOOP-03, LOOP-04
**Success Criteria** (what must be TRUE):
  1. After session start, Claude is automatically hydrated with `current-state.md` context without manual prompting
  2. Attempting to write product code outside `docs/cortex/**` or `.cortex/**` during clarify/research/spec phase is blocked by `cortex-phase-guard`
  3. No task can be marked complete when validators have not passed — `cortex-task-completed` enforces this
  4. After `/compact` or `/clear`, `/cortex-status` reconstructs full working context from `current-state.md`, `next-prompt.md`, and active contract
  5. All four agents (specifier, critic, scribe, eval-designer) are installed with correct permission modes and can be invoked
**Research**: Likely (hook event model, agent permission schema, validator runner integration)
**Research topics**: Claude hook event types and trigger conditions, agent YAML permission field options, dirty-files.json validator runner patterns
**Plans**: 4 plans

Plans:
- [x] 04-01-PLAN.md — Create cortex subagents (specifier, critic, scribe, eval-designer) with permission modes
- [x] 04-02-PLAN.md — Create cortex-write-guard.sh + settings.json TeammateIdle hook registration
- [x] 04-03-PLAN.md — Create cortex-phase-guard.sh, cortex-validator-trigger.sh, cortex-task-completed.sh, cortex-task-created.sh, cortex-teammate-idle.sh
- [x] 04-04-PLAN.md — Fix cortex-sync.sh (credential URL, stdin parsing, hard-fail) + document LOOP-01 through LOOP-04 in CONTINUITY.md

### Phase 5: Eval Subsystem
**Goal**: Evals are first-class artifacts — every active contract references an eval plan, failures produce repair recommendations, and human approval gates subjective/high-stakes decisions
**Depends on**: Phase 4
**Requirements**: EVAL-01, EVAL-02, EVAL-03, EVAL-04, EVAL-05
**Success Criteria** (what must be TRUE):
  1. `/cortex-research --phase evals` produces an eval proposal covering all 8 candidate dimensions (functional correctness, regression, integration, safety/security, performance, resilience, style, UX/taste)
  2. When an eval is subjective, high-stakes, or ambiguous, the system surfaces an explicit human approval request and blocks progression until answered
  3. Every active contract in `docs/cortex/contracts/` references a corresponding eval plan path
  4. A failed eval produces a repair recommendation or opens a new repair contract rather than silently failing
**Research**: Unlikely (internal artifact wiring)
**Plans**: 2 plans

Plans:
- [x] 05-01-PLAN.md — Add 8-dimension enumeration and Phase 3b approval gate to cortex-research (EVAL-01, EVAL-02, EVAL-05)
- [ ] 05-02-PLAN.md — Add eval_plan contract validation and repair-on-failure to cortex-review + cortex-status (EVAL-03, EVAL-04)

### Phase 6: Installer and Operational Cleanup
**Goal**: A single installer run deploys the full Cortex stack (skills, agents, hooks) from the canonical local repo path with no credential debt or dry-run failures
**Depends on**: Phase 5
**Requirements**: INST-01, INST-02, INST-03, INST-04, INST-05, INST-06
**Success Criteria** (what must be TRUE):
  1. Running the installer against a fresh environment symlinks all `cortex-*` skills into `~/.claude/skills/` with no errors
  2. Installer installs all 4 agents into `~/.claude/agents/` and wires all 10 hooks into `~/.claude/hooks/` and Claude settings
  3. `--dry-run` flag completes without requiring any clone-dependent files and outputs a clear diff of what would be installed
  4. No credential-bearing remote URLs appear anywhere in the installed git configuration
**Research**: Unlikely (extend existing install.js patterns)
**Plans**: 2 plans

Plans:
- [x] 06-01-PLAN.md — Rewrite bin/install.js: MANIFEST constant, installAgents(), installHooks(), generalized wireSettings() (9 events), dry-run table output
- [x] 06-02-PLAN.md — Create dotfiles-setup.sh wrapper + test/installer.test.sh (5 assertions: dry-run, symlinks, idempotency, settings dedup, credential audit)

### Phase 7: Idea Stash
**Goal**: Any Cortex user can capture a tangential idea mid-session in one command, store it durably outside the active slug lifecycle, and promote it into `/cortex-clarify` when ready — without ideas being lost to chat history or interrupting active work
**Depends on**: Phase 6
**Requirements**: STSH-01, STSH-02, STSH-03, STSH-04, STSH-05, STSH-06, STSH-07, STSH-08, STSH-09, STSH-10, STSH-11, STSH-12, STSH-13
**Success Criteria** (what must be TRUE):
  1. `/cortex-stash add "idea" --context "..."` creates `.cortex/stash/{id}-{label}.md` with correct YAML front matter (`id`, `captured`, `context`, `disposition` defaulting to `explore`); `/cortex-stash add` with no `--context` prompts interactively; `--no-context` bypasses the prompt
  2. `/cortex-stash list` shows all entries with id, age-in-days, first line of idea, and truncated context; entries older than 90 days are marked `[STALE]`
  3. `/cortex-stash show <id>` outputs the full entry; `/cortex-stash review` outputs all entries sorted oldest-first
  4. `/cortex-stash promote <id>` outputs a ready-to-run `/cortex-clarify "..."` invocation, removes the stash entry file, and warns that the entry has been deleted and the command must be run before `/clear`
  5. `/cortex-stash discard <id>` previews the entry and confirms before deleting; stash operations leave `.cortex/state.json` mode, slug, and approval fields unmodified
**Research**: Unlikely (filesystem skill, no external APIs)
**Plans**: 1 plan
**Status**: COMPLETE — 2026-04-01

Plans:
- [x] 07-01-PLAN.md — Write skills/cortex-stash/SKILL.md (6 subcommands), templates/cortex/stash-entry.md, worked example entry, verify installer symlink (13 STSH requirements)

### Phase 8: Discovery Loop — Design Docs and Templates
**Goal**: Write the authoritative design reference for the Cortex discovery loop and the two new artifact templates it introduces, so all subsequent implementation phases have a concrete schema to implement against
**Depends on**: Phase 7
**Requirements**: DISC-01, DISC-02, DISC-03
**Contract**: docs/cortex/contracts/cortex-discovery-loop/contract-001.md
**Success Criteria** (what must be TRUE):
  1. `docs/DISCOVERY_LOOP.md` exists covering all 6 sections: mode transitions, artifact schemas, uncertainty register schema, spec-readiness gate definition, write-root policy, convergence guardrails
  2. `templates/cortex/learning-contract.md` exists with all 12 HDD/Lean Startup/Shape Up fields
  3. `templates/cortex/experiment-result.md` exists with outcome, validated learning, decision (promote/iterate/re-clarify/abandon), rationale, next steps fields
**Research**: Unlikely (design synthesis from approved spec and research dossier)
**Plans**: 1 plan
**Status**: COMPLETE — 2026-04-01

Plans:
- [x] 08-01-PLAN.md — Write docs/DISCOVERY_LOOP.md (6-section design reference), templates/cortex/learning-contract.md (12-field template), templates/cortex/experiment-result.md (8-field close artifact) (DISC-01, DISC-02, DISC-03)

### Phase 9: Discovery Loop — Infrastructure Patches
**Goal**: Patch state.json schema, scaffold script, and phase guard so the experiment mode has a permitted write root and the state machine has the fields it needs
**Depends on**: Phase 8
**Requirements**: DISC-04, DISC-05, DISC-06
**Contract**: docs/cortex/contracts/cortex-discovery-loop/contract-001.md
**Success Criteria** (what must be TRUE):
  1. `docs/cortex/handoffs/open-questions.md` documents the structured uncertainty register schema (type/severity/resolution_path/status/resolved_by fields)
  2. `scripts/cortex/scaffold_runtime.sh` contains `experiments` in DOCS_SUBDIRS
  3. `.claude/hooks/cortex-phase-guard.sh` permits writes to `docs/cortex/experiments/`; product-path guard remains intact
**Research**: Unlikely (one-line patches with known locations from audit)
**Plans**: 1 plan
**Status**: COMPLETE — 2026-04-01

Plans:
- [x] 09-01-PLAN.md — Patch REQUIREMENTS.md (DISC-04/05/06), scaffold_runtime.sh (experiments DOCS_SUBDIRS), cortex-phase-guard.sh (EXPERIMENTS_ROOT), open-questions.md (uncertainty register schema) (DISC-04, DISC-05, DISC-06)

### Phase 10: Discovery Loop — /cortex-experiment Skill
**Goal**: Deliver the 8th Cortex command with open/run/close lifecycle, learning-contract and result artifacts, and correct state transitions
**Depends on**: Phase 9
**Requirements**: DISC-07
**Contract**: docs/cortex/contracts/cortex-discovery-loop/contract-001.md
**Success Criteria** (what must be TRUE):
  1. `skills/cortex-experiment/SKILL.md` exists and documents open/run/close lifecycle, artifact write paths (`docs/cortex/experiments/{slug}/`), state.json write behavior (mode: experiment, experiment_complete gate), and all four decision rule outcomes (promote/iterate/re-clarify/abandon)
**Research**: Unlikely (implements spec design; no external APIs)
**Plans**: 1
**Status**: COMPLETE — 2026-04-01

Plans:
- [x] 10-01-PLAN.md — Define DISC-07 in REQUIREMENTS.md; write skills/cortex-experiment/SKILL.md with full open/run/close lifecycle (DISC-07)

### Phase 11: Discovery Loop — Update Existing Skills and Docs
**Goal**: Update /cortex-research, /cortex-spec, CORTEX.md, INTELLIGENCE_FLOW.md, and COMMANDS.md to reflect the discovery loop model, tighten the spec gate, and document the 8-command surface
**Depends on**: Phase 10
**Requirements**: DISC-08, DISC-09, DISC-10, DISC-11, DISC-12
**Contract**: docs/cortex/contracts/cortex-discovery-loop/contract-001.md
**Success Criteria** (what must be TRUE):
  1. `skills/cortex-research/SKILL.md` sets `reclarify_required: true` in state.json when evidence changes the frame, with visible warning in output
  2. `skills/cortex-spec/SKILL.md` blocks when `reclarify_required: true`, any critical uncertainty is open, or core assumptions lack evidence backing
  3. `CORTEX.md` references "8-command surface" and includes `/cortex-experiment`
  4. `docs/INTELLIGENCE_FLOW.md` shows discovery loop with backtracking paths; does not describe pre-spec spine as strictly linear
  5. `docs/COMMANDS.md` contains a `/cortex-experiment` entry with lifecycle actions, artifact paths, and state transitions
  6. All existing clarify briefs, research dossiers, specs, and execution contracts remain valid without modification
**Research**: Unlikely (targeted edits to known files)
**Plans**: TBD (11-01 complete)

Plans:
- [x] 11-01-PLAN.md — Add reclarify_required write + warning to cortex-research/SKILL.md; add three spec-readiness blockers to cortex-spec/SKILL.md Phase 1 (DISC-08, DISC-09)

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Core Docs and Architecture Alignment | 3/3 | Complete    | 2026-03-29 |
| 2. Artifact Scaffolding and Templates | 0/4 | Complete    | 2026-03-29 |
| 3. New and Updated Skills | 0/3 | Complete    | 2026-03-29 |
| 4. Subagents and Hooks | 4/4 | Complete    | 2026-03-29 |
| 5. Eval Subsystem | 2/2 | Complete    | 2026-03-29 |
| 6. Installer and Operational Cleanup | 2/2 | Complete    | 2026-03-29 |
| 7. Idea Stash | 1/1 | Complete    | 2026-04-01 |
| 8. Discovery Loop — Design Docs and Templates | 1/1 | Complete    | 2026-04-01 |
| 9. Discovery Loop — Infrastructure Patches | 1/1 | Complete    | 2026-04-01 |
| 10. Discovery Loop — /cortex-experiment Skill | 1/1 | Complete    | 2026-04-01 |
| 11. Discovery Loop — Update Existing Skills and Docs | 1/? | In progress | - |
