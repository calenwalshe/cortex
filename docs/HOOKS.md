# Cortex Hook Reference

**Last audited:** 2026-04-01

This file documents all installed Cortex hook scripts. Hooks are shell scripts wired to Claude Code lifecycle events via `.claude/settings.json`. They run automatically — no user invocation required.

> **Maintenance note:** Update this file whenever a hook script changes. The authoritative source of truth for each hook is its script file under `.claude/hooks/`. This document must not contradict those scripts.

---

## Hook Overview

| Hook | Event | Matcher | Async | Blocking |
|------|-------|---------|-------|---------|
| `cortex-session-start` | SessionStart | — | No | Yes |
| `cortex-precompact` | PreCompact | — | No | Yes |
| `cortex-postcompact` | PostCompact | — | No | No |
| `cortex-session-end` | Stop | — | Yes | No |
| `cortex-phase-guard` | PreToolUse | Write\|Edit | No | Yes (can deny) |
| `cortex-write-guard` | PreToolUse | Write\|Edit | No | Yes (can deny) |
| `cortex-validator-trigger` | PostToolUse | Write\|Edit | Yes | No |
| `cortex-sync` | PostToolUse | Write\|Edit | No | No |
| `cortex-distribute` | PostToolUse | Write\|Edit | Yes | No |
| `cortex-task-created` | TaskCreated | — | No | Yes (can deny) |
| `cortex-task-completed` | TaskCompleted | — | No | Yes (can deny) |
| `cortex-teammate-idle` | TeammateIdle | — | No | Yes (returns exit 2) |
| `auto-doc-sync` | pre-commit (git) | — | No | No |

---

## Hook Entries

### cortex-session-start

**Script:** `.claude/hooks/cortex-session-start.sh`
**Event:** SessionStart
**Async:** No (synchronous — runs before Claude receives its first message)
**Blocking:** Yes — output is injected into Claude's context as `additionalContext`

**Trigger conditions:**
- Fires on every session start: initial startup, `/clear`, post-compaction resume, and agent resume.

**Inputs:**
- `$CLAUDE_PROJECT_DIR/docs/cortex/handoffs/current-state.md` — read to get the current Cortex state snapshot.

**Outputs (files written):** None — output is injected into Claude's context only.

**Side effects:**
- Injects the full contents of `current-state.md` into Claude's session context with a `CORTEX STATE RESTORED` header. If `current-state.md` does not exist, exits silently (fresh project).

**state.json interaction:** Reads indirectly via `current-state.md`. Does not read or write `state.json` directly.

---

### cortex-precompact

**Script:** `.claude/hooks/cortex-precompact.sh`
**Event:** PreCompact
**Async:** No (synchronous — runs before `/compact` executes)
**Blocking:** No — cannot block compaction; runs as a side-effect only.

**Trigger conditions:**
- Fires before every `/compact` invocation.

**Inputs:**
- `.cortex/state.json` — read for slug, mode, and contract fields.
- `docs/cortex/handoffs/current-state.md` — included verbatim in the snapshot.

**Outputs (files written):**
- `.cortex/compaction/precompact-<timestamp>.md` — snapshot combining `current-state.md` contents and `state.json` at the moment of compaction. Timestamp format: `YYYYMMDDTHHMMSSZ`.

**Side effects:**
- Creates `.cortex/compaction/` directory if it does not exist.

**state.json interaction:** Reads `mode`, `slug`, `active_contract`. Does not write state.json.

---

### cortex-postcompact

**Script:** `.claude/hooks/cortex-postcompact.sh`
**Event:** PostCompact
**Async:** No
**Blocking:** No

**Trigger conditions:**
- Fires after every `/compact` completes.

**Inputs:**
- `.cortex/state.json` — read for slug, mode, and active contract.
- `.cortex/compaction/precompact-*.md` — most recent snapshot is referenced in the summary.

**Outputs (files written):**
- `docs/cortex/handoffs/last-compact-summary.md` — short summary of compaction: timestamp, slug, mode, active contract, reference to the pre-compaction snapshot.
- `docs/cortex/handoffs/next-prompt.md` — refreshed paste-ready restart prompt for use after `/clear`.

