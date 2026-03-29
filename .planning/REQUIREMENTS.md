# Requirements: Cortex vNext

**Defined:** 2026-03-29
**Core Value:** A stateless executor can read a Cortex handoff pack and start implementation without guessing architecture or definition of done.

## v1 Requirements

### Commands

- [ ] **CMD-01**: `/cortex-clarify` converts a fuzzy idea into a written problem frame (clarify brief) with goal, non-goals, constraints, assumptions, open questions, and next research steps
- [ ] **CMD-02**: `/cortex-research` supports three phases — `concept`, `implementation`, `evals` — with `--depth quick|standard|deep` and optional `--team` flag
- [ ] **CMD-03**: `/cortex-spec` compresses clarify + research into a GSD-ready handoff pack, spec.md, and first execution contract
- [ ] **CMD-04**: `/cortex-investigate` writes investigation artifacts to `docs/cortex/investigations/` and can hand off into GSD repair contract
- [ ] **CMD-05**: `/cortex-review` writes review artifacts to `docs/cortex/reviews/` including contract compliance lens
- [ ] **CMD-06**: `/cortex-audit` writes audit artifacts to `docs/cortex/audits/` with required lenses (auth, data, secrets, unsafe tools, input validation, deps, misuse)
- [ ] **CMD-07**: `/cortex-status` reconstructs current state from repo-local artifacts and updates continuity handoff files

### Artifacts

- [ ] **ART-01**: Clarify brief written to `docs/cortex/clarify/<slug>/<timestamp>-clarify-brief.md`
- [ ] **ART-02**: Research dossier written to `docs/cortex/research/<slug>/<phase>-<timestamp>.md`
- [ ] **ART-03**: Spec written to `docs/cortex/specs/<slug>/spec.md` with required schema (problem, scope, arch decision, interfaces, deps, risks, sequencing, tasks, acceptance criteria)
- [ ] **ART-04**: GSD handoff written to `docs/cortex/specs/<slug>/gsd-handoff.md`
- [ ] **ART-05**: Contract written to `docs/cortex/contracts/<slug>/contract-001.md` with required schema (id, slug, phase, objective, deliverables, scope, write roots, done criteria, validators, approvals, rollback hints)
- [ ] **ART-06**: Eval proposal written to `docs/cortex/evals/<slug>/eval-proposal.md`
- [ ] **ART-07**: Eval plan written to `docs/cortex/evals/<slug>/eval-plan.md` after human approval
- [ ] **ART-08**: Continuity files maintained: `current-state.md`, `open-questions.md`, `next-prompt.md`, `decisions.md`, `eval-status.md`, `last-compact-summary.md`

### Continuity

- [ ] **CONT-01**: After compaction or `/clear`, `/cortex-status` reconstructs current state from `current-state.md`, `next-prompt.md`, and active contract
- [ ] **CONT-02**: `current-state.md` schema: current slug, mode, approval status, active contract path, recent artifacts, open questions, blockers, next action
- [ ] **CONT-03**: `next-prompt.md` contains a short restart prompt a human can paste after `/clear`
- [ ] **CONT-04**: `.cortex/state.json` tracks Cortex runtime mode, artifacts, approvals, and gates (not GSD roadmap state)

### Hooks

- [ ] **HOOK-01**: `cortex-session-start` — hydrates Claude with `current-state.md` context on SessionStart
- [ ] **HOOK-02**: `cortex-phase-guard` — blocks Write/Edit outside `docs/cortex/**` and `.cortex/**` when phase is clarify/research/spec
- [ ] **HOOK-03**: `cortex-validator-trigger` — after writes in execute/repair mode, appends to dirty-files.json and invokes validator runner
- [ ] **HOOK-04**: `cortex-task-created` — rejects tasks missing objective, deliverable, validator(s), or contract link
- [ ] **HOOK-05**: `cortex-task-completed` — blocks false completion if validators didn't pass, artifact is missing, evals are stale, or done criteria unmet
- [ ] **HOOK-06**: `cortex-teammate-idle` — feeds actionable feedback to idle agent-team workers that still owe deliverables
- [ ] **HOOK-07**: `cortex-precompact` — writes snapshot to `.cortex/compaction/precompact-<timestamp>.md` and refreshes `current-state.md`
- [ ] **HOOK-08**: `cortex-postcompact` — writes compact summary to `last-compact-summary.md` and refreshes `next-prompt.md`
- [ ] **HOOK-09**: `cortex-session-end` — writes final continuity state on `/clear`, exit, or resume transitions
- [ ] **HOOK-10**: `cortex-sync` — fixed: canonical repo path, no credential URLs, correct untracked detection, soft-fail on auth unavailable

