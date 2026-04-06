# Contract: pattern-harvest — execute

**ID:** pattern-harvest-001
**Slug:** pattern-harvest
**Phase:** execute
**Created:** 20260403T215523Z
**Status:** draft
**Repair Budget:** max_repair_contracts: 3, cooldown_between_repairs: 1

---

## Objective

Add 13 harvested patterns to Cortex in 3 tiers — safety nets, repair quality, and intelligence depth — so repair loops self-terminate, context degradation is caught, and planning depth adapts to complexity.

---

## Deliverables

- Modified `scripts/cortex/resolve-autonomy.js` — context_capacity gate
- New `hooks/cortex-context-capacity.sh`
- Modified `templates/cortex/contract.md` — repair budget, failed approaches, validator taxonomy, completion promise
- Modified `skills/cortex-review/SKILL.md` — convergence detector, composite scoring
- Modified `skills/cortex-clarify/SKILL.md` — complexity tier
- Modified `skills/cortex-research/SKILL.md` — complexity-adaptive depth
- Modified `skills/cortex-spec/SKILL.md` — coherence check, complexity gating
- Modified `scripts/cortex/codex-exec-wrapper.sh` — circuit breaker, iteration budget, event log
- Modified `hooks/cortex-task-completed.sh` — completion promise check
- New `templates/cortex/eval-status.md`
- New `schemas/execution-event.schema.json`
- Modified `templates/cortex/clarify-brief.md` — complexity field
- Modified `runtime-manifest.json`

---

## Scope

### In Scope

- 4 safety net patterns (context gate, repair budget, convergence detector, circuit breaker)
- 4 repair quality patterns (failed approaches, reflexion, validator taxonomy, completion promises)
- 5 intelligence depth patterns (complexity tiers, coherence check, composite scoring, event log, iteration budget)

### Out of Scope

- Semantic memory retrieval (Tier 4 — separate milestone)
- LLM-judge calibration (Tier 4)
- Agent personas, minimum-issue quotas, mesh/swarm coordination
- Layered LLM routing (Tier 4)

---

## Write Roots

- `scripts/cortex/` — resolve-autonomy.js, codex-exec-wrapper.sh
- `hooks/` — cortex-context-capacity.sh, cortex-task-completed.sh
- `templates/cortex/` — contract.md, clarify-brief.md, eval-status.md
- `schemas/` — execution-event.schema.json
- `skills/cortex-clarify/` — SKILL.md
- `skills/cortex-research/` — SKILL.md
- `skills/cortex-spec/` — SKILL.md
- `skills/cortex-review/` — SKILL.md
- `runtime-manifest.json`

---

## Done Criteria

- [ ] Context capacity gate blocks at >85% used, warns at 75-85%
- [ ] Repair contracts capped at max_repair_contracts (default 3)
- [ ] Convergence detector identifies 3+ similar failures, generates convergence-stall.md
- [ ] Codex circuit breaker stops dispatch after 3 consecutive failures
- [ ] Codex iteration budget kills tasks exceeding max_steps
- [ ] Repair contracts include Failed Approaches + Why Previous Failed sections
- [ ] Validators annotated as [external] or [judgment]
- [ ] Executor emits CORTEX_PROMISE signal, hook checks for it
- [ ] Clarify brief has complexity field (trivial/standard/complex)
- [ ] Trivial slugs skip research, get thin spec
- [ ] Cross-artifact coherence check at spec time
- [ ] eval-status.md shows 0-1 scores per dimension with composite
- [ ] Execution event log records structured events per Codex task

---

## Validators

- [ ] `node scripts/cortex/resolve-autonomy.js < '{"preset":"supervised"}' | grep context_capacity` returns true
- [ ] `grep "repair_budget\|max_repair_contracts" templates/cortex/contract.md` returns matches
- [ ] `grep "convergence" skills/cortex-review/SKILL.md` returns matches
- [ ] `grep "circuit_breaker\|CIRCUIT" scripts/cortex/codex-exec-wrapper.sh` returns matches
- [ ] `grep "max_steps\|iteration_budget" scripts/cortex/codex-exec-wrapper.sh` returns matches
- [ ] `grep "Failed Approaches" templates/cortex/contract.md` returns match
- [ ] `grep "external.*judgment\|judgment.*external" templates/cortex/contract.md` returns match
- [ ] `grep "CORTEX_PROMISE" hooks/cortex-task-completed.sh` returns match
- [ ] `grep "complexity" templates/cortex/clarify-brief.md` returns match
- [ ] `grep "coherence" skills/cortex-spec/SKILL.md` returns match
- [ ] `test -f templates/cortex/eval-status.md` exits 0
- [ ] `test -f schemas/execution-event.schema.json` exits 0

---

## Eval Plan

docs/cortex/evals/pattern-harvest/eval-plan.md

---

## Approvals

- [x] Contract approval
- [x] Evals approval

---

## Rollback Hints

- Revert each modified file via `git checkout HEAD~N -- <path>`
- Delete new files: hooks/cortex-context-capacity.sh, templates/cortex/eval-status.md, schemas/execution-event.schema.json
- Remove context_capacity gate from resolve-autonomy.js PRESET_DEFAULTS
- Remove context-capacity hook registration from runtime-manifest.json and settings
