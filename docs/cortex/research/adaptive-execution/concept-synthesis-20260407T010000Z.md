# Research Dossier: adaptive-execution — synthesis

**Slug:** adaptive-execution
**Phase:** concept (synthesis)
**Timestamp:** 20260407T010000Z
**Depth:** standard (3 parallel research agents)

---

## Executive Summary

The execution layer has rich signals (token counts, step counts, elapsed time, failure reasons) but nobody reads them for decision-making — they flow into the token ledger for accounting only. The circuit breaker treats all failures identically (3 strikes regardless of pattern). The task router classifies once at plan start and never reclassifies.

The MVP is small: enrich the wrapper's signal file after each task, add a pre-dispatch signal check that detects task-type failure clustering, and return `fallback` with reason `adaptive_reroute`. GSD's existing fallback path handles the rest — zero GSD code changes for the MVP.

---

## Finding 1: Current Execution Architecture

### Dispatch Flow

```
cortex-drive → /gsd:drive → execute-phase.md (waves)
                                → execute-plan.md (per plan)
                                    → task-router.js (ONCE, static)
                                    → for each codex_task:
                                        → codex-exec-wrapper.sh (one task)
                                        → if fallback: move to claude_tasks[]
                                    → gsd-executor (claude tasks)
```

**Key constraint:** Task classification happens once per plan, not per task. The router reads PLAN.md and outputs a static JSON array. No runtime reclassification exists.

### Signal Inventory

| Category | Available Signals | Currently Used For |
|----------|------------------|-------------------|
| Pre-dispatch | Circuit breaker count, file count, TDD flag, timeout tier | Circuit breaker check only |
| During execution | **None** — wrapper blocks until Codex exits | N/A |
| Post-completion | Exit code, elapsed_ms, token counts (in/out/cached/reasoning), step count, failure reason, result status, files changed, deviations | Token ledger accounting only. execute-plan reads status + fallback_reason for per-task fallback. |
| Event log | task_started, task_completed, task_failed, budget_exceeded, circuit_breaker | Append-only JSONL, never read back |

**The gap:** Rich post-completion signals exist but feed only into accounting. Nobody aggregates patterns across tasks to detect "Codex is struggling with this type of work."

### Circuit Breaker Limitation

The breaker increments on ANY failure regardless of type. A timeout on a complex 8-file task and a crash on a 1-file task both count equally. After 3 of either, ALL Codex tasks are blocked — even unrelated simple tasks that would succeed. There is no per-type tracking.

---

## Finding 2: Adaptation Hook Points

Six hook points analyzed, ranked by feasibility:

| Hook Point | Location | Feasibility | GSD Changes? |
|------------|----------|-------------|-------------|
| **C: Pre-dispatch signal check** | Wrapper lines 422-433, before circuit breaker | **Best — MVP** | None |
| **E: Post-task signal emission** | Wrapper after JSONL parsing, before failure handling | **Best — MVP** | None |
| **F: PostToolUse hook** | Cortex hook fires after Bash calls | Good — clean but higher latency | None |
| **B: Between tasks in execute-plan** | execute-plan.md Step 5a loop | Good — most powerful | Yes (GSD) |
| **D: Between waves** | execute-phase.md between wave dispatches | Moderate — coarse | Yes (GSD) |
| **A: Inside wrapper task loop** | N/A — wrapper handles ONE task | Impossible — no loop | N/A |

**MVP uses C + E:** Enrich signal emission after each task (E), check accumulated signals before next dispatch (C). Both are inside `codex-exec-wrapper.sh`. No GSD changes.

---

## Finding 3: Signal Detection Design

Six early warning signals with concrete thresholds:

| # | Signal | Threshold | Source | False Positive Risk |
|---|--------|-----------|--------|-------------------|
| S1 | **Task-type failure clustering** | 2 failures on tasks sharing 2+ characteristics (file patterns, TDD flag, file count tier) | Accumulated signal file | Low — characteristic matching is specific |
| S2 | Context degradation | Token usage >2x median for same-tier tasks, 2+ consecutive | Token counts from output_result | Moderate — legitimate complexity can inflate tokens |
| S3 | Timeout pattern | 2 timeouts or 1 near-miss (>80% of limit) + 1 timeout | Elapsed_ms + timeout tier | Low — timeouts are unambiguous |
| S4 | Test failure pattern | Same test name failing across 2+ tasks | Test output from result JSON | High signal — architectural issue, not task-level |
| S5 | Step count inflation | >3x median steps for same-tier completed tasks | Step count from JSONL parsing | Moderate — novel tasks legitimately take more steps |
| S6 | Token cost anomaly | Single task >30% of estimated phase budget | Cost_usd from output_result | Low — clear outlier |

