---
version: 1
scope: project
last_updated: 2026-04-06
author: calen
review_cadence: 30d
---

# Owner Intent — Cortex

## Mission

Cortex converts fuzzy ideas into correct, validated software by wrapping Claude Code sessions in a lifecycle intelligence layer — so that every piece of work is clarified, researched, specified, executed, and verified before it ships.

## Objectives

1. **Lifecycle completeness** — Every non-trivial change passes through the full spine (clarify → research → spec → execute → validate → done). No shortcuts that skip validation.

2. **Autonomous capability** — cortex-drive can take a stash idea through to a closed slug without human intervention for standard-complexity work. Human gates fire only for mandatory stops (taste, reclarify, budget).

3. **Zero context loss** — After /clear, /compact, or session crash, /cortex-status reconstructs full working state from disk artifacts. No intelligence is stored only in chat.

4. **Honest quality signal** — Validators, evals, and reviews produce accurate pass/fail signals. A passing eval means the work is actually correct, not that the eval is weak.

5. **Low ceremony** — The system adds intelligence, not bureaucracy. Trivial work gets thin pipelines. The overhead of Cortex on a standard slug should be under 15 minutes of wall time for the intelligence phases (clarify + research + spec).

6. **Composability** — Cortex layers cleanly over GSD without collision. Each system owns its namespace. No dual-write conflicts.

## Success Metrics

- Slug completion rate: >80% of started slugs reach `done` without manual rescue (measured over rolling 10 slugs)
- Context recovery: /cortex-status after /clear restores working state in <30 seconds with zero information loss
- False positive rate on validators: <10% (validators that pass when the work is actually broken)
- Autonomous drive success: >60% of standard-complexity slugs complete via cortex-drive without human escalation
- Time-to-spec for standard complexity: <15 minutes wall time

## Non-Negotiables

- **No code without contract.** Production code must not be written before a contract is approved. The phase guard enforces this.
- **Validators must run.** No slug closes without validators passing. LOOP-01 is non-negotiable.
- **Disk is truth.** All state lives in repo artifacts. Chat is ephemeral. Any feature that stores state only in memory or chat context is a bug.
- **GSD owns execution.** Cortex does not write to .planning/ except via /cortex-bridge. No exceptions.
- **No sycophantic evals.** Eval rubrics must test for actual correctness, not surface compliance. A passing rubric score on broken code is worse than a failing score on working code.

## Tradeoff Preferences

When objectives conflict, resolve in this order:

1. **Correctness > Speed** — A slower slug that ships correct code beats a fast slug that ships bugs. Always.
2. **Autonomy > Ceremony** — Prefer automated decisions over human gates, except for mandatory stops. Default to gates-only, not supervised.
3. **Durability > Features** — Continuity and state management fixes take priority over new commands or capabilities.
4. **Simplicity > Generality** — Solve the concrete case well before abstracting. YAGNI applies to framework features.
5. **Evidence > Opinion** — When there's a disagreement about approach, the side with data (benchmarks, eval results, user feedback) wins.

## Kill Criteria

- If Cortex adds >30 minutes overhead to a standard slug with no measurable quality improvement, the system is net-negative. Strip it back to essentials.
- If cortex-drive autonomous mode produces >3 consecutive slugs that require human rescue, the autonomous capability is not ready. Disable it and investigate.
- If validators consistently produce false positives (>25% rate over 10 slugs), the eval system is unreliable. Freeze new features and fix evals.

## Current Initiatives

- **Owner intent system** (this slug) — Give Cortex a durable alignment layer so autonomous decisions are grounded in owner values.
- **Pattern harvest safety nets** — Context gate, circuit breaker, repair budget hardening (completed).
- **Autonomous builder ideas** — Backlog of 40+ improvements from competing system analysis.

## Anti-Goals

- Cortex will never be a general-purpose project management tool. It serves one user (the owner) working with one AI (Claude).
- Cortex will never require a database, external service, or network dependency for core operation. It is a file-based system.
- Cortex will never generate marketing copy, slide decks, or non-engineering artifacts. It is an engineering intelligence layer.
