# Layer 1: Workflow (GSD)

GSD is NOT extracted into Cortex. It runs as-is from `~/.claude/get-shit-done/`.

## Why Not Extract

GSD is the orchestrator — the most complex of the three frameworks. It has
state machines, phase directories, roadmaps, and cross-session persistence.
Extracting pieces would break its internal consistency.

## How Cortex Integrates

Cortex **enhances** GSD tasks without replacing them:

- When GSD says "execute this task" → Layer 2 (Discipline) adds "write the test first"
- When GSD says "review this work" → Layer 3 (Thinking) adds "push back on vague claims"
- When GSD says "plan this phase" → Layer 3 adds forcing questions to discuss-phase

## GSD Commands (Unchanged)

All `/gsd:*` commands work exactly as before. Cortex does not intercept,
modify, or wrap them. It simply injects behavioral rules that improve
the quality of work done within GSD tasks.