### Agents

- [ ] **AGNT-01**: `cortex-specifier` — drafts specs/contracts from research; write-restricted to docs/cortex
- [ ] **AGNT-02**: `cortex-critic` — adversarial reviewer of specs, contracts, decisions; read-only
- [ ] **AGNT-03**: `cortex-scribe` — maintains continuity artifacts; write-restricted to docs/cortex + .cortex
- [ ] **AGNT-04**: `cortex-eval-designer` — proposes eval suites, rubrics, fixtures, thresholds

### Eval Subsystem

- [ ] **EVAL-01**: `/cortex-research --phase evals` proposes eval dimensions, fixtures, rubrics, thresholds, and failure taxonomy
- [ ] **EVAL-02**: System explicitly requests human input when eval success is subjective, high-stakes, or ambiguous
- [ ] **EVAL-03**: Every active contract references its required eval plan
- [ ] **EVAL-04**: Eval failures produce repair recommendations or open a repair contract
- [ ] **EVAL-05**: Candidate eval matrix covers: functional correctness, regression, integration, safety/security, performance, resilience, style, UX/taste

### Contract Loop

- [ ] **LOOP-01**: No task closes without satisfying the contract's validator list
- [ ] **LOOP-02**: If validation fails, system produces repair recommendation or opens repair contract
- [ ] **LOOP-03**: After each loop iteration, continuity artifacts are updated
- [ ] **LOOP-04**: State transitions: clarify → research → spec → execute → validate → repair → assure → done

### Installer

- [ ] **INST-01**: Installer uses one canonical local repo path
- [ ] **INST-02**: Installer installs/symlinks all `cortex-*` skills into `~/.claude/skills/`
- [ ] **INST-03**: Installer installs Cortex agents into `~/.claude/agents/`
- [ ] **INST-04**: Installer installs hook bundle into `~/.claude/hooks/` and wires events into Claude settings
- [ ] **INST-05**: Installer supports dry run without requiring clone-dependent files
- [ ] **INST-06**: No credential-bearing remote URLs stored in git config

### Docs

- [x] **DOCS-01**: `CORTEX.md` updated to reflect vNext architecture
- [x] **DOCS-02**: `docs/INTELLIGENCE_FLOW.md` — sequential spine diagram with loops
- [x] **DOCS-03**: `docs/COMMANDS.md` — 7-command surface with inputs, outputs, rules
- [x] **DOCS-04**: `docs/CONTINUITY.md` — continuity strategy and artifact schemas
- [x] **DOCS-05**: `docs/EVALS.md` — eval lifecycle, matrix, and harness guide
- [x] **DOCS-06**: `docs/AGENTS.md` — agent roster, tools, permission modes
- [x] **DOCS-07**: README updated; source tree, docs, installer all agree

## v2 Requirements

### Extended Capabilities

- **EXT-01**: `scripts/cortex/import_to_gsd.sh` — explicit bridge from gsd-handoff.md into GSD input format
- **EXT-02**: Agent team mode for concept research and eval research (when `--team` flag provided)
- **EXT-03**: `/cortex-research <youtube-url>` via Gemini multimodal (already partially implemented)

## Out of Scope