### MVP Signal: S1 (Task-Type Failure Clustering)

Why S1 first: it catches what the circuit breaker misses. If Codex fails on two tasks that both touch `.test.ts` files with >5 files, the remaining `.test.ts` tasks should reroute to Claude immediately — without tripping the global breaker and blocking unrelated tasks.

---

## Finding 4: Adaptation Action Space

| # | Action | When to use | Reversible? | GSD changes? |
|---|--------|------------|-------------|-------------|
| A1 | **Reroute task to Claude** | Task matches failed pattern | Yes (task still executes) | None — uses existing fallback |
| A2 | Adjust timeout | Near-miss timeouts on legitimate work | Yes | None — env var override |
| A3 | Pause wave | Multiple signals firing simultaneously | Yes — resume on command | Would need GSD signal |
| A4 | Escalate to drive | Systemic failure beyond task routing | Partially — drive decides next | Breaks out of GSD loop |
| A5 | Annotate next task | Prior failure provides useful context | Yes | Capsule modification |
| A6 | Skip task | Task is consistently unfixable | Yes — defer to manual | Move to skip list |

### MVP Action: A1 (Reroute to Claude)

Why A1 first: the fallback path already exists in execute-plan. The wrapper returning `status: "fallback"` with `fallback_reason: "adaptive_reroute"` triggers the same handling as any other Codex failure. GSD moves the task to claude_tasks[]. Zero new code on the GSD side.

---

## Finding 5: MVP Architecture

### Three components, file-based interface

```
codex-exec-wrapper.sh                   check-signals.js (NEW)
  │                                          │
  │ After each task:                         │ Before each task:
  │ Append to .cortex/exec-signals.jsonl     │ Read .cortex/exec-signals.jsonl
  │ {task_id, file_patterns, outcome,        │ Evaluate S1: task-type clustering
  │  elapsed_ms, tokens, failure_type}       │ If match: return "reroute"
  │                                          │ Else: return "proceed"
  └──────────────────────────────────────────┘
                    │
                    ▼
          execute-plan.md (unchanged)
          Sees: status="fallback", reason="adaptive_reroute"
          Does: moves task to claude_tasks[] (existing behavior)
```

### Signal file schema (.cortex/exec-signals.jsonl)

```json
{
  "ts": "20260407T010000Z",
  "plan": "23-01",
  "task_id": "3",
  "task_name": "Write auth middleware tests",
  "file_patterns": [".test.ts", "auth"],
  "file_count": 6,
  "tdd": true,
  "timeout_tier": "180s",
  "outcome": "fallback",
  "failure_type": "test_failure",
  "elapsed_ms": 145000,
  "tokens": {"input": 12000, "output": 8500},
  "step_count": 42
}
```

### check-signals.js logic (MVP — ~80 lines)

```
1. Read all entries from .cortex/exec-signals.jsonl for current plan
2. Group failed entries by characteristic tuples:
   - (file_pattern, tdd_flag)
   - (file_pattern, file_count_tier)
   - (failure_type, file_pattern)
3. For any group with 2+ failures:
   - Check if the CURRENT task shares 2+ characteristics with that group
   - If match: return { decision: "reroute", reason: "task-type failure clustering", matching_pattern: [...] }
4. Else: return { decision: "proceed" }
```

### Wrapper integration (2 insertion points)

**Signal emission (after line 608, on success):**
```bash
# Emit enriched signal for adaptive execution
emit_signal "$TASK_ID" "$TASK_NAME" "$FILE_PATTERNS" "$FILE_COUNT" "$TDD" "$TIMEOUT" "complete" "null" "$ELAPSED_MS" "$INPUT_TOKENS:$OUTPUT_TOKENS" "$STEP_COUNT"
```

**Signal emission (in each failure handler — timeout, crash, test_failure, parse_error, budget_exceeded):**
```bash
emit_signal "$TASK_ID" "$TASK_NAME" "$FILE_PATTERNS" "$FILE_COUNT" "$TDD" "$TIMEOUT" "fallback" "$FAILURE_REASON" "$ELAPSED_MS" "$INPUT_TOKENS:$OUTPUT_TOKENS" "$STEP_COUNT"
```

