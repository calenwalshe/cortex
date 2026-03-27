# Requirements: GSD Autonomous Runner

**Defined:** 2026-03-09
**Core Value:** Autonomous end-to-end execution of GSD projects with human involvement only at GSD-defined gates

## v1 Requirements

### Session Management

- [x] **SESS-01**: Runner launches Claude via Agent SDK `query()` with configurable `maxTurns` per invocation
- [x] **SESS-02**: Runner tracks compaction events per session and checkpoints via `/gsd:pause-work` when threshold is hit
- [x] **SESS-03**: Runner starts fresh session that reads STATE.md to re-orient and continues from where it left off
- [x] **SESS-04**: Runner shuts down gracefully on SIGTERM, completing current operation and persisting state

### Phase Loop

- [x] **LOOP-01**: State machine reads STATE.md and ROADMAP.md to determine the next GSD command to invoke
- [x] **LOOP-02**: Runner executes the full phase cycle: plan-phase → execute-phase → verify-work → advance to next phase
- [x] **LOOP-03**: Runner auto-approves at non-gate steps (permissionMode: bypassPermissions)
- [x] **LOOP-04**: Runner terminates when all phases in ROADMAP.md are marked complete

### Telegram Escalation

- [x] **TELE-01**: Runner sends gate notifications to Telegram with inline approve/reject buttons via grammY
- [x] **TELE-02**: Runner pipes Telegram button response back to unblock the waiting session
- [x] **TELE-03**: Runner sends progress notifications between gates (phase started, phase complete, session restarted)
- [x] **TELE-04**: Runner sends periodic heartbeat pings to confirm it's still alive

### Observability

- [x] **OBSV-01**: Runner logs all operations as structured JSON via pino (session start/stop, GSD commands, gate events, errors)
- [x] **OBSV-02**: Runner detects stuck/looping agents (repeated failing tool calls) and escalates to Telegram

## v2 Requirements

### Enhanced Safety

- **SAFE-01**: Git safety guardrails via Agent SDK hooks (prevent force-push, protect main branch)
- **SAFE-02**: Per-session cost/token tracking with budget alerts
- **SAFE-03**: `maxBudgetUsd` enforcement per session

### Enhanced Escalation

- **ESCL-01**: Approval timeout with configurable period and reminder messages
- **ESCL-02**: Free-text Telegram replies piped back as input (not just buttons)
- **ESCL-03**: Remote start via Telegram "go" command

### Reporting

- **REPT-01**: End-of-run summary report (phases completed, time, tokens, errors)
- **REPT-02**: Meaningful verification criteria injection (architectural review, not just test results)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Multi-project orchestration | Single project only for v1 -- avoids session management complexity |
| Auto-resume on boot | Manual start only -- predictable behavior |
| Web dashboard | Telegram is the sole UI -- keep it simple |
| Reuse OpenClaw approvals-bridge | Research found it's tightly coupled to OpenClaw WebSocket protocol -- fresh grammY bot is simpler |
| Confidence-based escalation | Parsing agent output for uncertainty is complex, low ROI for v1 |
| Docker containerization | Runs directly on host -- same machine as other services |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SESS-01 | Phase 1 | Complete |
| SESS-02 | Phase 1 | Complete |
| SESS-03 | Phase 1 | Complete |
| SESS-04 | Phase 1 | Complete |
| LOOP-01 | Phase 1 | Complete |
| LOOP-02 | Phase 1 | Complete |
| LOOP-03 | Phase 1 | Complete |
| LOOP-04 | Phase 1 | Complete |
| TELE-01 | Phase 2 | Complete |
| TELE-02 | Phase 2 | Complete |
| TELE-03 | Phase 2 | Complete |
| TELE-04 | Phase 2 | Complete |
| OBSV-01 | Phase 2 | Complete |
| OBSV-02 | Phase 2 | Complete |

**Coverage:**
- v1 requirements: 14 total
- Mapped to phases: 14
- Unmapped: 0

---
*Requirements defined: 2026-03-09*
*Last updated: 2026-03-09 after roadmap creation*
