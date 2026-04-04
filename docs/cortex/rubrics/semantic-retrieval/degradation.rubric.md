---
validator: Review that graceful degradation produces a clear, actionable stderr warning
pass_threshold: 3
max_score: 5
criteria:
  - name: warning_present
    range: [0, 1]
    levels:
      0: No warning message on stderr
      1: WARNING message present on stderr
  - name: clarity
    range: [0, 2]
    levels:
      0: Warning is cryptic or missing context
      1: Warning explains what failed
      2: Warning explains what failed and why
  - name: actionable
    range: [0, 1]
    levels:
      0: No guidance on how to fix
      1: Suggests a fix or next step
  - name: non_breaking
    range: [0, 1]
    levels:
      0: Command crashed or produced no output
      1: Command still produced results despite the failure
---

## Context

This validator checks graceful degradation in `cortex-retrieve.py` when ollama is unreachable.
Expected behavior: the command returns all facts unranked (fallback) and prints a clear warning to stderr.
The warning should help the user understand what went wrong and what to do about it.
