# Research Dossier: adaptive-execution — Signal Detection & Action Design

**Slug:** adaptive-execution
**Phase:** research (design)
**Timestamp:** 20260406T
**Depth:** standard
**Upstream:** `20260406T250000Z-clarify-brief.md`

---

## Executive Summary

This document defines the complete signal-to-action mapping for adaptive execution. Six early warning signals are specified with concrete thresholds, data sources, and false positive profiles. Six adaptation actions are defined with reversibility properties. A decision matrix maps signals to actions. The MVP is a single signal (task-type failure pattern) driving a single action (reroute remaining same-type tasks) at a single hook point (between task dispatches within a wave).

---

## Signal Detection Layer

### Signal 1: Codex Struggling on Task Type

**What:** Codex fails on tasks sharing a characteristic — same file pattern, same action category (e.g., auth-related, TDD tasks), or same file-count tier.

**Data source:** `output_result` JSON from `codex-exec-wrapper.sh`. Each result includes `task_id`, `fallback_reason`, `status`. Cross-reference with task-router classification data (`task_name`, file count, rule matched). Event log JSONL at `.cortex/events/{phase}-{plan}.jsonl` records `task_started` and `task_failed` events with structured details.

**Threshold:** 2 consecutive failures on tasks matching any of:
- Same `fallback_reason` (e.g., two `test_failure`s in a row)
- Same file-count tier (both >5 files)
- Overlapping file paths (>50% file overlap between failed tasks)

**Why 2, not 1:** A single failure is noise — Codex legitimately fails on edge cases. Two consecutive failures on structurally similar tasks indicates a systematic mismatch, not bad luck. The circuit breaker already handles the "everything is broken" case at 3 failures; this catches the "this category is broken" case earlier.

**False positive risk:** MODERATE. Two unrelated tasks could share file-count tier by coincidence. Mitigation: require at least two matching characteristics (e.g., same tier AND same fallback_reason), not just one. Also, rerouting to Claude is always safe (just slower/more expensive), so the cost of a false positive is wasted tokens, not incorrect behavior.

**Detection implementation:** After each `output_result` call in the wrapper, append a typed failure record to a rolling window file (last 5 task results). Before dispatching the next task, a `check_signals()` function reads this window and pattern-matches. Total: ~15 lines bash + ~30 lines node for the matcher.

---

### Signal 2: Context Degradation

**What:** Across sequential tasks in a wave, Codex is consuming increasing tokens per task while task complexity stays flat. This indicates context pollution — prior task residue, growing capsule sizes, or the model struggling to focus.

**Data source:** `write_ledger()` records `input_tokens`, `output_tokens`, `elapsed_ms` per task. The token ledger SQLite DB (`~/.cortex/token-ledger.db`) stores all entries indexed by `task_id`. Event log JSONL records `step_count` on completion.

**Threshold:** Token consumption increasing >2x between tasks of comparable complexity (same file-count tier, same plan). Specifically:

```
task_n.input_tokens > 2.0 * median(task_1..task_(n-1)).input_tokens
  AND task_n.file_count <= median(task_1..task_(n-1)).file_count * 1.5
```

The second condition ensures we're comparing like with like — a 10-file task legitimately uses more tokens than a 2-file task.

**Why 2x:** Normal variance in Codex token usage is ~30-50% for similar tasks. A 2x spike with no complexity increase is a strong signal. Below 2x, we'd be flagging normal variation.

**False positive risk:** LOW-MODERATE. A legitimately harder task within the same file-count tier could trigger this (e.g., 3 files but one is 2000 lines). Mitigation: only trigger when 2+ consecutive tasks show the upward trend, not a single spike. Single spikes get logged but don't trigger action.

**Detection implementation:** Query the ledger after each task completion:
```sql
SELECT input_tokens, output_tokens, elapsed_ms
FROM codex_tasks
WHERE phase = ? AND plan_file = ?
ORDER BY rowid DESC LIMIT 5;
```
Compare latest entry against rolling median. ~20 lines SQL + node.

