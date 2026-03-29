# Cortex Continuity Strategy

This document answers: what is Cortex's continuity strategy, what artifacts does it maintain, and how do I resume after `/clear`?

---

## Why Continuity Matters

Claude's chat history is ephemeral. `/clear`, `/compact`, and context window exhaustion destroy it with no recovery path. Any intelligence state stored only in chat — working hypotheses, architectural decisions, contract status, open questions — is permanently lost.

Cortex solves this by writing all intelligence state to repo-local artifacts that persist across sessions, compactions, and context resets. The target project repo is the durable store; chat context is a disposable working surface.

After any session interruption, `/cortex-status` is the recovery command. It reads from repo-local artifacts and reconstructs the current working state without requiring chat history.

---

## The Continuity Stack

Cortex continuity operates on three layers:

### Layer 1: Repo Artifacts (Always On)

All commands write artifacts to two roots in the target project repo:
- `docs/cortex/` — human-readable artifacts (clarify briefs, research dossiers, specs, contracts, reviews, audits, investigations, evals, handoffs)
- `.cortex/` — machine state (state.json, compaction snapshots)

These are written on every command invocation. No configuration needed. Always-on.

### Layer 2: Session Hooks (Phase 4)

Four hooks provide automated continuity lifecycle management:

| Hook | Event | Action |
|------|-------|--------|
| `cortex-session-start` | SessionStart | Hydrates Claude with `current-state.md` context |
| `cortex-precompact` | Before `/compact` | Writes snapshot to `.cortex/compaction/precompact-<timestamp>.md`, refreshes `current-state.md` |
| `cortex-postcompact` | After `/compact` | Writes compact summary to `last-compact-summary.md`, refreshes `next-prompt.md` |
| `cortex-session-end` | `/clear`, exit, or resume transition | Writes final continuity state |

**Session hooks are Phase 4 deliverables — they are not yet active.** In the current state, `/cortex-status` must be run manually after resuming a session to restore context.

### Layer 3: Machine State

`.cortex/state.json` tracks Cortex runtime mode, artifacts, approvals, and gates. This file is the source of truth for the current execution phase and contract status. It is distinct from GSD planning state — Cortex does not read or write `.planning/`, `STATE.md`, or GSD roadmaps.

---

## Continuity Files

All paths below are relative to the **target project repo** (the repo where Cortex is installed and used), not the Cortex framework repo.

### Human-Readable Files (`docs/cortex/handoffs/`)

| File | Purpose |
|------|---------|
| `current-state.md` | Current working state snapshot — active slug, mode, approval status, recent artifacts, open questions, blockers, next action |
| `open-questions.md` | Unresolved questions that block phase transitions |
| `next-prompt.md` | Paste-ready restart prompt for use after `/clear` |
| `decisions.md` | Log of architectural and design decisions made during the project |
| `eval-status.md` | Current eval pass/fail state for the active contract |
| `last-compact-summary.md` | Written by the `cortex-postcompact` hook after each `/compact` run |

### Machine State (`.cortex/`)

| File | Purpose |
|------|---------|
| `.cortex/state.json` | Runtime mode, artifacts written, approval gates, phase gates |
| `.cortex/compaction/precompact-<timestamp>.md` | Pre-compaction snapshots written by `cortex-precompact` hook |

---

## current-state.md Schema

`current-state.md` is the primary handoff document. It must contain the following fields:

| Field | Type | Description |
|-------|------|-------------|
| `slug` | string | Current active slug (e.g., `retry-logic-v2`) |
| `mode` | enum | Current phase: `clarify` \| `research` \| `spec` \| `execute` \| `validate` \| `repair` \| `assure` \| `done` |
| `approval_status` | enum | Contract approval state: `pending` \| `approved` \| `rejected` |
| `active_contract_path` | string | Relative path to the active contract (e.g., `docs/cortex/contracts/retry-logic-v2/contract-001.md`) |
| `recent_artifacts` | array | List of artifact paths written in the current or most recent session |
| `open_questions` | array | Questions that must be resolved to advance to the next phase |
| `blockers` | array | Hard blockers preventing the current phase transition |
| `next_action` | string | The single recommended next step |

