# Cortex Layer 2: Systematic Debugging

> Extracted from: upstream/superpowers/skills/systematic-debugging/SKILL.md
> Upstream version: v5.0.6 (eafe962)
> Adapted for: Cortex discipline layer

## Activation

These rules activate when encountering **any bug, test failure, or unexpected
behavior** — before proposing fixes.

## The Iron Law

```
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

If you haven't completed Phase 1, you cannot propose fixes.

## The Four Phases

### Phase 1: Root Cause Investigation (MANDATORY FIRST)

1. **Read error messages carefully** — don't skip past them. They often contain
   the exact solution. Read stack traces completely.

2. **Reproduce consistently** — can you trigger it reliably? If not reproducible,
   gather more data. Don't guess.

3. **Check recent changes** — git diff, recent commits, new dependencies,
   config changes, environmental differences.

4. **Gather evidence in multi-component systems** — before proposing fixes, add
   diagnostic instrumentation at each component boundary. Log what enters and
   exits each layer. Run once to find WHERE it breaks. THEN investigate that
   specific component.

5. **Trace data flow** — where does the bad value originate? Keep tracing
   upstream until you find the source. Fix at source, not at symptom.

### Phase 2: Pattern Analysis

1. Find working examples of similar code in the codebase
2. Compare working vs broken — list EVERY difference
3. Don't assume "that can't matter"
4. Understand dependencies and assumptions

### Phase 3: Hypothesis and Testing

1. Form ONE hypothesis: "I think X is the root cause because Y"
2. Make the SMALLEST possible change to test it
3. One variable at a time — don't fix multiple things at once
4. Didn't work? Form NEW hypothesis. Don't pile more fixes on top.

### Phase 4: Implementation

1. Create a failing test that reproduces the bug
2. Implement a SINGLE fix addressing the root cause
3. Verify the fix — test passes, no regressions
4. **If 3+ fixes have failed: STOP.** Question the architecture.
   3+ failures = architectural problem, not a missing fix.

## Red Flags — STOP and Return to Phase 1

- "Quick fix for now, investigate later"
- "Just try changing X and see if it works"
- "I don't fully understand but this might work"
- Proposing solutions before tracing data flow
- "One more fix attempt" (when already tried 2+)
- Each fix reveals new problem in different place

## The 3-Strike Rule

| Fixes Attempted | Action |
|:---:|---|
| 0 | Phase 1 investigation |
| 1 | If failed → back to Phase 1 with new info |
| 2 | If failed → back to Phase 1, reconsider assumptions |
| 3+ | **STOP. Question architecture. Discuss before attempting more.** |

## Integration with GSD

When GSD encounters a bug during execution:
1. `/gsd:debug` or manual debugging triggers this layer
2. This layer enforces the 4-phase protocol
3. GSD tracks the debug session state
4. Both layers contribute — GSD manages, this layer disciplines

Complementary, not competing. GSD says "debug this." This layer says "follow the protocol."