---

### Signal 3: Timeout Patterns

**What:** Tasks consistently hitting the wall-clock timeout, suggesting the timeout tier is wrong for the task category or the approach itself is flawed.

**Data source:** `fallback_reason: "timeout"` in `output_result`. Exit code 124. `elapsed_ms` in ledger. `timeout` value from `task_started` event.

**Threshold:** 2 timeouts in the same plan. OR 1 timeout where `elapsed_ms > 0.95 * timeout_ms` (near-miss) followed by 1 actual timeout.

**Why this compound threshold:** A single timeout might be a one-off (network hiccup, model latency spike). Two timeouts in the same plan means the timeout calculation is systematically wrong for this workload. Near-misses (>95% of budget consumed) are leading indicators — the task barely finished and the next one probably won't.

**False positive risk:** LOW. Timeouts are unambiguous failure signals. The only false positive scenario is two genuinely complex tasks that happen to be in the same plan but are dissimilar — adjusting the timeout for subsequent tasks is still the correct response.

**Detection implementation:** Count `fallback_reason=timeout` entries in the rolling window. Check `elapsed_ms / (timeout * 1000)` ratio for near-misses. ~10 lines.

---

### Signal 4: Test Failure Patterns

**What:** The same test (or test file) fails across multiple tasks, suggesting an architectural issue — not a task-level bug that Codex can fix in isolation.

**Data source:** `fallback_reason: "test_failure"` in `output_result`. The `result_json` content from Codex's structured output, which should contain test output or at minimum the test command and its exit status. If Codex's task capsule includes `<verify>` commands, the specific test command is known.

**Threshold:** Same test file failing in 2+ tasks. OR any test failure where the failing test is NOT in the task's `<files>` list (the task broke something it wasn't supposed to touch).

**Why these two conditions:** Condition 1 catches systemic issues (e.g., a shared fixture is broken, an API contract changed). Condition 2 catches blast-radius problems (task touched auth, but the payment test broke — something deeper is wrong).

