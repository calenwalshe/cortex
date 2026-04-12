---
iteration: 1
initial_terminal_set:
  - commit-to-build
  - experiment-required
ruled_out:
  - kill-with-learning
---

# Clarify Brief: test-terminal-smoke (ruled_out variant)

**Slug:** test-terminal-smoke
**Timestamp:** 20260412T050100Z
**Status:** draft
**Complexity:** trivial

---

## Idea

Smoke test for cortex-close --terminal rejection when terminal is in ruled_out.

---

## Goal

Verify that /cortex-close --terminal kill-with-learning fails when ruled_out contains kill-with-learning.

---

## Non-Goals

- Not a real slug.

---

## Constraints

- None.

---

## Assumptions

- cortex-close Phase 1 reads the most recent clarify brief and checks ruled_out list.

---

## Open Questions

- (none)

---

## Next Research Steps

1. (none)
