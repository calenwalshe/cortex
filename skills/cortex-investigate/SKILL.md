# Cortex Investigate — Systematic Debugging

Combined protocol from Superpowers (4-phase TDD debugging) and GStack (/investigate with Iron Law, scope lock, structured reports).

## User-invocable
When the user types `/cortex-investigate`, run this skill.
Also trigger when: "debug this", "fix this bug", "why is this broken", "investigate this error", "root cause analysis".

## The Iron Law

**NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.**

If you haven't completed Phase 1, you CANNOT propose fixes. Period.

## Instructions

### Phase 1: Root Cause Investigation

**BEFORE attempting ANY fix:**

1. **Read error messages carefully.** Don't skip past them. Read stack traces completely. Note line numbers, file paths, error codes. They often contain the exact solution.

2. **Reproduce consistently.** Can you trigger it reliably? What are the exact steps? If not reproducible, gather more data — don't guess.

3. **Check recent changes:**
   ```bash
   git log --oneline -20 -- <affected-files>
   git diff HEAD~5 -- <affected-files>
   ```

4. **Gather evidence in multi-component systems.** Before proposing fixes, add diagnostic instrumentation at each component boundary. Log what enters and exits each layer. Run once to find WHERE it breaks, THEN investigate that specific component.

5. **Trace data flow.** Where does the bad value originate? Keep tracing upstream until you find the source. Fix at source, not at symptom.

**Output:** "Root cause hypothesis: [specific, testable claim about what is wrong and why]"

### Scope Lock

After forming your hypothesis, identify the narrowest directory containing affected files. Restrict your edits to that directory for the duration of this debug session. This prevents "while I'm here" scope creep that introduces new bugs.

Tell the user: "Edits restricted to `<dir>/` for this debug session."

### Phase 2: Pattern Analysis

Check if this bug matches known patterns before going deeper:

| Pattern | Signature | Where to Look |
|---------|-----------|---------------|
| Race condition | Intermittent, timing-dependent | Concurrent shared state |
| Nil/null propagation | NoMethodError, TypeError | Missing guards on optionals |
| State corruption | Inconsistent data, partial updates | Transactions, callbacks |
| Integration failure | Timeout, unexpected response | External API boundaries |
| Configuration drift | Works locally, fails in prod | Env vars, feature flags |
| Stale cache | Shows old data, fixes on clear | Redis, CDN, browser cache |

Also check:
- `git log` for prior fixes in the same area — recurring bugs = architectural smell
- Web search for "{framework} {sanitized error type}" (strip sensitive data first)

### Phase 3: Hypothesis Testing

1. **Form ONE hypothesis:** "I think X is the root cause because Y" — write it down.
2. **Test minimally.** Make the SMALLEST possible change to test the hypothesis. One variable at a time.
3. **Didn't work?** Form a NEW hypothesis. Don't pile more fixes on top.

**3-Strike Rule:**
- 1st failed fix → back to Phase 1 with new info
- 2nd failed fix → reconsider assumptions entirely
- 3rd failed fix → **STOP.** Ask the user:
  ```
  3 hypotheses tested, none confirmed. This may be an architectural
  issue rather than a simple bug.

  A) Continue — I have a new hypothesis: [describe]
  B) Escalate — this needs someone who knows the system
  C) Instrument — add logging and catch it next occurrence
  ```

### Phase 4: Implementation

1. **Write a failing test** that reproduces the bug (TDD — Layer 2 discipline).
2. **Implement a SINGLE fix** addressing the confirmed root cause. Minimal diff.
3. **Verify:** Test passes. No regressions. Run the full test suite.
4. **If fix touches >5 files:** Flag the blast radius before proceeding.

### Phase 5: Structured Report

Every debug session produces this report:

```
DEBUG REPORT
════════════════════════════════════════
Symptom:         [what was observed]
Root cause:      [what was actually wrong]
Fix:             [what changed, file:line references]
Evidence:        [test output showing fix works]
Regression test: [file:line of new test]
Related:         [prior bugs in same area, architectural notes]
Status:          DONE | DONE_WITH_CONCERNS | BLOCKED
════════════════════════════════════════
```

## Red Flags — STOP and Return to Phase 1

- "Quick fix for now, investigate later"
- "Just try changing X and see if it works"
- Proposing solutions before tracing data flow
- "I don't fully understand but this might work"
- "One more fix attempt" (when already tried 2+)
- Each fix reveals new problem in different place

**ALL of these mean: STOP. Return to Phase 1.**

## Integration

- GSD `/gsd:debug` manages the debug session state
- This skill enforces the debugging protocol within that session
- Layer 2 (TDD) ensures the fix includes a regression test
- Layer 3 (anti-sycophancy) ensures honest assessment of the fix quality
