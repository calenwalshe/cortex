# Roadmap: gate-critique — Adversarial Gate Critique

## Overview

Build a standalone `/cortex-critique` skill that runs an adversarial AI review of Cortex artifacts (clarify brief, research dossier, spec) at each gate transition, so bad assumptions and poor framing are caught before they propagate downstream into expensive execution work.

## Phases

### Phase 1: Build cortex-critique skill

**Goal**: Write the standalone `skills/cortex-critique/SKILL.md` with all core mechanics — Codex CLI invocation, artifact-type routing, adversarial prompt template, three-tier severity, artifact persistence, gate receipt writer, and `human_critique` autonomy gate
**Depends on**: Nothing
**Requirements**: None formalized
**Success Criteria** (what must be TRUE):
  1. `skills/cortex-critique/SKILL.md` exists and implements the cortex-critique skill with: artifact-type routing (brief, dossier, spec, contract), Codex CLI invocation with exec mode and adversarial prompt, three-tier severity output (STOP/CAUTION/GO), and persistent critique artifact output
  2. The Codex invocation uses `codex exec --full-auto` with a prompt that explicitly frames Codex as an adversarial critic — not an assistant — before presenting the artifact to critique
  3. Running cortex-critique against a clarify brief produces `docs/cortex/reviews/{slug}/critique-clarify.md` containing: severity verdict, finding count by tier, and specific findings with artifact quotes
  4. Running cortex-critique against a research dossier produces `docs/cortex/reviews/{slug}/critique-dossier-{timestamp}.md`
  5. Running cortex-critique against a spec produces `docs/cortex/reviews/{slug}/critique-spec.md`
**Research**: Unlikely
**Plans**: 0 plans

### Phase 2: Wire critique into existing skills

**Goal**: Edit cortex-clarify, cortex-research, and cortex-spec to invoke cortex-critique at the correct gate transition point in each skill
**Depends on**: Phase 1: Build cortex-critique skill
**Requirements**: None formalized
**Success Criteria** (what must be TRUE):
  1. `skills/cortex-clarify/SKILL.md` invokes cortex-critique after writing the clarify brief (Phase 4c) before completing continuity state update
  2. `skills/cortex-research/SKILL.md` invokes cortex-critique after writing each dossier before setting `research_complete: true`
  3. `skills/cortex-spec/SKILL.md` invokes cortex-critique against spec.md before presenting the contract approval gate
  4. In full-auto mode, AI critique runs and findings are persisted; the `human_critique` gate is skipped and the gate advances automatically
  5. In supervised mode, the owner is shown the AI critique findings in plain language and given the opportunity to respond before the gate advances
**Research**: Unlikely
**Plans**: 0 plans

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| Phase 1: Build cortex-critique skill | 0/0 | Not started | - |
| Phase 2: Wire critique into existing skills | 0/0 | Not started | - |
