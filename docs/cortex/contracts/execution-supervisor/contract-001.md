# Contract: execution-supervisor — execute

**ID:** execution-supervisor-001
**Slug:** execution-supervisor
**Phase:** execute
**Created:** 20260404T020000Z
**Status:** approved
**Repair Budget:** max_repair_contracts: 3, cooldown_between_repairs: 1

---

## Objective

Build a supervision layer for Cortex: structured event logging from all 13 hooks and an on-demand health report that verifies system coherence — so the human can answer "is this thing working?" at any time.

---

## Deliverables

- `scripts/cortex/cortex-health.py` — health report CLI
- `.claude/hooks/cortex-*.sh` and `.js` modifications — 13 hooks instrumented with JSONL logging
- `test/test_supervisor.py` — test suite

---

## Scope

### In Scope

- Health report with 6 coherence checks
- JSONL event logging in all 13 hooks
- 4 event types (hook_fire, hook_error, state_transition, gate_eval)
- Log rotation at 10K lines

### Out of Scope

- Auto-repair, UI, alerting, new hooks, system resource monitoring

---

## Write Roots

- `scripts/cortex/cortex-health.py`
- `.claude/hooks/cortex-session-start.sh`
- `.claude/hooks/cortex-session-end.sh`
- `.claude/hooks/cortex-precompact.sh`
- `.claude/hooks/cortex-postcompact.sh`
- `.claude/hooks/cortex-postcompact.js`
- `.claude/hooks/cortex-phase-guard.sh`
- `.claude/hooks/cortex-write-guard.sh`
- `.claude/hooks/cortex-task-created.sh`
- `.claude/hooks/cortex-task-completed.sh`
- `.claude/hooks/cortex-teammate-idle.sh`
- `.claude/hooks/cortex-distribute.sh`
- `.claude/hooks/cortex-sync.sh`
- `.claude/hooks/cortex-validator-trigger.sh`
- `.cortex/supervisor.jsonl`
- `test/test_supervisor.py`

---

## Done Criteria

- [ ] `cortex-health.py` produces structured health report with all 6 coherence checks
- [ ] All 13 hooks append events to `.cortex/supervisor.jsonl`
- [ ] Events have structure: `{ts, event, hook, slug, mode}` minimum
- [ ] Hook errors logged as `hook_error` events
- [ ] Health report includes token-ledger activity summary
- [ ] Health report includes event log summary
- [ ] Log rotation works at >10K lines
- [ ] Hook exit codes and behavior unchanged
- [ ] All tests pass

---

## Validators

- [ ] [external] `python3 scripts/cortex/cortex-health.py | head -20` — health report runs
- [ ] [external] `python3 -m pytest test/test_supervisor.py -v` — all tests pass
- [ ] [judgment] Review that hook instrumentation doesn't change existing hook behavior
- [ ] [judgment] Review that health report coherence checks catch real issues

---

## Eval Plan

docs/cortex/evals/execution-supervisor/eval-plan.md (pending)

---

## Approvals

- [x] Contract approval
- [ ] Evals approval

---

## Completion Promise

<!-- CORTEX_PROMISE: execution-supervisor-001 COMPLETE -->

---

## Failed Approaches

<!-- Initial contract -->

---

## Why Previous Approach Failed

N/A — initial contract

---

## Rollback Hints

- Delete `scripts/cortex/cortex-health.py`
- Delete `test/test_supervisor.py`
- Revert JSONL logging lines from all 13 hooks (git checkout .claude/hooks/)
- Delete `.cortex/supervisor.jsonl`

---

## Repair Budget

**max_repair_contracts:** 3
**cooldown_between_repairs:** 1
