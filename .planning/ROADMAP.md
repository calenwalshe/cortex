# Roadmap: Pattern Harvest

## Overview

Add 13 patterns harvested from competing systems (Praetorian, BMAD, Swarm-IOSM, OpenHands, LangSmith, DeepEval) to Cortex across 3 tiers: safety nets (prevent runaway loops and silent degradation), repair quality (make each fix attempt count), and intelligence depth (smarter planning and better measurement). All patterns fit within SKILL.md instruction architecture — no new runtime dependencies. Success = repair loops self-terminate, context degradation is caught before it hurts, and planning depth adapts to work complexity.

## Phases

### Phase 1: Context Capacity Gate

**Goal**: Add a mandatory context_capacity gate to resolve-autonomy.js and a PostToolUse hook that monitors context window usage, warning at 75-85% and blocking at >85%.
**Depends on**: Nothing
**Requirements**: REQ-PH-01
**Success Criteria** (what must be TRUE):
  1. Context capacity gate blocks at >85% used, warns at 75-85%
**Research**: Unlikely
**Plans**: 0 plans

### Phase 2: Repair Budget + Convergence Detector

**Goal**: Add repair_budget and cooldown fields to the contract template, and add a convergence detector to cortex-review that identifies repeated similar failures and generates convergence-stall.md.
**Depends on**: Phase 1: Context Capacity Gate
**Requirements**: REQ-PH-02, REQ-PH-03
**Success Criteria** (what must be TRUE):
  1. Repair contracts capped at max_repair_contracts (default 3)
  2. Convergence detector identifies 3+ similar failures, generates convergence-stall.md
**Research**: Unlikely
**Plans**: 0 plans

### Phase 3: Circuit Breaker + Iteration Budget

**Goal**: Add circuit breaker logic and iteration budget (max_steps) to codex-exec-wrapper.sh so Codex dispatch stops after 3 consecutive failures and runaway tasks are killed.
**Depends on**: Phase 2: Repair Budget + Convergence Detector
**Requirements**: REQ-PH-04, REQ-PH-05
**Success Criteria** (what must be TRUE):
  1. Codex circuit breaker stops dispatch after 3 consecutive failures
  2. Codex iteration budget kills tasks exceeding max_steps
**Research**: Unlikely
**Plans**: 0 plans

### Phase 4: Failed Approaches + Reflexion Mandate

**Goal**: Add Failed Approaches and Why Previous Approach Failed sections to the contract template so repair contracts carry failure history and force the repairing agent to explain why the previous approach failed.
**Depends on**: Phase 3: Circuit Breaker + Iteration Budget
**Requirements**: REQ-PH-06
**Success Criteria** (what must be TRUE):
  1. Repair contracts include Failed Approaches + Why Previous Failed sections
**Research**: Unlikely
**Plans**: 0 plans

### Phase 5: Validator Taxonomy + Completion Promises

**Goal**: Annotate contract validators as [external] or [judgment] to distinguish deterministic from taste checks, and add completion promise signaling so executors emit explicit done signals that hooks can verify.
**Depends on**: Phase 4: Failed Approaches + Reflexion Mandate
**Requirements**: REQ-PH-07, REQ-PH-08
**Success Criteria** (what must be TRUE):
  1. Validators annotated as [external] or [judgment]
  2. Executor emits CORTEX_PROMISE signal, hook checks for it
**Research**: Unlikely
**Plans**: 0 plans

### Phase 6: Complexity Tiers

**Goal**: Add a complexity field (trivial/standard/complex) to the clarify-brief template and add conditional logic to cortex-research and cortex-spec so trivial slugs skip research and get thin specs.
**Depends on**: Phase 5: Validator Taxonomy + Completion Promises
**Requirements**: REQ-PH-09, REQ-PH-10
**Success Criteria** (what must be TRUE):
  1. Clarify brief has complexity field (trivial/standard/complex)
  2. Trivial slugs skip research, get thin spec
**Research**: Unlikely
**Plans**: 0 plans

### Phase 7: Cross-Artifact Coherence + Composite Scoring

**Goal**: Add a cross-artifact coherence validator to cortex-spec that verifies the spec addresses all clarify-brief goals, and create eval-status.md template with 0-1 per-dimension composite scoring.
**Depends on**: Phase 6: Complexity Tiers
**Requirements**: REQ-PH-11, REQ-PH-12
**Success Criteria** (what must be TRUE):
  1. Cross-artifact coherence check at spec time
  2. eval-status.md shows 0-1 scores per dimension with composite
**Research**: Unlikely
**Plans**: 0 plans

### Phase 8: Event Log + Step Budget

**Goal**: Add JSONL event logging and step-count budget enforcement to codex-exec-wrapper.sh, and create the execution-event JSON schema.
**Depends on**: Phase 7: Cross-Artifact Coherence + Composite Scoring
**Requirements**: REQ-PH-13
**Success Criteria** (what must be TRUE):
  1. Execution event log records structured events per Codex task
**Research**: Unlikely
**Plans**: 0 plans

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| Phase 1: Context Capacity Gate | 0/0 | Not started | - |
| Phase 2: Repair Budget + Convergence Detector | 0/0 | Not started | - |
| Phase 3: Circuit Breaker + Iteration Budget | 0/0 | Not started | - |
| Phase 4: Failed Approaches + Reflexion Mandate | 0/0 | Not started | - |
| Phase 5: Validator Taxonomy + Completion Promises | 0/0 | Not started | - |
| Phase 6: Complexity Tiers | 0/0 | Not started | - |
| Phase 7: Cross-Artifact Coherence + Composite Scoring | 0/0 | Not started | - |
| Phase 8: Event Log + Step Budget | 0/0 | Not started | - |
