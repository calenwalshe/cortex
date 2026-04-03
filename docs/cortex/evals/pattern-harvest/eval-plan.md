# Eval Plan: pattern-harvest

**Slug:** pattern-harvest
**Timestamp:** 20260403T221000Z
**Approved By:** project lead
**Approved At:** 20260403T221000Z

---

## Approved Dimensions

- Functional Correctness
- Regression
- Integration
- Style
- UX/Taste

---

## Fixtures Per Dimension

### Fixtures: Functional Correctness
- A `.cortex/state.json` with context_capacity gate registered
- A contract with `repair_budget: 3` and 3 existing repair contracts to test cap
- 3+ repair failure artifacts with >80% similar signatures for convergence detection
- A codex-exec-wrapper session with 3 consecutive task failures for circuit breaker test
- A clarify brief with each complexity value (trivial/standard/complex)
- A mock executor output with and without CORTEX_PROMISE signal

### Fixtures: Regression
- Snapshot of all 9 modified files before changes (git baseline)
- Existing autonomy presets (supervised, gates-only, full-auto) must still resolve correctly
- Existing hook registrations must remain functional
- Existing contract template fields must be preserved (no removals)

### Fixtures: Integration
- End-to-end scenario: context-capacity hook triggers → resolve-autonomy.js evaluates gate → execution blocked/warned
- End-to-end scenario: 3 Codex failures → circuit breaker activates → no further dispatch
- End-to-end scenario: executor emits CORTEX_PROMISE → hook validates → task marked complete
- End-to-end scenario: 3 similar repair failures → convergence detector fires → convergence-stall.md generated

### Fixtures: Style
- Existing SKILL.md files for convention reference
- Existing shell script style (codex-exec-wrapper.sh, other hooks)
- Existing JSON schema conventions (if any in schemas/)

### Fixtures: UX/Taste
- Sample convergence-stall.md output for human review
- Sample context capacity warning and block messages
- Sample eval-status.md with composite scores
- Sample completion promise signal format

---

## Thresholds Per Dimension

### Threshold: Functional Correctness
**Pass:** 13/13 done criteria satisfied, 12/12 validators exit 0
**Fail:** Any done criterion unsatisfied or any validator exits non-zero

### Threshold: Regression
**Pass:** 0 regressions in existing behavior across all modified files
**Fail:** Any regression in existing behavior (gate resolution, hook firing, template field availability)

### Threshold: Integration
**Pass:** 4/4 end-to-end scenarios complete successfully
**Fail:** Any integration scenario fails to propagate signals correctly

### Threshold: Style
**Pass:** No convention violations across all new/modified files
**Fail:** Any structural deviation from established conventions without justification

### Threshold: UX/Taste
**Pass:** Human reviewer approves all user-facing output formats
**Fail:** Human reviewer flags any output as confusing or misleading

---

## Run Instructions

1. Checkout the git baseline commit (pre-implementation) and snapshot the 9 files being modified for regression comparison.
2. Run all 12 contract validators from contract-001.md § Validators — each must exit 0:
   - `node scripts/cortex/resolve-autonomy.js < '{"preset":"supervised"}' | grep context_capacity`
   - `grep "repair_budget\|max_repair_contracts" templates/cortex/contract.md`
   - `grep "convergence" skills/cortex-review/SKILL.md`
   - `grep "circuit_breaker\|CIRCUIT" scripts/cortex/codex-exec-wrapper.sh`
   - `grep "max_steps\|iteration_budget" scripts/cortex/codex-exec-wrapper.sh`
   - `grep "Failed Approaches" templates/cortex/contract.md`
   - `grep "external.*judgment\|judgment.*external" templates/cortex/contract.md`
   - `grep "CORTEX_PROMISE" hooks/cortex-task-completed.sh`
   - `grep "complexity" templates/cortex/clarify-brief.md`
   - `grep "coherence" skills/cortex-spec/SKILL.md`
   - `test -f templates/cortex/eval-status.md`
   - `test -f schemas/execution-event.schema.json`
3. Verify all 13 done criteria from contract-001.md § Done Criteria by inspecting the deliverables (gate thresholds, cap enforcement, signal format, template fields, conditional logic).
4. Regression check: diff the 9 modified files against the baseline snapshot. Verify existing autonomy presets resolve identically. Verify existing hooks still fire. Verify no contract template fields were removed.
5. Integration check: walk each of the 4 end-to-end scenarios manually, verifying signal propagation across component boundaries.
6. Style check: review all new/modified shell scripts, SKILL.md sections, and JSON schema against existing conventions.
7. UX/Taste check: present sample outputs (convergence-stall.md, context capacity messages, eval-status.md, completion promise format) to human reviewer for approval.

---

## Results

- [ ] Functional Correctness —
- [ ] Regression —
- [ ] Integration —
- [ ] Style —
- [ ] UX/Taste —
