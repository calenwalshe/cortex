# GSD Autonomous Runner

## What This Is

A daemon that runs Claude Code in a loop, autonomously executing GSD project phases (plan, execute, verify, advance) without human intervention. Uses Telegram for bidirectional escalation at GSD gates — sends approval requests with inline buttons, receives approve/reject responses, and continues. A runner script manages Claude Code session lifecycle, checkpointing context before it fills and restarting fresh sessions that re-orient from STATE.md on disk.

## Core Value

Autonomous end-to-end execution of GSD projects — from first phase to last — with human involvement only at GSD-defined gates.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Runner script that launches and manages Claude Code sessions
- [ ] Context window lifecycle management (detect filling, checkpoint via /gsd:pause-work, restart fresh, resume via /gsd:resume-work)
- [ ] GSD phase loop: plan-phase → execute-phase → verify-work → advance to next phase
- [ ] Telegram integration for escalation at GSD gates (roadmap approval, requirements confirmation, verification checkpoints)
- [ ] Approve/reject inline buttons on Telegram, with response piped back to unblock Claude Code
- [ ] STATE.md/ROADMAP.md as persistent state across session restarts
- [ ] Single-project orchestration (one project, one session at a time)
- [ ] Manual start trigger (CLI or Telegram "go" command)
- [ ] Terminate when all phases in ROADMAP.md are complete
- [ ] Auto-approve at non-gate steps (GSD --auto/YOLO mode between gates)

### Out of Scope

- Multi-project orchestration — single project only for v1
- Auto-resume on boot — manual start only
- Free-text Telegram replies — approve/reject buttons only
- Running on a separate host — same Vultr machine as openclaw-fresh
- Building a new Telegram bot — reuses OpenClaw Telegram bridge

## Context

- Runs on the same Vultr server as openclaw-fresh and agent-stack
- OpenClaw's existing Telegram bridge provides the messaging infra — needs adaptation for this use case (inline buttons, routing escalation messages)
- GSD already has all the workflow primitives: /gsd:plan-phase, /gsd:execute-phase, /gsd:verify-work, /gsd:pause-work, /gsd:resume-work, STATE.md, ROADMAP.md
- Claude Code CLI supports non-interactive mode and can be driven from shell scripts
- The daemon is essentially a state machine: detect current phase from STATE.md → invoke the right GSD command → handle output → advance or escalate

## Constraints

- **Runtime**: Node.js or bash — must run on existing server without new runtime dependencies
- **Telegram**: Must integrate with existing OpenClaw bridge, not create a separate bot
- **Context window**: Claude Code sessions have finite context; runner must detect and handle gracefully
- **GSD compatibility**: Must work with current GSD skill commands as-is, not fork or modify them

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Reuse OpenClaw Telegram bridge | Avoid duplicate bot infra, leverage existing message routing | — Pending |
| Checkpoint before context restart | /gsd:pause-work preserves richer context than raw STATE.md alone | — Pending |
| Approve/reject buttons only | Keeps Telegram interaction simple, avoids complex stdin piping | — Pending |
| Single project at a time | Simplicity for v1, avoids session management complexity | — Pending |

---
*Last updated: 2026-03-09 after initialization*
