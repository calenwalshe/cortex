# Roadmap: GSD Autonomous Runner

## Overview

Build a daemon that drives Claude Code through GSD project phases autonomously, with Telegram as the human-in-the-loop escalation channel. Phase 1 delivers the headless engine (session management + phase loop state machine), Phase 2 wires in Telegram for gate approvals, progress notifications, and observability. Two phases because the engine must exist before the oversight layer can attach to it.

## Phases

**Phase Numbering:**
- Integer phases (1, 2): Planned milestone work
- Decimal phases (1.1, 1.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Core Engine** - State machine, session lifecycle, and autonomous phase loop (completed 2026-03-09)
- [x] **Phase 2: Telegram and Observability** - Gate approvals, progress notifications, structured logging, and stuck detection (completed 2026-03-09)

## Phase Details

### Phase 1: Core Engine
**Goal**: Runner autonomously executes GSD phase cycles (plan, execute, verify, advance) with bounded sessions and graceful lifecycle management
**Depends on**: Nothing (first phase)
**Requirements**: SESS-01, SESS-02, SESS-03, SESS-04, LOOP-01, LOOP-02, LOOP-03, LOOP-04
**Success Criteria** (what must be TRUE):
  1. Runner launches a Claude Code session via Agent SDK, executes a GSD command, and captures structured output
  2. Runner reads STATE.md and ROADMAP.md to determine the correct next GSD command (plan-phase, execute-phase, verify-work, or advance) without human input
  3. Runner detects context exhaustion (compaction threshold), checkpoints via /gsd:pause-work, starts a fresh session, and resumes from where it left off
  4. Runner completes a full phase cycle (plan -> execute -> verify -> advance) and terminates when all phases are marked complete
  5. Runner shuts down cleanly on SIGTERM, completing the current operation and persisting state before exit
**Research**: Unlikely (Agent SDK well-documented, state machine is pure logic)
**Plans**: 3 plans

Plans:
- [ ] 01-01-PLAN.md — Project scaffold, state parsers, and state machine (LOOP-01, LOOP-04)
- [ ] 01-02-PLAN.md — Session runner with Agent SDK wrapper (SESS-01, SESS-02, SESS-03, LOOP-03)
- [ ] 01-03-PLAN.md — Daemon loop, SIGTERM handling, and build verification (LOOP-02, SESS-04)

### Phase 2: Telegram and Observability
**Goal**: Runner escalates to Telegram at GSD gates with approve/reject buttons, sends progress updates, and provides structured logging with stuck detection
**Depends on**: Phase 1
**Requirements**: TELE-01, TELE-02, TELE-03, TELE-04, OBSV-01, OBSV-02
**Success Criteria** (what must be TRUE):
  1. Runner sends a Telegram message with inline approve/reject buttons when it reaches a GSD gate, and blocks until the user responds
  2. User tapping "approve" in Telegram unblocks the runner and it continues to the next step; "reject" halts execution
  3. Runner sends Telegram notifications for phase started, phase complete, and session restarted events
  4. Runner emits structured JSON logs (pino) for all operations: session start/stop, GSD commands, gate events, errors
  5. Runner detects a stuck/looping agent (repeated failing tool calls) and escalates to Telegram instead of burning credits
**Research**: Likely (grammY inline keyboard patterns, callback routing, long polling setup)
**Research topics**: grammY inline keyboard callback routing, long polling configuration, timeout patterns for approval gates
**Plans**: 3 plans

Plans:
- [ ] 02-01-PLAN.md — Centralized logger and stuck detector modules (OBSV-01, OBSV-02)
- [ ] 02-02-PLAN.md — Telegram bot with gate controller, progress, and heartbeat (TELE-01, TELE-02, TELE-03, TELE-04)
- [ ] 02-03-PLAN.md — Integration: wire Telegram, logging, and stuck detection into daemon (all reqs)

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Core Engine | 3/3 | Complete   | 2026-03-09 |
| 2. Telegram and Observability | 3/3 | Complete   | 2026-03-09 |