**Side effects:**
- Creates `docs/cortex/handoffs/` directory if it does not exist.

**state.json interaction:** Reads `slug`, `mode`, `active_contract`. Does not write state.json.

---

### cortex-session-end

**Script:** `.claude/hooks/cortex-session-end.sh`
**Event:** Stop (fires after every agent response turn)
**Async:** Yes — registered as `async: true`; does not delay Claude's response.
**Blocking:** No

**Trigger conditions:**
- Fires after every agent response turn (Stop event). This includes mid-session turns, not just final exits.

**Inputs:**
- `.cortex/state.json` — read for slug, mode, approval_status, active_contract, and artifacts.

**Outputs (files written):**
- `docs/cortex/handoffs/current-state.md` — rebuilt from state.json fields at every turn. Includes: slug, mode, approval_status, active_contract_path, recent_artifacts, open_questions pointer, blockers (none by default), and a next_action prompt to run `/cortex-status`.

**Side effects:**
- Soft-fails silently if state.json does not exist (fresh project).

**state.json interaction:** Reads `slug`, `mode`, `approval_status`, `active_contract`, `artifacts`. Does not write state.json.

---

### cortex-phase-guard

**Script:** `.claude/hooks/cortex-phase-guard.sh`
**Event:** PreToolUse
**Matcher:** `Write|Edit`
**Async:** No (synchronous, with 10s timeout)
**Blocking:** Yes — emits a permission deny with an actionable reason message.

**Trigger conditions:**
- Fires before every Write or Edit tool call.
- Only enforces restrictions during `clarify`, `research`, or `spec` modes. Exits immediately (allows) for all other modes.

**Inputs:**
- `.cortex/state.json` — reads `mode` field.
- Tool input JSON — reads `file_path` of the write/edit being attempted.

**Outputs (files written):** None.

**Side effects:**
- If the target file is outside permitted roots during a pre-execution phase, emits a JSON deny response:
  ```
  Phase guard: writes outside docs/cortex/ and .cortex/ are blocked while in {mode} mode.
  Advance to execute mode before writing product code.
  ```
- Permitted write roots during `clarify`/`research`/`spec`: `docs/cortex/`, `.cortex/`, `docs/cortex/fit/`, `docs/cortex/experiments/`.

**state.json interaction:** Reads `mode`. Does not write state.json.

---

### cortex-write-guard

**Script:** `.claude/hooks/cortex-write-guard.sh`
**Event:** PreToolUse
**Matcher:** `Write|Edit`
**Async:** No
**Blocking:** Yes — emits a permission deny when an agent attempts to write outside its designated paths.

**Trigger conditions:**
- Fires before every Write or Edit tool call when an agent is active.
- Only enforces restrictions for named agents: `cortex-specifier`, `cortex-scribe`, `cortex-eval-designer`. Unknown agents are checked against a broad `docs/cortex/` + `.cortex/` allowlist.

**Inputs:**
- Tool input JSON — reads `file_path` and `agent_name`.

**Outputs (files written):** None.

**Side effects:**
- Emits a deny response if the target path is outside the agent's write scope:
  - `cortex-specifier`: `docs/cortex/specs/`, `docs/cortex/contracts/`
  - `cortex-scribe`: `docs/cortex/handoffs/`, `.cortex/`
  - `cortex-eval-designer`: `docs/cortex/evals/`
  - Unknown agents: `docs/cortex/`, `.cortex/`

**state.json interaction:** None.

---

### cortex-validator-trigger

**Script:** `.claude/hooks/cortex-validator-trigger.sh`
**Event:** PostToolUse
**Matcher:** `Write|Edit`
**Async:** Yes — registered as `async: true`
**Blocking:** No (PostToolUse cannot block; the write has already occurred)

**Trigger conditions:**
- Fires after every Write or Edit tool call.
- Only active during `execute` or `repair` modes. Exits immediately for all other modes.

