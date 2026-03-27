# Cortex Layer 2: TDD Enforcement

> Extracted from: upstream/superpowers/skills/test-driven-development/SKILL.md
> Upstream version: v5.0.6 (eafe962)
> Adapted for: Cortex discipline layer (behavioral rules, not orchestration)

## Activation

These rules activate during **implementation tasks** — when writing new features,
fixing bugs, or refactoring code. They do NOT activate during planning, research,
documentation, or infrastructure tasks.

## The Iron Law

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

Write code before the test? Delete it. Start over.

- Don't keep it as "reference"
- Don't "adapt" it while writing tests
- Delete means delete
- Implement fresh from tests

## Red-Green-Refactor Cycle

### RED — Write Failing Test
- One behavior per test
- Clear name describing expected behavior
- Real code, not mocks (unless unavoidable)
- Run it. Watch it fail. Confirm it fails for the RIGHT reason.

### GREEN — Minimal Code
- Write the simplest code that passes the test
- Don't add features, refactor, or "improve" beyond the test
- Run it. Watch it pass. Confirm ALL tests still pass.

### REFACTOR — Clean Up (Only After Green)
- Remove duplication, improve names, extract helpers
- Keep all tests green throughout
- Don't add behavior during refactor

### Repeat
Next failing test for next behavior.

## Exceptions (Must Be Explicit)

- Throwaway prototypes (acknowledged as disposable)
- Generated/scaffolded code
- Configuration files
- Infrastructure/deployment scripts

All exceptions require explicit acknowledgment. "Just this once" is not an exception.

## Common Rationalizations (All Mean: Start Over)

| Excuse | Reality |
|--------|---------|
| "Too simple to test" | Simple code breaks. Test takes 30 seconds. |
| "I'll test after" | Tests passing immediately prove nothing. |
| "Already manually tested" | Ad-hoc ≠ systematic. No record, can't re-run. |
| "Deleting X hours is wasteful" | Sunk cost fallacy. Unverified code is debt. |
| "TDD will slow me down" | TDD is faster than debugging. |

## Integration with GSD

When GSD executes a task that involves writing code:
1. GSD says "execute task N"
2. **This layer activates:** Write test first, watch it fail
3. Write minimal code to pass
4. Refactor
5. GSD commits the result

GSD owns the task. This layer owns the coding discipline within that task.