**False positive risk:** MODERATE-HIGH for condition 2. Tasks can legitimately affect tests outside their file list through transitive dependencies. Mitigation: only escalate (don't reroute) — surface the pattern for human review rather than making an automated decision. For condition 1 (same test, 2+ tasks), false positive risk is LOW — this is a clear signal of a shared root cause.

**Detection implementation:** Requires parsing test output from `result_json`. This is the hardest signal to extract because test output format varies by framework. MVP approach: string-match test file names from stderr/stdout. Full approach: structured test result parsing (JUnit XML, jest JSON). Start with MVP. ~40 lines node.

---

### Signal 5: Step Count Inflation

**What:** Codex uses far more steps (turns) than expected for the task's complexity tier, indicating it's thrashing — making edits, reverting, retrying — rather than converging.

**Data source:** `STEP_COUNT` parsed from Codex JSONL (count of `turn.completed` events). `MAX_STEPS` calculated as `file_count * MAX_STEPS_MULTIPLIER` (default multiplier: 10). `task_started` event logs both `file_count` and `max_steps`.

**Threshold:** `step_count > 0.6 * max_steps` AND task not yet complete. This is the "yellow zone" — the iteration budget check at `step_count >= max_steps` is the "red zone" (already implemented). We want to detect thrashing before the hard budget kills the task.

**Secondary threshold:** `step_count > 3 * median_step_count` for completed tasks of similar file count. This catches tasks that technically finish but took way too long — they "succeeded" but the approach was wrong and future similar tasks will likely fail.

**Why 0.6x:** The iteration budget (max_steps) is set generously — `file_count * 10` means a 3-file task gets 30 steps. If Codex has used 18 steps on a 3-file task and isn't done, something is wrong. Normal completion for a 3-file task should be 5-10 steps.

**False positive risk:** LOW for the 0.6x threshold (it's generous). MODERATE for the 3x-median threshold on completed tasks — some tasks are legitimately harder. Mitigation: log and annotate but don't block completion. Use the data to inform routing of future similar tasks.

**Detection implementation:** This signal can only be detected DURING execution (not post-hoc) for the 0.6x threshold. The current architecture checks step count only AFTER Codex exits. To detect mid-task, we'd need to tail the JSONL during execution — this conflicts with the <100ms latency constraint. **Practical compromise:** detect post-hoc only. If a task completes but used >0.6x budget, annotate the next similar task's capsule with a warning. If a task hits the budget, the existing `iteration_budget_exceeded` fallback handles it. The 3x-median check is purely post-hoc and fits naturally.

---

### Signal 6: Token Cost Anomaly

**What:** A single task consumes a disproportionate share of the expected phase budget.

**Data source:** `cost_usd` from `write_ledger()`. Phase budget derived from: `task_count * median_expected_cost_per_task`. The `codex_tasks` table in the ledger has all historical data needed.

**Threshold:** Single task `cost_usd > 0.3 * estimated_phase_budget`. Estimated phase budget = `total_tasks_in_plan * $0.15` (empirical median for o4-mini Codex tasks at $1.10/$4.40 per 1M input/output).

**Why 0.3x:** A plan with 8 tasks has an expected budget of ~$1.20. If one task costs $0.36+, that's a problem — it consumed almost a third of the budget and there are 7 more tasks to go. This threshold is intentionally sensitive because cost anomalies often indicate thrashing (Signal 5) or context degradation (Signal 2) — catching the cost symptom catches the underlying cause.

**False positive risk:** LOW-MODERATE. Legitimately complex tasks (high file count, TDD with many test iterations) can be expensive. Mitigation: adjust threshold by task complexity tier:
- Tasks with <3 files: threshold at 0.2x phase budget
- Tasks with 3-5 files: threshold at 0.3x phase budget
- Tasks with >5 files: threshold at 0.5x phase budget

**Detection implementation:** After `write_ledger()`, query cumulative spend:
```sql
SELECT SUM(cost_usd) as total, COUNT(*) as completed
FROM codex_tasks WHERE phase = ? AND plan_file = ?;
```
Compare `latest_task_cost / (estimated_total - cumulative_so_far)` to detect budget exhaustion trajectory. ~15 lines.

---

## Adaptation Action Space

### Action 1: Reroute Task

**What:** Move a task from Codex to Claude (or theoretically vice versa, but Codex-to-Claude is the primary direction). The task-router classification is overridden at runtime.

**Mechanism:** The `output_result` already returns `status: "fallback"` which triggers Claude execution in the orchestrator. Adaptive rerouting extends this: before dispatching a task to Codex, check the signal state. If signals indicate Codex will struggle, emit `status: "fallback"` with `fallback_reason: "adaptive_reroute"` without invoking Codex at all.

**Reversibility:** FULLY REVERSIBLE. The reroute only affects the current task. Future tasks can still be sent to Codex. The circuit breaker file is not incremented (this is an adaptive decision, not a failure).

**Side effects:** Higher token cost (Claude is more expensive than Codex for simple tasks). Slight latency increase. No data loss.

**Pre-requisite:** The execute-plan orchestrator must accept `adaptive_reroute` as a fallback reason and handle it identically to other fallbacks.

---

### Action 2: Adjust Timeout

**What:** Increase the timeout for subsequent tasks in the same plan when timeout patterns are detected.

**Mechanism:** Write an override file (`/tmp/gsd-codex-timeout-override-{plan}`) containing the new timeout value. `codex-exec-wrapper.sh` reads this file before calculating timeout, using it as a floor. Formula: `new_timeout = current_tier_timeout * 1.5`, capped at 600s (hard maximum to prevent runaway sessions).

**Reversibility:** FULLY REVERSIBLE. The override file is per-plan and cleaned up at plan completion. Does not affect other plans or future waves.

**Side effects:** Longer wall-clock time per task. Higher potential cost if the timeout increase masks a deeper problem. Mitigated by: only one escalation allowed per plan (300->450 or 450->600, not 300->600->900).

---

### Action 3: Pause Wave

**What:** Stop dispatching new tasks. Write a signal file that surfaces the current state for human review.

**Mechanism:** Write `.cortex/events/{phase}-{plan}-PAUSED.json` containing:
```json
{
  "reason": "adaptive_pause",
  "signals": [...triggered signals...],
  "tasks_completed": N,
  "tasks_remaining": M,
  "recommendation": "...",
  "timestamp": "..."
}
```
The execute-plan orchestrator checks for this file before dispatching the next task. Log to `supervisor.jsonl`.

**Reversibility:** FULLY REVERSIBLE. Human deletes the pause file (or runs a resume command) and execution continues from where it stopped.

**Side effects:** Blocks progress until human intervenes. This is the correct behavior when the system lacks confidence, but it shouldn't trigger on minor signals. Reserved for compound signals (2+ signals active simultaneously).

---

### Action 4: Escalate to Drive

**What:** Break out of GSD execution entirely. Return control to `cortex-drive` for re-evaluation of the approach — the plan might need restructuring, the spec might have a gap, or the phase strategy might be wrong.

**Mechanism:** Write `.cortex/events/ESCALATION.json` with full context. The `gsd:execute-phase` skill checks for this file and aborts with a structured message directing the user (or cortex-drive) to re-evaluate.

**Reversibility:** PARTIALLY REVERSIBLE. The phase can be re-executed, but any in-progress wave state is lost. Completed tasks are preserved (their commits are merged). This is the most disruptive action — it should only trigger when the evidence is strong that continuing execution is wasteful.

**Side effects:** Loss of wave momentum. Potential need to re-plan. Time cost of re-evaluation. But: prevents the worse outcome of burning through an entire phase producing garbage.

---

### Action 5: Annotate Task

**What:** Add context from prior failures to the next task's capsule. This is the lightest-touch adaptation — it doesn't change routing or timing, just gives Codex better information.

**Mechanism:** Before generating the task capsule from the template, check the rolling failure window. If prior tasks failed with relevant information (same files, same test failures), inject a `## Prior Failure Context` section into the capsule:

```markdown
## Prior Failure Context

Task T2 failed on these files with: test_failure
- Error: `TypeError: Cannot read property 'id' of undefined` in auth.test.js
- Approach attempted: direct property access without null check
- This suggests: the user object may be undefined in the test fixture

Avoid repeating this approach.
```

**Reversibility:** FULLY REVERSIBLE. The annotation only affects the capsule for one task. It's additive information, not a constraint.

**Side effects:** Slightly larger capsule (more input tokens). Risk of anchoring Codex on the wrong hypothesis if the prior failure analysis is incorrect. Mitigation: keep annotations factual (what failed, what error), not interpretive (why it failed).

---

### Action 6: Skip Task

**What:** Defer a task — move it out of the current wave and either: (a) push to the next wave, (b) mark for manual handling, or (c) mark as blocked pending resolution of the issue that caused the skip.

**Mechanism:** `output_result "skipped" "adaptive_skip"`. The orchestrator removes the task from the current dispatch queue and appends it to a `deferred-tasks.json` file in `.cortex/events/`. On next wave or plan execution, deferred tasks are re-evaluated.

**Reversibility:** FULLY REVERSIBLE. The task is not deleted, just deferred. It can be picked up in any future wave or manually executed.

**Side effects:** Dependencies. If task T5 depends on T3 and T3 is skipped, T5 will fail or produce wrong output. The skip action must check the task dependency graph (if one exists in the plan) before skipping. If no dependency info exists, skip is only safe for independent tasks.

---

## Decision Matrix

| Signal | Threshold | Primary Action | Secondary Action | Reversible? | Confidence |
|--------|-----------|---------------|-----------------|-------------|------------|
| **S1: Task-type failure** | 2 consecutive failures on tasks with 2+ shared characteristics | Reroute remaining same-type tasks to Claude | Annotate next task with failure context | Yes | HIGH — structurally similar failures are predictive |
| **S2: Context degradation** | Token usage >2x median for same-tier tasks, 2+ consecutive | Pause wave for human review | Annotate next task with "context may be degraded" warning | Yes | MODERATE — legitimate complexity spikes possible |
| **S3: Timeout pattern** | 2 timeouts in same plan, OR 1 near-miss + 1 timeout | Adjust timeout +50% (once per plan) | If already adjusted: reroute remaining tasks | Yes | HIGH — timeouts are unambiguous |
| **S4: Test failure pattern** | Same test failing in 2+ tasks | Escalate to drive (architectural issue) | Pause wave if escalation not warranted | Partial | HIGH — cross-task test failures indicate shared root cause |
| **S5: Step count inflation** | Completed task used >3x median steps for tier | Annotate next similar task | If 2+ inflated tasks: reroute type to Claude | Yes | MODERATE — some tasks legitimately harder |
| **S6: Token cost anomaly** | Single task >30% of estimated phase budget | Pause wave | Annotate + adjust timeout | Yes | MODERATE — complexity variance is real |

### Compound Signal Rules

When multiple signals fire simultaneously, escalate faster:

| Compound Signal | Action |
|----------------|--------|
| S1 + S5 (failure + inflation) | Reroute immediately, do not attempt even 1 more Codex task of that type |
| S3 + S6 (timeout + cost anomaly) | Pause wave — the plan's complexity estimates are wrong |
| S4 + any other signal | Escalate to drive — architectural issue confirmed by corroborating evidence |
| S2 + S5 + S6 (degradation + inflation + cost) | Escalate to drive — execution environment is unhealthy |
| 3+ signals active simultaneously | Always pause wave regardless of which signals |

---

## Hook Point Architecture

Where does the detection logic run? Three candidate hook points, evaluated:

### Option A: Inside `codex-exec-wrapper.sh` (post-task)
- **Pro:** All raw data is available (JSONL, exit codes, tokens). Already has `log_event()` and `record_failure()`.
- **Pro:** Zero new files — extends existing script.
- **Con:** Can only detect post-task, not mid-task. Cannot make pre-dispatch decisions for the NEXT task.
- **Verdict:** Use for signal RECORDING. Every signal data point gets logged here.

### Option B: Pre-dispatch check in the orchestrator (between tasks)
- **Pro:** Can read accumulated signals before deciding to dispatch next task. Natural point for reroute/skip/pause decisions.
- **Con:** The orchestrator is in the GSD layer, not the Cortex layer. Writing Cortex logic into GSD violates the ownership boundary.
- **Verdict:** Use for signal CONSUMPTION via a file-based interface. The orchestrator reads a signal state file; Cortex writes it.

### Option C: Dedicated `check-signals.js` script called between tasks
- **Pro:** Clean separation. Orchestrator calls `check-signals.js` before each dispatch, gets back a decision JSON.
- **Pro:** Testable in isolation.
- **Con:** One more script in the pipeline. Adds ~50ms per task.
- **Verdict:** PREFERRED. This is the clean architecture. The latency is well under the 100ms budget.

**Chosen architecture:**

```
codex-exec-wrapper.sh          check-signals.js            orchestrator
        |                            |                          |
  [task completes]                   |                          |
        |                            |                          |
  log_event() ──────> .cortex/events/{phase}-{plan}.jsonl       |
  write_ledger() ──> token-ledger.db                            |
        |                            |                          |
        |                     [next task ready]                 |
        |                            |                          |
        |                   read events + ledger                |
        |                   evaluate 6 signals                  |
        |                   return decision JSON ──────────────>|
        |                            |                   [dispatch/reroute/
        |                            |                    pause/skip/escalate]
```

Decision JSON format:
```json
{
  "action": "dispatch" | "reroute" | "pause" | "skip" | "escalate",
  "reason": "S1: 2 consecutive test_failure on 5+ file tasks",
  "signals_active": ["S1", "S5"],
  "confidence": 0.85,
  "annotation": "Prior task T3 failed with: ...",
  "timeout_override": null | 450
}
```

---

## Minimum Viable Adaptation (MVP)

### One signal: S1 — Task-type failure pattern

Chosen because:
- Highest confidence signal (structurally similar failures are strongly predictive)
- Data already exists (event log, fallback_reason, task classification)
- The circuit breaker proves the pattern works — this just makes it smarter (type-aware instead of global)

### One action: Reroute to Claude

Chosen because:
- Already implemented as fallback path (the orchestrator handles `status: "fallback"`)
- Fully reversible
- Zero new infrastructure
- The only cost is higher token spend — no risk of data loss or execution corruption

### One hook point: `check-signals.js` called pre-dispatch

### MVP Implementation Spec

**File:** `scripts/cortex/check-signals.js`

**Input:** 
```
node check-signals.js <event-log-path> <next-task-json>
```

**Logic (pseudocode):**
```
1. Read last 5 events from {phase}-{plan}.jsonl
2. Filter to failures (task_failed, budget_exceeded, timeout)
3. Extract characteristics: fallback_reason, file_count, file_overlap
4. Compare next-task characteristics to failure characteristics
5. If 2+ failures match next-task on 2+ characteristics:
     → output { action: "reroute", reason: "...", ... }
6. Else:
     → output { action: "dispatch" }
```

**Integration point:** Before `codex-exec-wrapper.sh` is invoked, the orchestrator calls `check-signals.js`. If it returns `reroute`, the orchestrator skips Codex and routes directly to Claude.

**Changes required:**
1. New file: `scripts/cortex/check-signals.js` (~80 lines)
2. Modify: `codex-exec-wrapper.sh` — enhance `log_event("task_failed", ...)` to include file list and fallback_reason in the event details (currently only logs `fallback_reason` and `exit_code` for `task_failed`)
3. Modify: orchestrator (GSD side) — add `check-signals.js` call before Codex dispatch. This is a ~5 line change: call script, check action field, skip wrapper if reroute.

**Estimated effort:** 2-3 hours for implementation + tests.

**What it catches that the circuit breaker doesn't:** The circuit breaker trips after 3 failures of ANY kind. The MVP catches 2 failures of the SAME kind and only reroutes that category. Example: tasks T1 (3 files, auth) and T2 (3 files, auth) both fail with test_failure. T3 (2 files, utility) is Codex-safe and should still go to Codex. T4 (4 files, auth) should be rerouted. The circuit breaker would let T3 and T4 both attempt Codex. The MVP would reroute T4 but not T3.

---

## Post-MVP Roadmap

| Phase | Adds | Depends On |
|-------|------|-----------|
| MVP | S1 (task-type failure) + Reroute | Event log enhancement |
| V2 | S3 (timeout) + Adjust Timeout | MVP (same hook point) |
| V3 | S5 (step inflation) + Annotate | MVP + ledger query |
| V4 | S6 (cost anomaly) + Pause | V3 (needs cost tracking) |
| V5 | S2 (context degradation) + Pause | V4 (needs trend analysis) |
| V6 | S4 (test failure pattern) + Escalate | All above (needs test output parsing) |
| V7 | Compound signal rules | V6 (all signals online) |

Each phase is independently shippable and backward compatible. Projects without `check-signals.js` fall through to the existing static routing.

---

## What Would Change My Mind

- **If Codex failure patterns are truly random** (no correlation between task characteristics and failure), then S1 is useless. To test: analyze historical `codex_tasks` ledger data for clustering. If failures are uniformly distributed across task types, S1 has no signal.
- **If the <100ms latency budget is too tight** for `check-signals.js`, the logic could move into `codex-exec-wrapper.sh` itself as a pre-flight check, eliminating the subprocess overhead.
- **If the GSD orchestrator cannot be modified** to call `check-signals.js`, the entire system must be advisory-only: log recommendations to a file that a human reads between waves.
- **If false positives on S1 cause Claude overuse** (>30% cost increase with no quality improvement), tighten the threshold from 2 to 3 matching failures, or require 3 shared characteristics instead of 2.