**Pre-dispatch check (before circuit breaker check, ~line 420):**
```bash
# Adaptive execution check (before circuit breaker)
if [[ -f "$SIGNAL_CHECK" ]]; then
  ADAPTIVE=$(node "$SIGNAL_CHECK" "$PLAN_ID" "$TASK_JSON" 2>/dev/null)
  if [[ "$(echo "$ADAPTIVE" | jq -r '.decision')" == "reroute" ]]; then
    REASON=$(echo "$ADAPTIVE" | jq -r '.reason')
    log_event "adaptive_reroute" "{\"reason\":\"$REASON\"}"
    output_result "fallback" "adaptive_reroute"
    exit 0
  fi
fi
```

### Estimated effort

| Component | Lines of code | Effort |
|-----------|-------------|--------|
| `scripts/cortex/check-signals.js` | ~80 | Small |
| Wrapper signal emission (emit_signal function) | ~20 | Tiny |
| Wrapper pre-dispatch check | ~10 | Tiny |
| Signal emission calls (6 failure handlers + 1 success) | ~14 (2 lines each) | Tiny |
| Test coverage | ~40 | Small |
| **Total** | **~165 lines new/modified** | **Small-Medium** |

---

## Revised Task Map

### Must-Do

| # | Task | Files | Effort |
|---|------|-------|--------|
| 1 | Create `scripts/cortex/check-signals.js` (S1 detection) | New file | Small |
| 2 | Add `emit_signal` function to codex-exec-wrapper.sh | Existing file | Tiny |
| 3 | Add signal emission calls to all 7 outcome paths | Existing file | Small |
| 4 | Add pre-dispatch adaptive check before circuit breaker | Existing file | Tiny |
| 5 | Add `adaptive_reroute` event type to execution-event schema | `schemas/execution-event.schema.json` | Tiny |
| 6 | Write tests for signal detection + rerouting | New test file | Small |

### Should-Do

| # | Task | Effort |
|---|------|--------|
| 7 | Add S3 (timeout pattern) detection to check-signals.js | Small |
| 8 | Add S4 (test failure pattern) detection | Small |
| 9 | Log adaptive decisions to supervisor.jsonl | Tiny |
| 10 | Add signal file rotation (clear between plans) | Tiny |

### Defer

| # | Task | Reason |
|---|------|--------|
| 11 | S2 (context degradation) | Requires baseline median calculation |
| 12 | S5/S6 (step count inflation, cost anomaly) | Need more execution data for calibration |
| 13 | Mid-wave rerouting (GSD changes) | MVP works without GSD changes |
| 14 | A3 (pause wave) | Requires GSD signal protocol |
| 15 | A4 (escalate to drive) | Requires breaking GSD execution loop |

---

## Open Questions Resolved

> "Where does the adaptation logic live?"
**Answer:** In the wrapper (`codex-exec-wrapper.sh`) for signal emission and pre-dispatch check. In a new `check-signals.js` for pattern evaluation. File-based interface (`.cortex/exec-signals.jsonl`) between them.

> "How does Cortex influence GSD without violating the boundary?"
**Answer:** The wrapper returns `status: "fallback"` with `reason: "adaptive_reroute"`. GSD's execute-plan handles this identically to any other Codex failure — moves the task to claude_tasks[]. Zero GSD code changes.

> "What early warning signals exist before circuit breaker trips?"
**Answer:** Task-type failure clustering (S1), timeout patterns (S3), test failure patterns (S4). These fire after 2 matching failures, before the global breaker fires at 3.

> "Should adaptation be automatic or advisory?"
**Answer:** Automatic for MVP. The reroute is safe (task still executes, just on Claude). Advisory mode could be added later for higher-risk actions (pause wave, escalate).

> "Is mid-wave adaptation possible with current architecture?"
**Answer:** For rerouting: yes, via the existing fallback path in the wrapper. For task reordering or wave pausing: no, requires GSD orchestrator changes (deferred).

> "What's the minimum viable adaptation?"
**Answer:** S1 (task-type failure clustering) + A1 (reroute to Claude) + check-signals.js (~80 lines) + wrapper changes (~45 lines). Total ~165 lines.

---

## Sources

### Internal
- `scripts/cortex/codex-exec-wrapper.sh` (614 lines) — full signal inventory, dispatch flow
- `scripts/cortex/task-router.js` (206 lines) — static classification, no runtime reclassification
- `upstream/gsd/commands/gsd/execute-plan.md` — Codex task loop with fallback handling
- `upstream/gsd/commands/gsd/execute-phase.md` — wave orchestration
- `.cortex/supervisor.jsonl` — 258 events, hook_fire only, no task-level data
- `.cortex/events/23-01.jsonl` — 0 bytes (no Codex executions recorded)

### Design
- `docs/cortex/research/adaptive-execution/design-20260406T-signals-actions.md` — complete signal/action matrix with thresholds
