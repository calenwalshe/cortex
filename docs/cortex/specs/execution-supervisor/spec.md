# Spec: execution-supervisor

**Slug:** execution-supervisor
**Timestamp:** 20260404T020000Z
**Status:** approved

---

## 1. Problem

Cortex has 13 hooks, 3 scripts, and 12 skills — but zero observability into whether they're working correctly. Hooks exit silently on error, state transitions aren't logged, and coherence between state files is never verified. When something goes wrong, there's no way to know until the symptoms surface as broken behavior. The system needs a lightweight supervision layer: structured event logging from hooks and an on-demand health report that checks system coherence.

---

## 2. Scope

### In Scope

- Add JSONL event logging (1 line) to each of the 13 existing hooks
- `cortex-health.py` CLI that runs 6 coherence checks and summarizes the event log
- Log rotation when supervisor.jsonl exceeds 10K lines
- 4 event types: hook_fire, hook_error, state_transition, gate_eval

### Out of Scope

- Auto-repair (observe only, never fix)
- Real-time dashboards or UI
- Alerting or notifications
- New hooks (piggyback on existing 13)
- Monitoring system resources (CPU, memory, disk)
- Modifying token-ledger.db schema

---

## 3. Architecture Decision

**Chosen approach:** One-line JSONL append in each hook + standalone health report CLI.

**Rationale:** JSONL append adds <2ms overhead per hook (benchmarked at 1.6ms for 1 write). No new processes, no dependencies. The health report runs coherence checks against live state files and summarizes the event log — answerable in <100ms.

### Alternatives Considered

- **Separate logging daemon:** Rejected — adds a process to manage, overkill for append-only logging
- **SQLite in token-ledger.db:** Rejected — couples supervisor to cost telemetry; different concern
- **Continuous monitoring:** Rejected — user reviews infrequently; on-demand is simpler

---

## 4. Interfaces

- **`.cortex/supervisor.jsonl`** — new file. Append-only event log written by hooks, read by health report.
- **`scripts/cortex/cortex-health.py`** — new file. Health report CLI.
- **`.claude/hooks/cortex-*.sh` and `.js`** (13 files) — modified. Add 1-line JSONL append each.
- **`.cortex/state.json`** — read by health report for coherence checks.
- **`docs/cortex/handoffs/current-state.md`** — read by health report for state sync check.
- **`~/.cortex/token-ledger.db`** — read by health report for activity summary.

---

## 5. Dependencies

- **jq** — for reading state.json in bash hooks (already used by existing hooks)
- **better-sqlite3** (Node.js) — for reading token-ledger.db in health report (already installed)
- **numpy** — only if checking embedding freshness (already installed)

---

## 6. Risks

- **Hook modification breaks existing behavior** — Mitigation: append line is after all existing logic, wrapped in `|| true` so it can't cause hook failure.
- **supervisor.jsonl grows unbounded** — Mitigation: rotation at 10K lines in health report.
- **JSONL append race condition (concurrent hooks)** — Mitigation: append-only writes are atomic at the OS level for lines <4KB. Each event is one line.

---

## 7. Sequencing

1. **Health report script** — Write `cortex-health.py` with all 6 coherence checks. Verify: produces correct report on current state.
2. **Supervisor log helper** — Write a shared bash function for JSONL logging. Verify: appends correctly.
3. **Hook instrumentation** — Add logging line to all 13 hooks. Verify: hooks still work, events appear in log.
4. **Log rotation** — Add rotation logic to health report. Verify: rotates at threshold.
5. **Tests** — Cover coherence checks, log parsing, rotation.

---

## 8. Tasks

- [ ] Write `scripts/cortex/cortex-health.py` with 6 coherence checks (artifact existence, gate monotonicity, state sync, embedding freshness, archive completeness, contract-artifact alignment)
- [ ] Write health report sections: inventory, coherence, recent activity, event log summary, pipeline status
- [ ] Add supervisor JSONL logging to all 13 cortex hooks (1 line each)
- [ ] Implement log rotation in cortex-health.py (rotate at 10K lines, keep 1 backup)
- [ ] Write tests for coherence checks, event log parsing, rotation
- [ ] End-to-end verification: trigger hooks, check events appear in log, run health report

---

## 9. Acceptance Criteria

- [ ] `cortex-health.py` produces a structured health report with all 6 coherence checks
- [ ] All 13 hooks append events to `.cortex/supervisor.jsonl` on fire
- [ ] Events have correct structure: `{ts, event, hook, slug, mode}` minimum
- [ ] Hook errors are logged as `hook_error` events (not silently swallowed)
- [ ] Health report includes recent activity from token-ledger.db
- [ ] Health report includes event log summary (hook fires, errors, state transitions)
- [ ] Log rotation works: supervisor.jsonl rotated when >10K lines
- [ ] Adding logging does not change hook exit codes or behavior
- [ ] All tests pass
