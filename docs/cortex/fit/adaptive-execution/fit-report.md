# Fit Report: adaptive-execution

<!-- ART-FIT: Fit Report Template — produced by /cortex-fit -->
<!-- SC2 forced-separation: each section must not repeat content from any other section -->

**Slug:** adaptive-execution
**Timestamp:** 20260407T020000Z
**Evaluated against:** Cortex execution layer (codex-exec-wrapper.sh, task-router.js, GSD execute-plan orchestrator, circuit breaker, supervisor)
**Confidence:** high (3 research dossiers + external research exist)
**Status:** pending-human-decision

---

## Tech Radar Ring

**Ring:** Trial

**Justification:** Rich post-completion signals exist but feed only into accounting — the MVP closes the observation→action loop with zero GSD changes.

---

## Gap

The execution layer has **no pattern-aware failure response**. Specific gaps:

1. **No task-type tracking across failures.** The circuit breaker counts all failures identically. Two timeouts on TDD tasks with >5 files and one crash on a 1-file config task all increment the same counter — the breaker trips and blocks the config task that would have succeeded.

2. **No signal aggregation.** Post-completion data (token counts, step counts, elapsed time, failure reasons, file patterns) flows into the token ledger for accounting but is never read back for routing decisions. The event log (`.cortex/events/`) is append-only with zero consumers.

3. **No pre-dispatch intelligence.** Before dispatching a Codex task, the wrapper checks only the global circuit breaker. It has no awareness of "tasks with these characteristics have been failing."

4. **No error classification.** All failures are treated as equivalent. No distinction between transient errors (timeout on a legitimately complex task), permanent errors (Codex can't handle TDD with auth patterns), and impossible errors (wrong approach entirely).

---

## Overlap

1. **Circuit breaker (existing, codex-exec-wrapper.sh lines 421-433).** Adaptive execution's rerouting overlaps with the circuit breaker's fallback behavior. Both return `status: "fallback"` to the execute-plan orchestrator. The difference: the breaker is a global kill switch (3 strikes = all Codex blocked), while adaptive execution is a targeted reroute (specific task types blocked, others proceed). They coexist — adaptive fires first (at 2 matching failures), breaker fires if adaptation doesn't catch it (at 3 total).

2. **Per-task fallback in execute-plan (existing, Step 5a).** GSD already handles individual task fallback when the wrapper returns `fallback` status. The execute-plan orchestrator moves the failed task to `claude_tasks[]`. Adaptive execution uses this same path — it doesn't add a new fallback mechanism, it adds a new *reason* for triggering the existing one.

3. **Supervisor JSONL (existing, `.cortex/supervisor.jsonl`).** The supervisor logs hook invocations. Adaptive execution would emit its own events to `.cortex/exec-signals.jsonl`. These are separate concerns (supervisor tracks hook health, signals track task execution patterns) but both are JSONL event stores.

---

## Unique Contribution

**Predictive rerouting based on task characteristic clustering.** No existing Cortex component does this. The circuit breaker is reactive (fires after N failures). The task router is static (classifies once, never reclassifies). Adaptive execution is the first component that would observe a pattern ("TDD tasks with >5 files are failing") and proactively reroute remaining matching tasks before they fail.

This is the "smoke detector vs fire alarm" distinction from the clarify brief. The circuit breaker is the fire alarm (reacts after damage). Adaptive execution is the smoke detector (reacts to early signals). No other component in the Cortex or GSD stack fills this role.

---

## Conflict

1. **GSD ownership boundary.** Cortex's hard rule: "Cortex does not write to .planning/ except via /cortex-bridge. GSD owns execution." Adaptive execution modifies behavior *during* GSD execution by intercepting Codex dispatch in the wrapper. This technically stays within the boundary (the wrapper is a Cortex script, not a GSD artifact), but it influences GSD's task routing indirectly. **Mitigation:** The wrapper returns the same `fallback` status that GSD already handles. GSD's orchestrator makes the final routing decision, not the wrapper. The boundary is respected in spirit — Cortex provides a signal, GSD acts on it.

2. **Signal file as shared state.** The proposed `.cortex/exec-signals.jsonl` is written by the wrapper (Cortex) and read by `check-signals.js` (Cortex), but its effects are consumed by execute-plan (GSD). This creates an implicit coupling. **Mitigation:** The coupling is one-way and uses the existing fallback interface. GSD never reads the signal file — it only sees `status: "fallback"` from the wrapper, which it already handles.

3. **False positive risk.** If the signal detection is too aggressive, it could reroute tasks that would have succeeded on Codex. This wastes Claude tokens (more expensive) and slows execution (Claude is sequential, Codex is parallel). **Mitigation:** The MVP threshold is conservative (2+ failures sharing 2+ characteristics). The reroute is safe (task still executes, just on Claude). And the signal file can be manually cleared to reset detection.

---

## Strategic Direction

**Alignment:** aligned

Adaptive execution moves toward autonomous execution quality — a stated owner objective ("Autonomous capability — cortex-drive can take a stash idea through to a closed slug without human intervention"). The owner-intent tradeoff preferences rank "correctness > speed" — adaptive rerouting prioritizes correct execution (via Claude) over fast execution (via Codex) when signals indicate failure patterns. The compound probability research (85% per-step = 19.7% over 10 steps) makes adaptive execution a mathematical necessity for autonomous multi-step execution.

---

## Pre-Populated Clarify Brief Fields

**Proposed goal:** During GSD execution, detect task-type failure patterns from accumulated signals and proactively reroute matching tasks to Claude before the circuit breaker trips — so that unrelated tasks continue on Codex while problematic task types get the attention they need.

**Constraints:**
- Must return the same `fallback` status that GSD already handles (zero GSD code changes for MVP)
- Must not add >100ms latency to task dispatch (file read, not network call)
- Must log all adaptation decisions to supervisor.jsonl for audit trail
- Must be backward compatible — projects without signal files continue to work unchanged
- GSD ownership boundary must be respected — Cortex provides signals, GSD acts on them

**Open questions:**
- Should the signal file be cleared between plans, between waves, or between phases?
- What's the right characteristic matching: file extension patterns only, or also file count + TDD flag + failure type combinations?
- Should adaptive rerouting be opt-in (disabled by default) or opt-out (enabled by default)?
- After MVP ships, should the error taxonomy (transient/permanent/impossible from external research) be the next signal to add?

---

## Human Decision

**Status:** pending-human-decision

To advance: change status to `approved` or `rejected` and add a one-line note.

- [ ] Approved — proceed to `/cortex-clarify adaptive-execution`
- [ ] Rejected — archive this report, no further action

**Decision note:** _(fill in when deciding)_
