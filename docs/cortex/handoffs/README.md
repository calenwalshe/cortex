# docs/cortex/handoffs/

**Artifact type:** Continuity files — the recovery substrate that survives `/clear`, `/compact`, and context exhaustion

---

## Structure

Unlike other `docs/cortex/` subdirectories, handoffs does **not** use slug-subdirectories. All continuity files live directly in this directory:

```
docs/cortex/handoffs/
├── current-state.md
├── open-questions.md
├── next-prompt.md
├── decisions.md
├── eval-status.md
└── last-compact-summary.md
```

---

## Files

### current-state.md

The primary handoff document. Active working state snapshot — read first after any session interruption.

| Field | Type | Description |
|-------|------|-------------|
| `slug` | string | Current active slug (e.g., `retry-logic-v2`) |
| `mode` | enum | Current phase: `clarify` \| `research` \| `spec` \| `execute` \| `validate` \| `repair` \| `assure` \| `done` |
| `approval_status` | enum | Contract approval state: `pending` \| `approved` \| `rejected` |
| `active_contract_path` | string | Relative path to the active contract |
| `recent_artifacts` | array | Artifact paths written in the current or most recent session |
| `open_questions` | array | Questions that must be resolved to advance to the next phase |
| `blockers` | array | Hard blockers preventing the current phase transition |
| `next_action` | string | The single recommended next step |

### open-questions.md

Unresolved questions that block phase transitions. Each entry includes the question, its blocking status (which phase it blocks), and when it was raised.

### next-prompt.md

Paste-ready restart prompt for use after `/clear`. Contains 3–5 sentences naming the current slug, mode, last completed action, next step, and active contract path. Format:

```
We are working on [slug] in [mode] mode. The last completed action was [what was done].
The next step is [next action]. The active contract is at [active_contract_path].
Run /cortex-status to see the full current state.
```

### decisions.md

Log of architectural and design decisions made during the project. Each entry records the decision, rationale, alternatives considered, and the date.

### eval-status.md

Current eval pass/fail state for the active contract. Tracks which dimensions passed, which failed, and which are pending. Updated after each validation run during the repair/assure loop.

### last-compact-summary.md

Written by the `cortex-postcompact` hook after each `/compact` run. Describes what was accomplished before compaction and what the next step is. Used to re-orient after compaction reduces context.

---

## Updated By

| File | Updated By |
|------|-----------|
| `current-state.md` | `/cortex-status` (manual); `cortex-session-end` hook (Phase 4, automated) |
| `open-questions.md` | `/cortex-status` (manual); any command that surfaces an open question |
| `next-prompt.md` | `/cortex-status` (manual); `cortex-postcompact` hook (Phase 4, automated) |
| `decisions.md` | `/cortex-spec`, `/cortex-investigate` (when architectural decisions are made) |
| `eval-status.md` | After each validation run during repair/assure loop |
| `last-compact-summary.md` | `cortex-postcompact` hook (Phase 4) — not manually created |

Session hooks are Phase 4 deliverables and are not yet active. Until Phase 4, `/cortex-status` must be run manually after session interruption to restore context.

---

## Recovery Protocol

After `/clear`, `/compact`, or any session interruption:

1. Run `/cortex-status`
2. Cortex reads `current-state.md`, `next-prompt.md`, and the active contract
3. Terminal output shows: current slug, mode, open questions, blockers, next recommended action
4. If more context is needed, paste the contents of `next-prompt.md` into the chat

No chat history is required. Chat context is a disposable working surface — these files are the durable store.

---

## Notes

- See `docs/CONTINUITY.md` for full field schemas and the complete resume protocol
- See `docs/COMMANDS.md` for the `/cortex-status` reference