**Inputs:**
- `.cortex/state.json` — reads `mode`.
- Tool response/input JSON — reads `file_path` of the written file.

**Outputs (files written):**
- `.cortex/dirty-files.json` — appends the written file path to the `dirty` array. Creates the file with `{"dirty": []}` if it does not exist.

**Side effects:**
- Tracks which files have been modified during the execution or repair phase. Used downstream by the validator pipeline to know which files to check.

**state.json interaction:** Reads `mode`. Does not write state.json.

---

### cortex-sync

**Script:** `.claude/hooks/cortex-sync.sh`
**Event:** PostToolUse
**Matcher:** `Write|Edit` on cortex SKILL.md files only
**Async:** No
**Blocking:** No (soft-fails on all errors)

**Trigger conditions:**
- Fires after Write or Edit tool calls.
- Only acts when the written file path matches `~/.claude/skills/cortex-*/SKILL.md`. All other writes are ignored immediately.

**Inputs:**
- Tool input JSON — reads `file_path`.
- Local cortex repo at `~/projects/cortex/` — must exist and be a git repo.

**Outputs (files written):**
- `~/projects/cortex/skills/<skill-name>/SKILL.md` — overwrites the canonical skill file in the local repo with the updated version.

**Side effects:**
- Runs `git add` and `git commit` in the local cortex repo when there are changes.
- Pushes to the remote origin if the remote URL does not contain embedded credentials.
- Emits a `systemMessage` confirmation: `"Cortex synced: <skill-name> updated in local repo"`.

**state.json interaction:** None.

---

### cortex-distribute

**Script:** `~/.claude/hooks/cortex-distribute.sh` (installed separately — not a symlink to the cortex repo)
**Event:** PostToolUse
**Matcher:** `Write|Edit`
**Async:** Yes — registered as `async: true`
**Blocking:** No (always exits 0)

**Trigger conditions:**
- Fires after Write or Edit tool calls.
- Only acts on specific path patterns:
  - `docs/cortex/recipes/` → distributes to `email` and `notebooklm` surfaces
  - `docs/cortex/research/` → distributes to `notebooklm` surface only
  - All other paths → exits immediately (< 5ms overhead)

**Inputs:**
- Tool input JSON — reads `file_path` and `content`.
- `~/.claude/hooks/cortex-distribute.py` — Python distributor script that handles the actual delivery.

**Outputs (files written):**
- `~/.claude/hooks/logs/cortex-distribute.log` — appends dispatch and error log entries.

**Side effects:**
- Derives a human-readable title from the filename (strips timestamp prefix, title-cases words).
- Delegates delivery to `cortex-distribute.py` with `--file-path`, `--tmpfile`, `--surfaces`, and `--title` arguments.
- Content is written to a temp file to avoid argument length limits; the temp file is always cleaned up via `trap`.

**state.json interaction:** None.

---

### cortex-task-created

**Script:** `.claude/hooks/cortex-task-created.sh`
**Event:** TaskCreated
**Async:** No (synchronous, with 5s timeout)
**Blocking:** Yes — emits `continue: false` with a `stopReason` to reject the task.

**Trigger conditions:**
- Fires when any task is created.

**Inputs:**
- Task creation JSON — reads `task_subject` and `task_description`.

**Outputs (files written):** None.

**Side effects:**
- Validates that the combined subject + description contains signals for three required fields:
  1. **Deliverable** — must mention `deliverable`, `produces`, `output`, `creates`, `writes`, or `artifact`
  2. **Validator** — must mention `validator`, `eval`, `test`, `verify`, `assertion`, or `check`
  3. **Contract link** — must mention `contract`, `contract-NNN`, or `docs/cortex/contracts`
- If any required field is missing, rejects the task with a specific list of what is missing.
- Soft-fails silently if both subject and description are empty.

**state.json interaction:** None.

---

### cortex-task-completed

**Script:** `.claude/hooks/cortex-task-completed.sh`
**Event:** TaskCompleted
**Async:** No (synchronous, with 10s timeout)
**Blocking:** Yes — emits `continue: false` with a `stopReason` to block completion.