---

## next-prompt.md Format

`next-prompt.md` contains a short paragraph (3–5 sentences) that a human can paste after `/clear` to restore working context. It names the current slug, mode, what was last accomplished, what the next step is, and where the active contract is located.

Template shape:

```
We are working on [slug] in [mode] mode. The last completed action was [what was done].
The next step is [next action]. The active contract is at [active_contract_path].
Run /cortex-status to see the full current state.
```

`next-prompt.md` is refreshed by `/cortex-status` and by the `cortex-postcompact` hook (Phase 4).

---

## .cortex/state.json Schema

`.cortex/state.json` is the machine-readable runtime state. It is updated by commands and hooks throughout the session.

```json
{
  "slug": "current-active-slug",
  "mode": "spec",
  "approval_status": "pending",
  "active_contract": "docs/cortex/contracts/<slug>/contract-001.md",
  "artifacts": [
    "docs/cortex/clarify/<slug>/<timestamp>-clarify-brief.md",
    "docs/cortex/research/<slug>/concept-<timestamp>.md",
    "docs/cortex/specs/<slug>/spec.md"
  ],
  "approvals": {
    "contract": false,
    "evals": false
  },
  "gates": {
    "clarify_complete": true,
    "research_complete": true,
    "spec_complete": true,
    "contract_approved": false
  }
}
```

**Key fields:**
- `mode` — matches the `mode` field in `current-state.md`; drives phase-guard behavior (Phase 4)
- `approvals` — tracks whether the contract and eval plan have received human approval
- `gates` — boolean flags for phase transition prerequisites; a gate must be `true` before the system advances

---

## Resume Protocol

Steps to resume work after `/clear`, `/compact`, or any session interruption:

1. Open the target project repo in Claude Code.
2. Run `/cortex-status`.
3. Cortex reads `current-state.md`, `next-prompt.md`, and the active contract.
4. Terminal output shows: current slug, mode, open questions, blockers, next recommended action.
5. If more context is needed, paste the contents of `next-prompt.md` into the chat.
6. Continue from the next recommended action.

No other steps are required. Chat history is not needed.

---

## Compaction Flow

The following describes Phase 4 behavior. These hooks are not yet active.

When `/compact` runs:

1. **PreCompact hook fires** (`cortex-precompact`):
   - Writes a snapshot to `.cortex/compaction/precompact-<timestamp>.md` capturing current artifacts, open questions, and state
   - Refreshes `current-state.md` with the latest working state

2. **`/compact` runs** — Claude's context is compressed by the Claude Code compaction process.

3. **PostCompact hook fires** (`cortex-postcompact`):
   - Writes a compact summary to `docs/cortex/handoffs/last-compact-summary.md` describing what was accomplished before compaction
   - Refreshes `next-prompt.md` with an updated restart prompt

After compaction, running `/cortex-status` reconstructs context from the updated files.

---

## Repair and Assure Continuity

After each iteration of the repair loop, continuity artifacts are updated (requirement LOOP-03). Specifically:

- `current-state.md` is refreshed to reflect the updated mode (`repair` or `assure`) and any new artifacts written
- `eval-status.md` is updated with the latest eval pass/fail state after each validation run
- `open_questions` and `blockers` in `current-state.md` are cleared as they are resolved

`/cortex-status` can be run at any point during a repair loop to get a snapshot of the current repair state — including which evals are still failing and what repair actions remain.

---

## Summary: Which File Answers Which Question

| Question | File |
|----------|------|
| Where are we in the lifecycle? | `current-state.md` → `mode` field |
| Is the contract approved? | `.cortex/state.json` → `approvals.contract` |
| What do I paste after /clear? | `next-prompt.md` |
| What architectural decisions were made? | `decisions.md` |
| Which evals are passing? | `eval-status.md` |
| What happened before the last /compact? | `last-compact-summary.md` |
| What is the machine runtime state? | `.cortex/state.json` |