| Feature | Reason |
|---------|--------|
| `/cortex-build` command | GSD owns execution; adding a separate build command violates ownership boundary |
| Agent teams as default backbone | Adds complexity for ordinary work; opt-in only |
| Cortex writing to `.planning/` | GSD owns all planning state; hard constraint |
| Chat history as source of truth | Continuity must survive /clear; repo-local artifacts only |
| Global research scratch dir | Research must be project-local and versionable |
| Making Cortex replace GSD | Cortex is intelligence layer; GSD is workflow owner |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DOCS-01 | Phase 1: Core Docs and Architecture Alignment | Complete |
| DOCS-02 | Phase 1: Core Docs and Architecture Alignment | Complete |
| DOCS-03 | Phase 1: Core Docs and Architecture Alignment | Complete |
| DOCS-04 | Phase 1: Core Docs and Architecture Alignment | Complete |
| DOCS-05 | Phase 1: Core Docs and Architecture Alignment | Pending |
| DOCS-06 | Phase 1: Core Docs and Architecture Alignment | Pending |
| DOCS-07 | Phase 1: Core Docs and Architecture Alignment | Pending |
| ART-01 | Phase 2: Artifact Scaffolding and Templates | Pending |
| ART-02 | Phase 2: Artifact Scaffolding and Templates | Pending |
| ART-03 | Phase 2: Artifact Scaffolding and Templates | Pending |
| ART-04 | Phase 2: Artifact Scaffolding and Templates | Pending |
| ART-05 | Phase 2: Artifact Scaffolding and Templates | Pending |
| ART-06 | Phase 2: Artifact Scaffolding and Templates | Pending |
| ART-07 | Phase 2: Artifact Scaffolding and Templates | Pending |
| ART-08 | Phase 2: Artifact Scaffolding and Templates | Pending |
| CONT-04 | Phase 2: Artifact Scaffolding and Templates | Pending |
| CMD-01 | Phase 3: New and Updated Skills | Pending |
| CMD-02 | Phase 3: New and Updated Skills | Pending |
| CMD-03 | Phase 3: New and Updated Skills | Pending |
| CMD-04 | Phase 3: New and Updated Skills | Pending |
| CMD-05 | Phase 3: New and Updated Skills | Pending |
| CMD-06 | Phase 3: New and Updated Skills | Pending |
| CMD-07 | Phase 3: New and Updated Skills | Pending |
| AGNT-01 | Phase 4: Subagents and Hooks | Pending |
| AGNT-02 | Phase 4: Subagents and Hooks | Pending |
| AGNT-03 | Phase 4: Subagents and Hooks | Pending |
| AGNT-04 | Phase 4: Subagents and Hooks | Pending |
| HOOK-01 | Phase 4: Subagents and Hooks | Pending |
| HOOK-02 | Phase 4: Subagents and Hooks | Pending |
| HOOK-03 | Phase 4: Subagents and Hooks | Pending |
| HOOK-04 | Phase 4: Subagents and Hooks | Pending |
| HOOK-05 | Phase 4: Subagents and Hooks | Pending |
| HOOK-06 | Phase 4: Subagents and Hooks | Pending |
| HOOK-07 | Phase 4: Subagents and Hooks | Pending |
| HOOK-08 | Phase 4: Subagents and Hooks | Pending |
| HOOK-09 | Phase 4: Subagents and Hooks | Pending |
| HOOK-10 | Phase 4: Subagents and Hooks | Pending |
| CONT-01 | Phase 4: Subagents and Hooks | Pending |
| CONT-02 | Phase 4: Subagents and Hooks | Pending |
| CONT-03 | Phase 4: Subagents and Hooks | Pending |
| LOOP-01 | Phase 4: Subagents and Hooks | Pending |
| LOOP-02 | Phase 4: Subagents and Hooks | Pending |
| LOOP-03 | Phase 4: Subagents and Hooks | Pending |
| LOOP-04 | Phase 4: Subagents and Hooks | Pending |
| EVAL-01 | Phase 5: Eval Subsystem | Pending |
| EVAL-02 | Phase 5: Eval Subsystem | Pending |
| EVAL-03 | Phase 5: Eval Subsystem | Pending |
| EVAL-04 | Phase 5: Eval Subsystem | Pending |
| EVAL-05 | Phase 5: Eval Subsystem | Pending |
| INST-01 | Phase 6: Installer and Operational Cleanup | Pending |
| INST-02 | Phase 6: Installer and Operational Cleanup | Pending |
| INST-03 | Phase 6: Installer and Operational Cleanup | Pending |
| INST-04 | Phase 6: Installer and Operational Cleanup | Pending |
| INST-05 | Phase 6: Installer and Operational Cleanup | Pending |
| INST-06 | Phase 6: Installer and Operational Cleanup | Pending |

**Coverage:**
- v1 requirements: 55 total
- Mapped to phases: 55
- Unmapped: 0

---
*Requirements defined: 2026-03-29*
*Last updated: 2026-03-29 — traceability updated after roadmap creation*