**Trigger conditions:**
- Fires when any task is marked complete.

**Inputs:**
- `.cortex/state.json` — reads `active_contract`.
- `docs/cortex/handoffs/eval-status.md` — scanned for failing validator rows.

**Outputs (files written):** None.

**Side effects:**
- If no active contract is set in state.json: exits without enforcement.
- If `eval-status.md` does not exist: blocks completion with "no eval-status.md found — run validators first."
- If `eval-status.md` contains any lines matching `| ... | FAIL`: blocks completion and lists up to 5 failing validators.
- Enforces LOOP-01: no task closes without validators passing.

**state.json interaction:** Reads `active_contract`. Does not write state.json.

---

### cortex-teammate-idle

**Script:** `.claude/hooks/cortex-teammate-idle.sh`
**Event:** TeammateIdle
**Async:** No (synchronous, with 5s timeout)
**Blocking:** Yes — exits with code 2 to keep the teammate working.

**Trigger conditions:**
- Fires when an agent team member becomes idle (TeammateIdle event).

**Inputs:**
- `docs/cortex/handoffs/current-state.md` — reads `next_action` field.
- `.cortex/state.json` — reads `mode` and `slug`.

**Outputs (files written):** None.

**Side effects:**
- Writes a guidance message to stderr: current slug, mode, and the recommended next action from `current-state.md`.
- If `next_action` is empty, falls back to a generic "run /cortex-status" message.
- Always exits 2 — the TeammateIdle protocol interprets this as "agent should keep working."

**state.json interaction:** Reads `mode`, `slug`. Does not write state.json.

---

### auto-doc-sync

**Script:** `hooks/auto-doc-sync.sh` (symlinked via `.claude/hooks/auto-doc-sync.sh`)
**Event:** git pre-commit (not a Claude lifecycle hook — runs via git's `pre-commit` hook mechanism)
**Async:** No (synchronous — runs before `git commit` completes)
**Blocking:** No — always exits 0. All failure paths (missing API key, API errors, invalid response) produce a warning and exit cleanly. Never blocks a commit.

**Trigger conditions:**
- Fires on every `git commit` when installed as a git pre-commit hook.
- Skips immediately when `SKIP_LLM_GITHOOK=1` is set or `SKIP` env var contains `auto-doc-sync`.
- Skips when no staged files match any entry in `.auto-doc-sync.json`.

**Inputs:**
- `.auto-doc-sync.json` — mapping config at repo root. Each entry specifies `source_glob`, `target_doc`, `target_section`, and `prompt_hint`. 22 entries covering COMMANDS.md (8), HOOKS.md (12), and CONTINUITY.md (2).
- `git diff --cached` — staged diffs for matched source files.
- `git diff --cached --name-only` — list of staged files for source matching and conflict detection.
- Target doc files (`docs/COMMANDS.md`, `docs/HOOKS.md`, `docs/CONTINUITY.md`) — current section content is read and sent to the LLM as context.
- `ANTHROPIC_API_KEY` env var — required for API calls. Hook soft-fails if unset.

**Outputs (files written):**
- Updated sections in target doc files (working tree only — `git add` is never called). The hook replaces the matched section content with the LLM-generated update.
- Unified diff printed to stdout for each updated file.

**Side effects:**
- Makes a single batched HTTP POST to the Anthropic Messages API (`claude-haiku-4-5-20241022` model) with all triggered mappings. One API call per commit regardless of how many source files changed.
- Heuristic classifier skips the LLM call entirely for trivial diffs (whitespace-only or comment-only changes). For `.md` files, markdown headings (`#`) are treated as content, not comments.
- Conflict detection: if a target doc is already in the staging area, the hook skips that target and prints a notice. `FORCE_DOC_SYNC=1` overrides this check.
- Per-file skip marker: if `<!-- auto-doc-sync:skip -->` appears in the first 50 lines of a target doc, that target is skipped.

**state.json interaction:** None. This hook does not read or write `.cortex/state.json`.
