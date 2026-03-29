# Roadmap: Cortex vNext

## Overview

Cortex evolves from a layered wrapper with 5 utilities into a lifecycle intelligence system: 7 commands, hidden orchestration, contract-gated execution, a full eval subsystem, and compaction-proof continuity. Phases follow the natural delivery shape — docs first (alignment), then artifact scaffolding (substrate), then commands (capability), then agents/hooks (enforcement and automation), then evals (quality gates), then installer (operational closure).

## Phases

- [x] **Phase 1: Core Docs and Architecture Alignment** - Bring all documentation into agreement with vNext architecture before any code is written
- [x] **Phase 2: Artifact Scaffolding and Templates** - Establish the directory structure, schemas, and state file substrate that all commands write into (completed 2026-03-29)
- [x] **Phase 3: New and Updated Skills** - Implement or extend all 7 user-facing commands (completed 2026-03-29)
- [x] **Phase 4: Subagents and Hooks** - Install the enforcement and automation layer: agents, full hook bundle, continuity flow, and contract loop (completed 2026-03-29)
- [ ] **Phase 5: Eval Subsystem** - Wire the eval lifecycle from research proposal through human approval to gated execution and repair
- [ ] **Phase 6: Installer and Operational Cleanup** - Deliver a clean, canonical installer that deploys skills, agents, and hooks with no credential debt

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
**Plans**: TBD

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
**Plans**: TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Core Docs and Architecture Alignment | 3/3 | Complete    | 2026-03-29 |
| 2. Artifact Scaffolding and Templates | 0/4 | Complete    | 2026-03-29 |
| 3. New and Updated Skills | 0/3 | Complete    | 2026-03-29 |
| 4. Subagents and Hooks | 4/4 | Complete    | 2026-03-29 |
| 5. Eval Subsystem | 0/TBD | Not started | - |
| 6. Installer and Operational Cleanup | 0/TBD | Not started | - |
