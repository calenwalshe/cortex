---
# Optional terminal-state frontmatter — added by /cortex-clarify if initial_terminal_set is known.
# Omit entirely for first-iteration briefs; /cortex-clarify writes defaults.
#
# initial_terminal_set: the set of terminals this slug could plausibly reach at the start.
#   Default: all six non-transitional terminals (list below).
#   Narrow this when a terminal is clearly ruled out before research begins.
#
# ruled_out: terminals already eliminated before research begins.
#   Default: [] (empty — nothing ruled out yet).
#   Each entry should be confirmed by evidence, not assumption.
#
# Six non-transitional terminals (the loop ends here):
#   commit-to-build       — real problem, viable solution, proceed to spec and execution
#   kill-with-learning    — real problem but not the right solution; document why and stop
#   decompose             — problem is real but too broad; split into N child slugs
#   experiment-required   — not enough evidence; bounded test needed before committing
#   already-exists        — the existing system already handles this adequately
#   hold-on-dependency    — blocked by an external dependency; resume when it resolves
#
# Note: reframe-and-continue is the seventh terminal but is TRANSITIONAL — reaching it
#   means producing a new clarify iteration (supersedes: this brief). It does NOT appear
#   in initial_terminal_set because it is reached implicitly, not declared.
#
# Worked example (from clarify-research-loop iter-3 brief — the canonical pattern):
#
#   iteration: 3
#   supersedes: docs/cortex/clarify/clarify-research-loop/20260412T001619Z-clarify-brief.md
#   informed_by:
#     - docs/cortex/research/clarify-research-loop/concept-20260411T235252Z.md
#     - docs/cortex/research/clarify-research-loop/concept-20260412T002407Z.md
#   reframe_reason: |
#     Iter 2 lacked a strong convergence model. Iter 3 introduces the seven-terminal
#     taxonomy as the philosophical core: the loop is a terminal-state finder, not a
#     spec-generator. Convergence = terminal set narrowing to one.
#   initial_terminal_set:
#     - commit-to-build
#     - kill-with-learning
#     - decompose
#     - experiment-required
#     - already-exists
#     - hold-on-dependency
#   ruled_out: []
---

# Clarify Brief: {SLUG}

<!-- ART-01: Clarify Brief Template — produced by /cortex-clarify -->
<!-- Copy this template to docs/cortex/clarify/{SLUG}/{TIMESTAMP}-clarify-brief.md in the target project repo -->

**Slug:** {SLUG} <!-- lowercase-hyphenated identifier derived from the idea text -->
**Timestamp:** {TIMESTAMP} <!-- ISO 8601 UTC timestamp when this brief was created -->
**Status:** {STATUS} <!-- draft | approved -->
**Complexity:** {COMPLEXITY} <!-- trivial | standard | complex — guides pipeline depth -->

<!-- Complexity tiers:
     trivial:  Simple, well-understood change. Skips research phase, gets thin spec (fewer sections).
     standard: Normal complexity. Full pipeline (clarify → research → spec → contract → execute).
     complex:  High complexity or risk. Extended validators, deeper research required.
     Complexity is a suggestion, not a hard gate. Research and spec skills can override if they
     detect the work is more complex than labeled. -->

---

## Idea

{IDEA}

<!-- Verbatim input: the exact idea, problem, or feature as stated by the human -->

---

## Goal

{GOAL}

<!-- Outcome statement: what success looks like when this idea is fully realized — one clear sentence -->

---

## Non-Goals

{NON_GOALS}

<!-- Explicit exclusions: things this work will NOT cover — each item on its own line starting with "- " -->
<!-- Example: - Not a replacement for the existing authentication system -->

---

## Constraints

{CONSTRAINTS}

<!-- Hard limits that must be respected — technical, business, timeline, regulatory, etc. -->
<!-- Each constraint on its own line starting with "- " -->

---

## Assumptions

{ASSUMPTIONS}

<!-- Things assumed true without verification — if any assumption is wrong, the goal or scope changes -->
<!-- Each assumption on its own line starting with "- " -->

---

## Open Questions

{OPEN_QUESTIONS}

<!-- Questions that must be answered before research or spec work can begin -->
<!-- Each question must be actionable — not rhetorical — on its own line starting with "- " -->
<!-- Carry unresolved questions forward to research phase -->

---

## Next Research Steps

{NEXT_RESEARCH_STEPS}

<!-- Ordered list of what to investigate in the research phase -->
<!-- Numbered list: 1. First step, 2. Second step, etc. -->
<!-- These become the agenda for /cortex-research --phase concept -->
