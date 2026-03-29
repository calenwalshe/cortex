# Cortex vNext

## What This Is

Cortex is the human-on-the-loop R&D brain for GSD — a lifecycle intelligence system that turns fuzzy ideas into approved execution contracts, supports looping build/eval/repair work, and survives long sessions, compactions, `/clear`, and distributed planning. It sits above GSD (which owns workflow execution) and below the human operator, bridging the gap between vague intent and ready-to-execute plans with research, specs, contracts, evals, and continuity infrastructure.

## Core Value

A stateless executor should be able to read a Cortex handoff pack and start implementation without guessing the architecture or the definition of done.

## Requirements

### Validated

- ✓ `/cortex-investigate` — systematic debugging with Iron Law — existing
- ✓ `/cortex-review` — multi-lens code review — existing
- ✓ `/cortex-audit` — security audit (OWASP + STRIDE) — existing
- ✓ `/cortex-research` — multi-source research pipeline — existing (partial)
- ✓ `/cortex-status` — system health check — existing (partial)
- ✓ Layer architecture (Workflow=GSD, Discipline=Superpowers, Thinking=GStack) — existing
- ✓ Hook infrastructure (cortex-sync) — existing (partial)

### Active

- [ ] `/cortex-clarify` — convert fuzzy ideas into problem frames
- [ ] `/cortex-spec` — compress clarify + research into GSD-ready handoff packs and contracts
- [ ] `/cortex-research` extended with phase/depth modes (concept / implementation / evals)
- [ ] `/cortex-status` extended with continuity awareness and state reconstruction
- [ ] Contract loop — no task closes without passing validators
- [ ] Continuity subsystem — survives compaction, /clear, resume
- [ ] Phase guard hook — block product code before execute mode
- [ ] Eval subsystem — research → proposal → approval → gated execution
- [ ] Custom agent roster (specifier, critic, scribe, eval-designer)
- [ ] Full hook bundle (9 hooks covering session lifecycle + task gating)
- [ ] Artifact model — docs/cortex/ + .cortex/ runtime state
- [ ] Installer vNext — deploys skills + agents + hooks consistently
- [ ] Docs alignment — README, CORTEX.md, source tree all agree

### Out of Scope

- `/cortex-build` as a mandatory command — GSD owns build execution
- Agent teams as default backbone — opt-in only via `--team`
- Replacing GSD `.planning/`, STATE.md, milestones, roadmap state — GSD owns these
- Chat history as source of truth — repo-local artifacts only
- Global scratch directory for research artifacts — must live in target project repo

## Context

**Current baseline:** The cortex repo at `~/projects/cortex` has 5 skills (investigate, review, audit, research, status), a cortex-sync hook, layer files (discipline/thinking), upstream submodules (superpowers, gstack), agents dir, and an install.js. The layer architecture and GSD/Cortex ownership boundaries are correct and must remain intact.

**Target:** Evolve from a layered wrapper + utilities into a lifecycle intelligence system with 7 commands, hidden orchestration, contract-gated execution, eval subsystem, and compaction-proof continuity.

**Ownership contract:**
- GSD owns: `.planning/`, execution sequencing, milestones, actual build execution
- Cortex owns: clarify/research/spec/contract/eval/review/audit/investigation/continuity artifacts

**Coding boundary:** Product code edits are only allowed after a spec exists, a contract exists, execution is approved, and GSD is in execute/build mode. Before that: only `docs/cortex/**` and `.cortex/**` writes.

**Runtime artifact roots:**
- Human-readable, versionable: `docs/cortex/` (in target project repo)
- Machine/runtime scratch: `.cortex/` (in target project repo)

## Constraints

- **Surface area**: Max 7 user-facing commands — no sprawl
- **Ownership**: Cortex must never write `.planning/` or manage GSD workflow state
- **Continuity**: System must survive auto-compaction, `/compact`, `/clear`, and multi-session resume
- **Install**: One canonical local repo path; no credential-bearing URLs in git config
- **Evals**: First-class artifacts — "done" means contract passes validators, not just code written

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| GSD remains workflow owner | Prevents dual-planner conflict; clear ownership boundaries | — Pending |
| Runtime artifacts in target project repo | Makes research/specs versionable and project-local, not in global scratch | — Pending |
| `/cortex-spec` does not auto-invoke GSD import | Keeps the import step explicit and human-reviewed | — Pending |
| Agent teams opt-in via `--team` only | Avoids complexity for ordinary work | — Pending |
| High-risk eval approval always requires human | Safety gate for subjective/security/cost-sensitive work | — Pending |
| Custom agents installed globally, project memory scoped | Framework global; runtime learnings project-local | — Pending |

---
*Last updated: 2026-03-29 after initialization*
