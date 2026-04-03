# GSD Handoff: pattern-harvest

**Slug:** pattern-harvest
**Timestamp:** 20260403T215523Z
**Status:** draft

---

## Objective

Add 13 patterns harvested from competing systems (Praetorian, BMAD, Swarm-IOSM, OpenHands, LangSmith, DeepEval) to Cortex across 3 tiers: safety nets (prevent runaway loops and silent degradation), repair quality (make each fix attempt count), and intelligence depth (smarter planning and better measurement). All patterns fit within SKILL.md instruction architecture — no new runtime dependencies. Success = repair loops self-terminate, context degradation is caught before it hurts, and planning depth adapts to work complexity.

---

## Deliverables

- Modified `scripts/cortex/resolve-autonomy.js` — context_capacity mandatory gate
- New `hooks/cortex-context-capacity.sh` — PostToolUse context monitoring
- Modified `templates/cortex/contract.md` — repair budget, failed approaches, validator taxonomy, completion promise
- Modified `skills/cortex-review/SKILL.md` — convergence detector, composite scoring
- Modified `skills/cortex-clarify/SKILL.md` — complexity tier field
- Modified `skills/cortex-research/SKILL.md` — complexity-adaptive depth
- Modified `skills/cortex-spec/SKILL.md` — coherence check, complexity-gated depth
- Modified `scripts/cortex/codex-exec-wrapper.sh` — circuit breaker, iteration budget, event log
- Modified `hooks/cortex-task-completed.sh` — completion promise check
- New `templates/cortex/eval-status.md` — composite quality score format
- New `schemas/execution-event.schema.json` — event log schema
- Modified `templates/cortex/clarify-brief.md` — complexity field
- Modified `runtime-manifest.json` — context-capacity hook registration

---

## Requirements

- None formalized

---

## Tasks

**Tier 1 — Safety Nets:**
- [ ] Add `context_capacity` mandatory gate to resolve-autonomy.js (75%/85% thresholds)
- [ ] Create `hooks/cortex-context-capacity.sh` PostToolUse hook
- [ ] Register hook in runtime-manifest.json and .claude/settings.json
- [ ] Add `repair_budget` (max_repair_contracts, cooldown) fields to contract template
- [ ] Add convergence detector to cortex-review (similarity scoring on repair failure signatures)
- [ ] Generate convergence-stall.md on 3+ similar failures
- [ ] Add circuit breaker to codex-exec-wrapper.sh (3 failures = stop Codex dispatch)
- [ ] Add iteration budget (max_steps) to codex-exec-wrapper.sh

**Tier 2 — Repair Quality:**
- [ ] Add `## Failed Approaches` section to contract template
- [ ] Add `## Why Previous Approach Failed` required section for repair contracts
- [ ] Add `[external]`/`[judgment]` taxonomy to contract validator section
- [ ] Add completion promise check to cortex-task-completed.sh
- [ ] Document promise format in contract template

**Tier 3 — Intelligence Depth:**
- [ ] Add `complexity` field (trivial/standard/complex) to clarify-brief template
- [ ] Add complexity-conditional logic to cortex-research (trivial skips research)
- [ ] Add complexity-conditional logic to cortex-spec (trivial gets thin spec)
- [ ] Add cross-artifact coherence validator to cortex-spec
- [ ] Create `templates/cortex/eval-status.md` with composite 0-1 scoring
- [ ] Create `schemas/execution-event.schema.json`
- [ ] Add JSONL event logging to codex-exec-wrapper.sh
- [ ] Add step-count budget enforcement to Codex JSONL processing

---

## Acceptance Criteria

- [ ] Context capacity gate blocks at >85% used, warns at 75-85%
- [ ] Repair contracts capped at max_repair_contracts (default 3) per slug
- [ ] Convergence detector identifies 3+ similar repair failures and generates convergence-stall.md
- [ ] Codex circuit breaker stops dispatch after 3 consecutive failures
- [ ] Codex iteration budget kills tasks exceeding max_steps
- [ ] Repair contracts include Failed Approaches + Why Previous Failed sections
- [ ] Validators annotated as [external] or [judgment]
- [ ] Executor emits CORTEX_PROMISE completion signal, hook checks for it
- [ ] Clarify brief has complexity field (trivial/standard/complex)
- [ ] Trivial slugs skip research, get thin spec
- [ ] Cross-artifact coherence check verifies spec addresses all clarify goals
- [ ] eval-status.md shows 0-1 scores per dimension with composite
- [ ] Execution event log records structured events per Codex task

---

## Contract Link

docs/cortex/contracts/pattern-harvest/contract-001.md
