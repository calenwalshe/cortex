# Spec: pattern-harvest

**Slug:** pattern-harvest
**Timestamp:** 20260403T215523Z
**Status:** draft

---

## 1. Problem

Cortex lacks safety nets for runaway repair loops, has no context capacity monitoring, treats all validators equally regardless of determinism, and applies the same planning depth to trivial and complex work. Competing systems (Praetorian, Swarm-IOSM, BMAD, OpenHands, LangSmith, DeepEval) have solved these problems with patterns that fit cleanly into Cortex's existing SKILL.md instruction architecture. Without these patterns, Cortex can burn tokens on convergent repair cycles, silently degrade at high context usage, and waste planning effort on simple tasks.

---

## 2. Scope

### In Scope

**Tier 1 — Safety Nets:**
- Convergence detector for repair cycles (similarity scoring)
- Repair budget + cooldown fields in contract template
- Context capacity gate (mandatory, threshold-based)
- Circuit breaker for Codex dispatch

**Tier 2 — Repair Quality:**
- Failed approaches log in repair contracts
- Reflexion mandate (why-it-failed section)
- Validator taxonomy (deterministic vs judgment annotations)
- Completion promises from executors

**Tier 3 — Intelligence Depth:**
- Scale-adaptive complexity tiers in clarify brief
- Cross-artifact coherence check at spec time
- Composite quality score in eval-status.md
- Event log for task execution (JSONL)
- Iteration budget per task (step count)

### Out of Scope

- Named agent personas (explicitly rejected — false confidence, same LLM)
- Minimum-issue review quotas (proven failure mode)
- Full mesh/swarm coordination (adds unpredictability)
- Pure LLM routing without static rules (documented broken)
- Semantic memory retrieval with embeddings (Tier 4 — high effort, separate milestone)
- LLM-judge calibration loop (Tier 4 — separate milestone)
- Sleep-time background refinement (unnecessary complexity)
- Graph memory for entity relationships (premature)

---

## 3. Architecture Decision

**Chosen approach:** 13 patterns delivered across 3 tiers in dependency order. Each pattern is a targeted modification to existing artifacts (SKILL.md files, contract template, hook scripts, resolve-autonomy.js) — no new runtime dependencies, no architectural changes.

**Rationale:** Every pattern was validated against a real competing system. Tier ordering reflects risk: safety nets first (prevent damage), repair quality second (make fixes work), intelligence depth third (measure better). Each tier is independently shippable.

### Alternatives Considered

- **Build a new orchestration layer:** Rejected — Cortex's SKILL.md instruction architecture is the right abstraction. Adding a separate orchestrator duplicates what Claude Code already does.
- **Adopt CrewAI/LangGraph wholesale:** Rejected — these are general-purpose frameworks. Cortex's opinionated pipeline (clarify→research→spec→contract→execute) is its strength, not a limitation to overcome.
- **Ship everything in one milestone:** Rejected — 13 patterns is too much for one pass. Three tiers allow shipping value incrementally and validating each tier before building the next.

---

## 4. Interfaces

**Modified SKILL.md files:**
- `skills/cortex-clarify/SKILL.md` — complexity tier field
- `skills/cortex-research/SKILL.md` — complexity-adaptive depth
- `skills/cortex-spec/SKILL.md` — coherence check, complexity-gated spec depth
- `skills/cortex-review/SKILL.md` — convergence detector, composite scoring, omission lens
- `skills/cortex-audit/SKILL.md` — no changes this milestone

**Modified templates:**
- `templates/cortex/contract.md` — repair budget, failed approaches, validator taxonomy, completion promise fields
- `templates/cortex/clarify-brief.md` — complexity tier field
- `templates/cortex/eval-status.md` — new template for composite quality scores

**Modified scripts/hooks:**
- `scripts/cortex/resolve-autonomy.js` — new `context_capacity` mandatory gate
- `scripts/cortex/codex-exec-wrapper.sh` — circuit breaker, iteration budget, event log
- New hook: `hooks/cortex-context-capacity.sh` — PostToolUse context monitoring
- `hooks/cortex-task-completed.sh` — completion promise check

**New files:**
- `schemas/execution-event.schema.json` — event log schema

---

## 5. Dependencies

- **Cortex v1.5 (token-efficiency)** — codex-exec-wrapper.sh must exist for circuit breaker + iteration budget
- **resolve-autonomy.js** — existing gate resolver, extended with new gate
- **PostToolUse hook infrastructure** — existing, used for context capacity monitoring
- **GSD upstream execute-plan.md** — reads circuit breaker state from wrapper

---

## 6. Risks

- **Convergence detector false positives** — Similarity scoring may flag legitimate iterative progress as "stuck." Mitigation: require 3 consecutive similar failures (not 2), and allow human override.
- **Context capacity gate too aggressive** — 85% threshold may trigger too early for long phases. Mitigation: threshold is configurable in autonomy.json, not hardcoded.
- **Complexity tier misclassification** — User picks "trivial" for something complex, gets thin spec. Mitigation: complexity is a suggestion, not a hard gate. Research and spec skills can override if they detect the work is more complex than labeled.
- **Repair budget too low** — 3 max repairs may not be enough for genuinely hard problems. Mitigation: budget is per-contract and configurable. Human can always create a new contract manually.

