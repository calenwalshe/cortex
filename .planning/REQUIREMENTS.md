# Requirements: Pattern Harvest

**Defined:** 2026-04-03
**Core Value:** Repair loops self-terminate, context degradation is caught before it hurts, and planning depth adapts to work complexity — all without new runtime dependencies.

## Safety Net Requirements

- [ ] **REQ-PH-01**: Context capacity gate blocks at >85% used, warns at 75-85%
- [ ] **REQ-PH-02**: Repair contracts capped at max_repair_contracts (default 3)
- [ ] **REQ-PH-03**: Convergence detector identifies 3+ similar failures, generates convergence-stall.md
- [ ] **REQ-PH-04**: Codex circuit breaker stops dispatch after 3 consecutive failures
- [ ] **REQ-PH-05**: Codex iteration budget kills tasks exceeding max_steps

## Repair Quality Requirements

- [ ] **REQ-PH-06**: Repair contracts include Failed Approaches + Why Previous Failed sections
- [ ] **REQ-PH-07**: Validators annotated as [external] or [judgment]
- [ ] **REQ-PH-08**: Executor emits CORTEX_PROMISE signal, hook checks for it

## Intelligence Depth Requirements

- [ ] **REQ-PH-09**: Clarify brief has complexity field (trivial/standard/complex)
- [ ] **REQ-PH-10**: Trivial slugs skip research, get thin spec
- [ ] **REQ-PH-11**: Cross-artifact coherence check at spec time
- [ ] **REQ-PH-12**: eval-status.md shows 0-1 scores per dimension with composite
- [ ] **REQ-PH-13**: Execution event log records structured events per Codex task

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| **REQ-PH-01** | Phase 1: Context Capacity Gate | Pending |
| **REQ-PH-02** | Phase 2: Repair Budget + Convergence Detector | Pending |
| **REQ-PH-03** | Phase 2: Repair Budget + Convergence Detector | Pending |
| **REQ-PH-04** | Phase 3: Circuit Breaker + Iteration Budget | Pending |
| **REQ-PH-05** | Phase 3: Circuit Breaker + Iteration Budget | Pending |
| **REQ-PH-06** | Phase 4: Failed Approaches + Reflexion Mandate | Pending |
| **REQ-PH-07** | Phase 5: Validator Taxonomy + Completion Promises | Pending |
| **REQ-PH-08** | Phase 5: Validator Taxonomy + Completion Promises | Pending |
| **REQ-PH-09** | Phase 6: Complexity Tiers | Pending |
| **REQ-PH-10** | Phase 6: Complexity Tiers | Pending |
| **REQ-PH-11** | Phase 7: Cross-Artifact Coherence + Composite Scoring | Pending |
| **REQ-PH-12** | Phase 7: Cross-Artifact Coherence + Composite Scoring | Pending |
| **REQ-PH-13** | Phase 8: Event Log + Step Budget | Pending |

**Coverage:**
- Safety Net requirements: 5 total — all mapped
- Repair Quality requirements: 3 total — all mapped
- Intelligence Depth requirements: 5 total — all mapped
- Unmapped: 0
