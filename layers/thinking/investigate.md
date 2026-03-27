# Cortex Layer 3: Investigation Protocol

> Extracted from: upstream/gstack/investigate/SKILL.md.tmpl
> Upstream version: v0.12.12.0 (11695e3)
> Adapted for: Cortex thinking layer
> Note: GStack's /investigate and Superpowers' systematic-debugging share the
> Iron Law. This extract focuses on the GStack-specific additions: scope lock,
> pattern table, 3-strike escalation, and structured debug report.

## Activation

Activates alongside Layer 2 debugging (discipline/debugging.md) during
any debugging session. This layer adds the structured report format and
escalation protocol.

## Unique Additions (Beyond Discipline Layer)

### Scope Lock
After forming a root cause hypothesis, restrict edits to the affected
module to prevent scope creep during debugging.

Identify the narrowest directory containing affected files. Only edit
within that scope. This prevents "while I'm here" changes that introduce
new bugs during a debug session.

### Pattern Table
Check bugs against known patterns before deep investigation:

| Pattern | Signature | Where to Look |
|---------|-----------|---------------|
| Race condition | Intermittent, timing-dependent | Concurrent shared state |
| Nil/null propagation | NoMethodError, TypeError | Missing guards on optionals |
| State corruption | Inconsistent data, partial updates | Transactions, callbacks |
| Integration failure | Timeout, unexpected response | External API boundaries |
| Configuration drift | Works locally, fails in prod | Env vars, feature flags |
| Stale cache | Shows old data, fixes on clear | Redis, CDN, browser cache |

### 3-Strike Escalation
If 3 hypotheses fail, present options:
- A) Continue with a new hypothesis (describe it)
- B) Escalate for human review
- C) Add logging and catch it next time

### Structured Debug Report
Every debug session produces:
```
DEBUG REPORT
════════════════════════════════════════
Symptom:         [what was observed]
Root cause:      [what was actually wrong]
Fix:             [what changed, file:line refs]
Evidence:        [test output showing fix works]
Regression test: [file:line of new test]
Related:         [prior bugs, architectural notes]
Status:          DONE | DONE_WITH_CONCERNS | BLOCKED
════════════════════════════════════════
```

### Blast Radius Gate
If a fix touches >5 files, flag it before proceeding:
- A) Proceed — root cause genuinely spans these files
- B) Split — fix critical path now, defer the rest
- C) Rethink — maybe there's a more targeted approach

## Integration with GSD + Discipline Layer

```
GSD (/gsd:debug)      → Manages the debug session state
Discipline (debugging) → Enforces the 4-phase protocol
Thinking (investigate) → Adds scope lock, pattern table, report format
```

All three layers contribute without conflict.