---

## 7. Sequencing

1. **Tier 1a: Context capacity gate** — New mandatory gate + PostToolUse hook. Verify: context monitoring active, blocks at >85%.

2. **Tier 1b: Repair budget + convergence detector** — New contract fields + similarity scoring in cortex-review. Verify: repair contracts capped at 3, convergence stall detected after 3 similar failures.

3. **Tier 1c: Codex circuit breaker + iteration budget** — Modify codex-exec-wrapper.sh. Verify: 3 consecutive Codex failures stops dispatch, step-count budget kills runaway tasks.

4. **Tier 2a: Failed approaches log + reflexion mandate** — New sections in contract template. Verify: repair contracts carry failure history, repairing agent must explain why previous approach failed.

5. **Tier 2b: Validator taxonomy + completion promises** — Annotation in contract validators, hook check for done signal. Verify: deterministic vs judgment validators distinguished, executor emits explicit completion signal.

6. **Tier 3a: Complexity tiers** — Modify clarify brief template + conditional logic in research/spec skills. Verify: trivial tasks skip research, complex tasks require extended validators.

7. **Tier 3b: Cross-artifact coherence + composite scoring** — New validator in spec, new eval-status format. Verify: spec checked against clarify goals, quality scores are 0-1 per dimension.

8. **Tier 3c: Event log + iteration budget** — JSONL logging in codex-exec-wrapper.sh. Verify: structured events logged per task, step-count limits enforced.

---

## 8. Tasks

**Tier 1 — Safety Nets:**
- [ ] Add `context_capacity` to resolve-autonomy.js as mandatory gate with thresholds (75%/85%)
- [ ] Create `hooks/cortex-context-capacity.sh` PostToolUse hook reading remaining_percentage
- [ ] Register context-capacity hook in runtime-manifest.json and settings
- [ ] Add `repair_budget` and `cooldown_between_repairs` fields to contract template
- [ ] Add convergence detector to cortex-review SKILL.md (compare repair failure signatures)
- [ ] Add `convergence-stall.md` artifact generation on 3+ similar failures
- [ ] Add circuit breaker logic to codex-exec-wrapper.sh (3 consecutive failures = stop Codex)
- [ ] Add iteration budget (max_steps) alongside timeout in codex-exec-wrapper.sh

**Tier 2 — Repair Quality:**
- [ ] Add `## Failed Approaches` section to contract template (carried forward on repair)
- [ ] Add `## Why Previous Approach Failed` required section for repair contracts
- [ ] Add `[external]` / `[judgment]` taxonomy annotations to contract validator section
- [ ] Add completion promise check to cortex-task-completed.sh hook
- [ ] Document completion promise format in contract template

**Tier 3 — Intelligence Depth:**
- [ ] Add `complexity` field (trivial/standard/complex) to clarify-brief template
- [ ] Add complexity-conditional logic to cortex-research SKILL.md (trivial skips research)
- [ ] Add complexity-conditional logic to cortex-spec SKILL.md (trivial gets thin spec)
- [ ] Add cross-artifact coherence validator to cortex-spec Phase 1
- [ ] Create `templates/cortex/eval-status.md` with composite scoring format (0-1 per dimension)
- [ ] Create `schemas/execution-event.schema.json` for structured event logging
- [ ] Add JSONL event logging to codex-exec-wrapper.sh
- [ ] Add step-count parsing and budget enforcement to Codex JSONL processing

---

## 9. Acceptance Criteria

- [ ] Context capacity gate blocks execution when context_window.remaining_percentage < 15% (>85% used)
- [ ] Context capacity gate warns when remaining_percentage is 15-25% (75-85% used)
- [ ] Repair contracts are capped at `max_repair_contracts` (default 3) per slug
- [ ] Convergence detector identifies 3+ consecutive repair cycles with >80% similar failure signatures and generates convergence-stall.md
- [ ] Codex circuit breaker stops dispatching after 3 consecutive task failures in a wave
- [ ] Codex iteration budget kills a task when step count exceeds `max_steps` (derived from file count * multiplier)
- [ ] Repair contracts include `## Failed Approaches` section populated from previous repair history
- [ ] Repair contracts require `## Why Previous Approach Failed` section (cortex-spec blocks without it)
- [ ] Contract validators are annotated as `[external]` or `[judgment]` — deterministic checks eligible for auto-repair
- [ ] Executor emits `CORTEX_PROMISE: contract-{ID} COMPLETE` signal, cortex-task-completed hook checks for it
- [ ] Clarify brief includes `complexity` field with values trivial/standard/complex
- [ ] `/cortex-research` skips research for `complexity: trivial` slugs
- [ ] `/cortex-spec` generates thin spec (fewer sections) for `complexity: trivial` slugs
- [ ] Cross-artifact coherence check at spec time verifies spec addresses all clarify-brief goals
- [ ] `eval-status.md` shows 0-1 scores per dimension with weighted composite
- [ ] Execution event log (JSONL) records task_started, file_edited, test_run, task_completed/failed per Codex task
