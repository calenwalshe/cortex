# Eval Proposal: pattern-harvest

**Slug:** pattern-harvest
**Timestamp:** 20260403T220500Z
**Status:** draft

---

## Proposed Dimensions

### 1. Functional Correctness
**Applies because:** 13 done criteria in the contract are all mechanically verifiable — gate thresholds, grep-based validators, file existence checks, signal emission. Every deliverable has a concrete pass/fail condition.
**approval_required:** false

### 2. Regression
**Applies because:** 9 existing files are modified (resolve-autonomy.js, codex-exec-wrapper.sh, 4 SKILL.md files, contract template, clarify-brief template, cortex-task-completed.sh, runtime-manifest.json). Each modification must preserve existing behavior while adding new capabilities.
**approval_required:** false

### 3. Integration
**Applies because:** Multiple components must interact correctly: context-capacity hook reads remaining_percentage and feeds resolve-autonomy.js; circuit breaker in codex-exec-wrapper.sh must propagate state to GSD upstream; completion promise signal must be emitted by executor AND checked by cortex-task-completed.sh hook; convergence detector in cortex-review must read prior repair failure signatures from contract artifacts.
**approval_required:** false

### 4. Safety/Security
**Applies because:** EXCLUDED. No auth, secrets management, input validation from untrusted sources, or privilege escalation paths. All modifications are internal tooling operating on local artifacts.

### 5. Performance
**Applies because:** EXCLUDED. No latency, throughput, or resource usage thresholds specified in the contract. Context capacity monitoring measures LLM context window usage, not system performance.

### 6. Resilience
**Applies because:** EXCLUDED. No networked systems, external API dependencies, or failure recovery paths. Circuit breaker and convergence detector are logical constructs within shell scripts and SKILL.md instructions, not network resilience patterns.

### 7. Style
**Applies because:** All deliverables include code (shell scripts, JS) and documentation (SKILL.md files, templates, JSON schema). Style consistency with existing Cortex conventions must be verified.
**approval_required:** false

### 8. UX/Taste
**Applies because:** Several deliverables produce user-facing output: convergence-stall.md artifact content and format, context capacity warning/block messages, eval-status.md composite scoring display, completion promise signal format. These involve taste decisions about how diagnostic information is presented to the human operator.
**approval_required:** true

---

## Fixtures

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

## Rubrics

### Rubric: Functional Correctness
**Pass:** All 12 contract validators exit 0. All 13 done criteria checked and satisfied. Each grep/test command in the validators section returns expected output.
**Fail:** Any validator exits non-zero, or any done criterion is not demonstrably met.

### Rubric: Regression
**Pass:** All existing autonomy presets resolve identically to pre-change behavior. All existing hooks still fire on their registered events. All existing contract template fields are preserved. No existing tests broken.
**Fail:** Any existing behavior changed without explicit justification in the spec, or any existing test fails.

### Rubric: Integration
**Pass:** All 4 end-to-end integration scenarios complete successfully — signals propagate correctly across component boundaries, state changes are visible to downstream consumers.
**Fail:** Any cross-component signal is dropped, misformatted, or fails to trigger the expected downstream behavior.

### Rubric: Style
**Pass:** New/modified shell scripts follow existing hook conventions (error handling, exit codes, variable naming). New/modified SKILL.md sections follow existing instruction format. JSON schema follows JSON Schema Draft 2020-12. No lint violations.
**Fail:** Inconsistent conventions, missing error handling in scripts, or structural deviation from existing patterns.

### Rubric: UX/Taste
**Pass:** Human reviewer confirms that warning/block messages are clear, actionable, and not noisy. Convergence-stall.md format is scannable. Eval-status.md composite scores are immediately interpretable. Completion promise format is unambiguous.
**Fail:** Human reviewer identifies confusing, verbose, or misleading output in any user-facing artifact.

---

## Thresholds

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

## Failure Taxonomy

| Failure Category | Severity | Description | Repair Path |
|-----------------|----------|-------------|-------------|
| Gate not registered | P0 | context_capacity gate missing from resolve-autonomy.js | Add gate to PRESET_DEFAULTS and MANDATORY_GATES |
| Signal not emitted | P0 | CORTEX_PROMISE signal not emitted or not detected by hook | Fix executor signal format or hook parsing |
| Circuit breaker inactive | P0 | 3+ consecutive failures don't stop Codex dispatch | Fix failure counter and threshold logic in wrapper |
| Convergence false negative | P0 | 3+ similar failures don't trigger convergence-stall.md | Fix similarity scoring threshold or comparison logic |
| Regression in gate resolution | P1 | Existing presets resolve differently after changes | Revert gate additions, fix merge with existing gates |
| Hook registration broken | P1 | Existing hooks stop firing after runtime-manifest.json changes | Fix manifest entries, verify hook event bindings |
| Repair budget not enforced | P1 | More than max_repair_contracts created for a slug | Add enforcement check in cortex-spec repair path |
| Complexity tier ignored | P1 | Trivial slugs still get full research/spec treatment | Fix conditional logic in research/spec SKILL.md files |
| Style inconsistency | P2 | New code doesn't match existing conventions | Refactor to match established patterns |
| Unclear warning messages | P2 | Context capacity or convergence messages are confusing | Revise message text after human feedback |
| Missing event log fields | P3 | JSONL events missing optional fields | Add missing fields in next iteration |
| Schema documentation gap | P3 | execution-event.schema.json missing descriptions | Add field descriptions |

---

## Document-Level Approval Flag

**approval_required:** true

**Reviewer:** project lead

**Approval Status:** approved
