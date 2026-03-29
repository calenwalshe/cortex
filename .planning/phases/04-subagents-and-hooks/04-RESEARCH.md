# Phase 4: Subagents and Hooks - Research

**Researched:** 2026-03-29
**Domain:** Claude Code agent definition files, hook event model, shell hook patterns, continuity automation
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| AGNT-01 | `cortex-specifier` — drafts specs/contracts from research; write-restricted to docs/cortex/specs/ and docs/cortex/contracts/ | Agent file format fully documented. Use `tools: Read, Glob, Grep, Bash, Write, Edit` with the `disallowedTools` approach, or explicit allowlist. Markdown body becomes system prompt. |
| AGNT-02 | `cortex-critic` — adversarial reviewer; read-only | Use `tools: Read, Glob, Grep, Bash` (no Write/Edit). Read-only enforcement via allowlist. |
| AGNT-03 | `cortex-scribe` — maintains continuity artifacts; write-restricted to docs/cortex/handoffs/ and .cortex/ | Agent with Write/Edit access but system prompt instruction restricts writes to designated paths. PostToolUse hook can enforce path restrictions. |
| AGNT-04 | `cortex-eval-designer` — proposes eval suites, rubrics, fixtures, thresholds | Write-restricted to docs/cortex/evals/. Same allowlist approach as specifier. |
| HOOK-01 | `cortex-session-start` — hydrates Claude with current-state.md on SessionStart | SessionStart event confirmed. Output via `hookSpecificOutput.additionalContext`. Source field distinguishes startup/resume/clear/compact. |
| HOOK-02 | `cortex-phase-guard` — blocks Write/Edit outside docs/cortex/** and .cortex/** when phase is clarify/research/spec | PreToolUse on `Write\|Edit` matcher. Reads .cortex/state.json for mode. Exit code 2 blocks. |
| HOOK-03 | `cortex-validator-trigger` — after writes in execute/repair mode, appends to dirty-files.json and invokes validator runner | PostToolUse on `Write\|Edit`. Reads state.json for mode check. Appends to .cortex/dirty-files.json, invokes validator script. |
| HOOK-04 | `cortex-task-created` — rejects tasks missing objective, deliverable, validator(s), or contract link | TaskCreated event confirmed. `continue: false` + `stopReason` blocks task creation. |
| HOOK-05 | `cortex-task-completed` — blocks false completion if validators didn't pass | TaskCompleted event confirmed. Same blocking mechanism as HOOK-04. |
| HOOK-06 | `cortex-teammate-idle` — feeds actionable feedback to idle agent-team workers | TeammateIdle event confirmed. Exit code 2 keeps the teammate working. |
| HOOK-07 | `cortex-precompact` — writes snapshot before compaction, refreshes current-state.md | PreCompact event confirmed. Cannot block compaction. Writes snapshot + refreshes continuity files. |
| HOOK-08 | `cortex-postcompact` — writes compact summary, refreshes next-prompt.md | PostCompact event confirmed. Writes last-compact-summary.md + next-prompt.md. |
| HOOK-09 | `cortex-session-end` — writes final continuity state on /clear, exit, or resume transitions | No dedicated SessionEnd event exists in Claude Code. The `Stop` event fires when the main agent finishes responding. Use `PreCompact` + `Stop` as the best approximation. Alternatively, wiring continuity writes into the cortex-status skill (manual trigger) covers this case reliably. |
| HOOK-10 | `cortex-sync` — fixed: canonical repo path, no credential URLs, correct untracked detection, soft-fail on auth | Existing cortex-sync.sh has three known bugs: uses credential-bearing remote URL, reads from wrong input path, and uses set -euo pipefail without soft-fail guards. All fixable. |
| CONT-01 | After compaction or /clear, /cortex-status reconstructs state from current-state.md, next-prompt.md, active contract | cortex-status SKILL.md already has full reconstruction protocol. HOOK-01 auto-hydration on SessionStart (source=clear|compact) is the automation layer. |
| CONT-02 | current-state.md schema: slug, mode, approval_status, active_contract_path, recent_artifacts, open_questions, blockers, next_action | Schema fully defined in docs/CONTINUITY.md and templates/cortex/current-state.md. No new schema work needed. |
| CONT-03 | next-prompt.md contains a short restart prompt a human can paste after /clear | Template at templates/cortex/next-prompt.md exists. cortex-status already writes this file. Postcompact hook refreshes it. |
| LOOP-01 | No task closes without satisfying the contract's validator list | HOOK-05 (TaskCompleted) is the enforcement mechanism. Reads state.json for contract path, reads contract for validator list, checks eval-status.md. |
| LOOP-02 | Validation failure produces repair recommendation or opens repair contract | Behavioral logic inside cortex-status/cortex-review skill protocols + documented in CONT-02 blocker fields. Not a hook — skill-layer behavior. |
| LOOP-03 | After each loop iteration, continuity artifacts are updated | Behavioral requirement on skills. HOOK-03 (validator-trigger) handles the hook-side refresh. Skills handle the rest. |
| LOOP-04 | State transitions: clarify → research → spec → execute → validate → repair → assure → done | State machine documented in CONTINUITY.md. Enforced through state.json mode field + phase guard hook. |
</phase_requirements>

---

## Summary

Phase 4 delivers the enforcement and automation layer: 4 agent definition files, 10 hooks, and the continuity wiring that connects them. The technical substrate (state.json, current-state.md, templates, skills) is already in place from Phases 2–3. Phase 4 wires behavior on top of it.

**Agent files** are Markdown files with YAML frontmatter stored at `~/.claude/agents/` (user scope) or `.claude/agents/` (project scope). The format is fully documented in the Claude Code sub-agents spec. Only `name` and `description` are required. Write restriction is enforced through the `tools` allowlist in frontmatter plus PreToolUse hooks for path-level enforcement.

**Hook events** cover the full session lifecycle including `SessionStart`, `PreCompact`, `PostCompact`, `TaskCreated`, `TaskCompleted`, `TeammateIdle`, `PreToolUse`, and `PostToolUse`. Each hook receives a JSON payload on stdin and communicates decisions via exit codes and stdout JSON. There is no `SessionEnd` event — the closest approximation is `Stop` (fires after each agent response) or `PreCompact`/`PostCompact` for compaction-triggered continuity writes.

**The cortex-sync bug** is confirmed: the existing script uses a credential-bearing remote URL (`https://user:token@...`), has fragile stdin parsing, and uses `set -euo pipefail` without guards that would cause silent failures on auth errors. HOOK-10 is a targeted fix.

**Primary recommendation:** Implement agents and hooks as a set of discrete Markdown files (agents) and shell scripts (hooks) wired into `.claude/settings.json` at the project level. Keep hooks small, fast, and soft-failing. Behavioral logic (contract validation, repair recommendations) lives in skills, not hooks.

---

## Agent File Format

### YAML Frontmatter Schema

```markdown
---
name: agent-name           # Required. Lowercase, hyphens. Must be unique.
description: >             # Required. Claude reads this to decide when to delegate.
  When to use this agent.  # Be specific and include "use when..." phrasing.
tools: Read, Glob, Grep    # Optional. Explicit allowlist. Omit to inherit all tools.
disallowedTools: Write, Edit  # Optional. Denylist applied to inherited tools.
model: inherit             # Optional. inherit|sonnet|opus|haiku|full-model-id
permissionMode: default    # Optional. default|acceptEdits|dontAsk|bypassPermissions|plan
maxTurns: 20               # Optional. Max agentic turns.
skills:                    # Optional. Skills preloaded into agent context.
  - skill-name
memory: project            # Optional. user|project|local — persistent memory scope.
---

System prompt content in Markdown follows the frontmatter.
```

**Source:** [Claude Code sub-agents docs](https://code.claude.com/docs/en/sub-agents) — HIGH confidence.

### Tool Allowlist vs Denylist Behavior

- `tools:` field is an **allowlist** — only these tools are available to the agent. Everything else is denied.
- `disallowedTools:` field is a **denylist** — all inherited tools except these are available.
- If both are present: `disallowedTools` is applied first, then `tools` is resolved against the remaining pool. A tool in both is removed.
- For read-only agents: use `tools: Read, Glob, Grep, Bash` — omitting Write and Edit is sufficient.
- Write-restricted agents require both an allowlist AND a PreToolUse hook for path-level enforcement, since the allowlist only controls which tool types are available, not which paths those tools can write to.

### File Location

| Location | Scope | When to use |
|----------|-------|-------------|
| `.claude/agents/` | Current project only | Cortex-specific agents — check into repo |
| `~/.claude/agents/` | All projects | Personal user-level agents |

For Cortex, project-level (`.claude/agents/`) is correct. The installer (Phase 6) will also symlink these to `~/.claude/agents/` for global availability.

### Invocation

- Automatic delegation: Claude reads the `description` and delegates when task matches
- Explicit: `@cortex-specifier` in a prompt guarantees invocation
- Session-wide: `claude --agent cortex-specifier` runs the whole session as the agent

### Example: Read-Only Agent (cortex-critic)

```markdown
---
name: cortex-critic
description: >
  Adversarial reviewer of specs, contracts, and architectural decisions.
  Use when reviewing a spec or contract for logical gaps, missing edge cases,
  incorrect assumptions, or unstated dependencies.
tools: Read, Glob, Grep, Bash
model: inherit
---

You are cortex-critic. You review specs, contracts, and decisions adversarially.
...
```

### Example: Write-Restricted Agent (cortex-specifier)

```markdown
---
name: cortex-specifier
description: >
  Drafts specs and contracts from research dossiers and clarify briefs.
  Use when a clarify brief and research dossier exist for a slug and a spec
  does not yet exist.
tools: Read, Glob, Grep, Bash, Write, Edit
model: inherit
hooks:
  PreToolUse:
    - matcher: "Write|Edit"
      hooks:
        - type: command
          command: ".claude/hooks/cortex-write-guard.sh"
---

You are cortex-specifier. You write only to docs/cortex/specs/<slug>/ and
docs/cortex/contracts/<slug>/. Never write to any other path.
...
```

The PreToolUse hook on Write|Edit enforces the path restriction mechanically, independent of the agent's instruction compliance.

---

## Hook Event Model

### Available Events (Phase 4 relevant subset)

| Event | Matcher Field | Can Block | When it Fires |
|-------|--------------|-----------|---------------|
| `SessionStart` | session source (startup/resume/clear/compact) | No | Session begins or resumes |
| `PreToolUse` | tool name | Yes (exit 2) | Before any tool executes |
| `PostToolUse` | tool name | No* | After tool succeeds |
| `TaskCreated` | (always fires) | Yes (exit 2) | When a task is created |
| `TaskCompleted` | (always fires) | Yes (exit 2) | When a task is marked complete |
| `TeammateIdle` | (always fires) | Yes (exit 2) | When an agent team member goes idle |
| `PreCompact` | compaction trigger (manual/auto) | No | Before context compaction |
| `PostCompact` | compaction trigger (manual/auto) | No | After compaction completes |
| `Stop` | (always fires) | Yes | When main agent finishes responding |

*PostToolUse can output `decision: block` in JSON to surface an error message to Claude, though the tool has already executed.

**Source:** [Claude Code hooks docs](https://code.claude.com/docs/en/hooks) — HIGH confidence.

### SessionStart Event — No `SessionEnd` Equivalent

The `SessionStart` event fires with a `source` field: `startup | resume | clear | compact`. This is the hydration hook entry point.

There is **no `SessionEnd` event** in the Claude Code hook model as of this research. HOOK-09 (`cortex-session-end`) as specified cannot be implemented as a dedicated event-driven hook. Options:
1. Use `Stop` — fires when the agent finishes each response turn. Too frequent for a "session end" semantic.
2. Write continuity state inside `cortex-status` skill (manual trigger) — most reliable.
3. Use `PreCompact` as the pre-session-end signal for compaction-triggered ends.

**Recommendation:** HOOK-09 should be implemented as `Stop` with a guard that only writes continuity files if meaningful state has changed (compare current state.json vs. last written state).

### Stdin Schema — Common Fields (all events)

```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/current/working/directory",
  "permission_mode": "default",
  "hook_event_name": "PreToolUse"
}
```

### Stdin Schema — Event-Specific Fields

**PreToolUse / PostToolUse (Write or Edit):**
```json
{
  "tool_name": "Write",
  "tool_input": {
    "file_path": "/absolute/path/to/file",
    "content": "..."
  },
  "tool_use_id": "toolu_..."
}
```

**PostToolUse additionally includes:**
```json
{
  "tool_response": {
    "filePath": "/absolute/path/to/file",
    "success": true
  }
}
```

**TaskCreated / TaskCompleted:**
```json
{
  "task_id": "task-001",
  "task_subject": "Implement feature",
  "task_description": "...",
  "teammate_name": "...",
  "team_name": "..."
}
```

**SessionStart:**
```json
{
  "source": "startup|resume|clear|compact",
  "model": "claude-sonnet-4-6"
}
```

**PreCompact / PostCompact:**
```json
{
  "hook_event_name": "PreCompact"
}
```
Matcher field for PreCompact/PostCompact is the compaction trigger: `manual` or `auto`.

### Hook Response — Exit Codes

| Exit Code | Meaning | Effect |
|-----------|---------|--------|
| 0 | Success | JSON stdout parsed for decisions; plain text added as context |
| 2 | Blocking error | Execution blocked; stderr fed back to Claude as error message |
| Other | Non-blocking error | Execution continues; stderr shown in verbose mode |

### Hook Response — Output JSON

**To block a PreToolUse (Write or Edit):**
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Phase is 'spec' — writes outside docs/cortex/ and .cortex/ are blocked"
  }
}
```

**To add context without blocking (PreToolUse allow):**
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "additionalContext": "Write validated — path is within permitted roots"
  }
}
```

**To block TaskCreated or TaskCompleted:**
```json
{
  "continue": false,
  "stopReason": "Task is missing required fields: validator list"
}
```

**To add context at SessionStart:**
```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "CORTEX CONTEXT RESTORED\n<content of current-state.md>"
  }
}
```

### Hook Registration — settings.json

Hooks are registered in `.claude/settings.json` at the project level or `~/.claude/settings.json` globally. Project settings take priority 2 (after CLI flag, before user settings).

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/cortex-session-start.sh"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/cortex-phase-guard.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/cortex-validator-trigger.sh",
            "async": true
          }
        ]
      }
    ],
    "TaskCreated": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/cortex-task-created.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "TaskCompleted": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/cortex-task-completed.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "TeammateIdle": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/cortex-teammate-idle.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/cortex-precompact.sh"
          }
        ]
      }
    ],
    "PostCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/cortex-postcompact.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/cortex-session-end.sh",
            "async": true
          }
        ]
      }
    ]
  }
}
```

---

## Hook Script Patterns

### Canonical Shell Script Structure

```bash
#!/usr/bin/env bash
# cortex-<hook-name>.sh
# <EventName> hook — <description>

set -uo pipefail
# NOTE: Do NOT use -e (errexit) — hook must soft-fail rather than crash

CORTEX_STATE="$CLAUDE_PROJECT_DIR/.cortex/state.json"

# Read stdin once and store it
INPUT=$(cat)

# Extract key fields
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)

# Soft-fail guard: if state.json doesn't exist, exit 0 (don't block)
if [[ ! -f "$CORTEX_STATE" ]]; then
  exit 0
fi

MODE=$(jq -r '.mode // "clarify"' "$CORTEX_STATE" 2>/dev/null || echo "clarify")
```

### Reading state.json from a Hook

```bash
# Read the Cortex mode from state.json
CORTEX_STATE="$CLAUDE_PROJECT_DIR/.cortex/state.json"

if [[ ! -f "$CORTEX_STATE" ]]; then
  exit 0  # No state — don't interfere
fi

MODE=$(jq -r '.mode // "clarify"' "$CORTEX_STATE" 2>/dev/null)
if [[ $? -ne 0 ]] || [[ -z "$MODE" ]]; then
  exit 0  # jq failed or mode unreadable — soft fail
fi
```

**Key rule:** `$CLAUDE_PROJECT_DIR` is the environment variable that gives the project root. All hooks must use this rather than hardcoded paths.

### Phase Guard Pattern (HOOK-02)

```bash
#!/usr/bin/env bash
# cortex-phase-guard.sh
# PreToolUse on Write|Edit — blocks writes outside permitted roots during pre-execution phases

set -uo pipefail

CORTEX_STATE="$CLAUDE_PROJECT_DIR/.cortex/state.json"
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)

# Soft-fail if state not available
[[ ! -f "$CORTEX_STATE" ]] && exit 0
[[ -z "$FILE_PATH" ]] && exit 0

MODE=$(jq -r '.mode // "clarify"' "$CORTEX_STATE" 2>/dev/null || echo "clarify")

# Phase guard only applies to pre-execution phases
case "$MODE" in
  clarify|research|spec)
    ;;
  *)
    exit 0  # execute|validate|repair|assure|done — no restriction
    ;;
esac

# Permitted write roots
DOCS_ROOT="$CLAUDE_PROJECT_DIR/docs/cortex"
CORTEX_ROOT="$CLAUDE_PROJECT_DIR/.cortex"

if [[ "$FILE_PATH" == "$DOCS_ROOT"* ]] || [[ "$FILE_PATH" == "$CORTEX_ROOT"* ]]; then
  exit 0  # Allowed
fi

# Block the write
cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Phase guard: writes outside docs/cortex/ and .cortex/ are blocked while in clarify/research/spec mode. Change mode to execute before writing product code."
  }
}
EOF
exit 0
```

Note: Use JSON output (exit 0 + permissionDecision deny) rather than exit 2 for phase guard — this gives Claude an actionable reason rather than a bare error.

### Blocking TaskCreated/TaskCompleted

For HOOK-04 and HOOK-05, the blocking mechanism is `continue: false` with `stopReason`:

```bash
# Block task creation — missing required fields
cat <<'EOF'
{
  "continue": false,
  "stopReason": "Task rejected: missing required fields. Every task must have an objective, a deliverable, at least one validator, and a contract link."
}
EOF
exit 0
```

### Soft-Fail Principle

All hooks must:
1. Not use `set -e` (errexit) — a hook crash becomes a user-visible error
2. Check for state.json existence before reading it
3. Check for empty/null jq results before acting on them
4. Default to `exit 0` (allow) when guard conditions cannot be evaluated

---

## Continuity Wiring

### Session Lifecycle → Hook Mapping

```
Session starts (startup/resume/clear/compact)
  → cortex-session-start (SessionStart)
     reads: docs/cortex/handoffs/current-state.md
     outputs: additionalContext injected into Claude's context
     ensures: Claude knows the active slug, mode, contract, and next action without needing /cortex-status

User works...

/compact is invoked (auto or manual)
  → cortex-precompact (PreCompact)
     writes: .cortex/compaction/precompact-<timestamp>.md (snapshot)
     refreshes: docs/cortex/handoffs/current-state.md
  → [compaction runs]
  → cortex-postcompact (PostCompact)
     writes: docs/cortex/handoffs/last-compact-summary.md
     refreshes: docs/cortex/handoffs/next-prompt.md

Agent finishes a response
  → cortex-session-end (Stop) — async, won't block response
     writes: docs/cortex/handoffs/current-state.md if mode or artifacts have changed
```

### cortex-session-start Implementation

The session-start hook reads `current-state.md` and injects it as `additionalContext`:

```bash
#!/usr/bin/env bash
# cortex-session-start.sh
# SessionStart — hydrate Claude with current-state.md context

set -uo pipefail

CURRENT_STATE="$CLAUDE_PROJECT_DIR/docs/cortex/handoffs/current-state.md"

if [[ ! -f "$CURRENT_STATE" ]]; then
  exit 0  # No state — fresh project
fi

CONTENT=$(cat "$CURRENT_STATE")

# Build JSON response with additionalContext
python3 -c "
import json, sys
content = sys.stdin.read()
output = {
    'hookSpecificOutput': {
        'hookEventName': 'SessionStart',
        'additionalContext': 'CORTEX STATE RESTORED\n' + content
    }
}
print(json.dumps(output))
" <<< "$CONTENT"

exit 0
```

### cortex-precompact Implementation

```bash
#!/usr/bin/env bash
# cortex-precompact.sh
# PreCompact — write snapshot and refresh current-state.md

set -uo pipefail

CORTEX_DIR="$CLAUDE_PROJECT_DIR/.cortex"
COMPACTION_DIR="$CORTEX_DIR/compaction"
CURRENT_STATE="$CLAUDE_PROJECT_DIR/docs/cortex/handoffs/current-state.md"
STATE_JSON="$CORTEX_DIR/state.json"

mkdir -p "$COMPACTION_DIR"

TIMESTAMP=$(date -u +"%Y%m%dT%H%M%SZ")
SNAPSHOT="$COMPACTION_DIR/precompact-$TIMESTAMP.md"

# Write snapshot from current-state.md
if [[ -f "$CURRENT_STATE" ]]; then
  {
    echo "# Pre-Compaction Snapshot: $TIMESTAMP"
    echo ""
    cat "$CURRENT_STATE"
    echo ""
    echo "## state.json"
    echo '```json'
    cat "$STATE_JSON" 2>/dev/null || echo '{}'
    echo '```'
  } > "$SNAPSHOT"
fi

exit 0
```

### CONT-01/02/03 — Relationship to cortex-status

CONT-01 (reconstruction after /clear) is handled by the combination of:
1. `cortex-session-start` hook — auto-injects `current-state.md` on every session start, including source=clear
2. `cortex-status` skill — on-demand full reconstruction if auto-hydration is insufficient

CONT-02 (current-state.md schema) is already defined in `docs/CONTINUITY.md` and `templates/cortex/current-state.md`. No new schema work is needed.

CONT-03 (next-prompt.md) is already defined in `docs/CONTINUITY.md`. The `cortex-status` skill writes it. The `cortex-postcompact` hook also refreshes it.

---

## Contract Loop Design

The LOOP requirements are behavioral constraints that span skills and hooks:

### LOOP-01: No task closes without validators passing

**Implementation:** HOOK-05 (`TaskCompleted`) reads the active contract's validator list from state.json and checks eval-status.md. If validators have not passed, it outputs `continue: false`.

```bash
# Pseudocode for cortex-task-completed.sh
ACTIVE_CONTRACT=$(jq -r '.active_contract // ""' "$STATE_JSON")
if [[ -z "$ACTIVE_CONTRACT" ]]; then
  exit 0  # No active contract — no enforcement possible
fi

# Read validator list from contract
# Check eval-status.md for pass/fail per validator
# If any validator not passed → block with continue: false
```

The hook is intentionally lightweight — it reads files, it does not run validators. Running validators in a hook would be too slow.

### LOOP-02: Validation failure → repair recommendation or repair contract

**Implementation:** This is skill-layer behavior, not hook behavior. When `/cortex-review` or `/cortex-investigate` detects a failing validator, the skill's instruction protocol includes a repair recommendation step. If the repair is complex, the skill writes a repair contract to `docs/cortex/contracts/<slug>/contract-NNN.md` and updates state.json to `mode: repair`.

Hooks enforce the loop entry condition (LOOP-01). Skills handle the loop body (LOOP-02).

### LOOP-03: Continuity artifacts updated after each iteration

**Implementation:** HOOK-03 (`cortex-validator-trigger`) fires PostToolUse on Write|Edit when mode is `execute` or `repair`. It appends the written file path to `.cortex/dirty-files.json` and can invoke a validator runner script. Separately, every skill that changes phase state writes to `current-state.md`.

### LOOP-04: State transitions

**Implementation:** The mode field in `.cortex/state.json` is the state machine. HOOK-02 (`cortex-phase-guard`) enforces the write restrictions associated with pre-execution states. Skills advance the state by writing to state.json. No dedicated "state transition" hook is needed — the transitions are natural consequences of skill protocol steps.

```
clarify → clarify_complete: true → research → research_complete: true → spec → contract_approved: true → execute → validate → [pass: assure → done] [fail: repair → validate]
```

---

## cortex-sync Fix (HOOK-10)

The existing `cortex-sync.sh` has three confirmed bugs:

1. **Credential-bearing URL:** `CORTEX_REMOTE="https://user:${GH_TOKEN}@github.com/..."` — violates INST-06 and stores credentials in the script.
2. **Wrong stdin parsing:** `jq -r '.tool_input.file_path // .tool_response.filePath // ""'` — reads from stdin but the pipeline is `jq ... 2>/dev/null` without `<<< "$INPUT"` — the hook reads stdin at jq time, not stored first, which is fragile.
3. **Hard-fail posture:** `set -euo pipefail` without guards — any git or auth failure crashes the hook with a non-zero exit, which Claude Code may interpret as a hook error.

**Fixed pattern:**
```bash
#!/usr/bin/env bash
# cortex-sync.sh — fixed
# PostToolUse on Write|Edit — syncs cortex SKILL.md to local repo (no credential URLs)

set -uo pipefail
# NOTE: not using -e; individual commands soft-fail

CORTEX_SKILLS_DIR="$HOME/.claude/skills"
CORTEX_REPO_DIR="$HOME/projects/cortex"  # canonical local path, no remote URL

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_response.filePath // ""' 2>/dev/null)

[[ -z "$FILE_PATH" ]] && exit 0
[[ "$FILE_PATH" != "$CORTEX_SKILLS_DIR"/cortex-*/SKILL.md ]] && exit 0

SKILL_NAME="$(basename "$(dirname "$FILE_PATH")")"

[[ ! -d "$CORTEX_REPO_DIR/.git" ]] && exit 0  # repo not available — soft fail

DEST="$CORTEX_REPO_DIR/skills/$SKILL_NAME/SKILL.md"
mkdir -p "$(dirname "$DEST")" 2>/dev/null
cp "$FILE_PATH" "$DEST" 2>/dev/null || exit 0

cd "$CORTEX_REPO_DIR" || exit 0

# Only commit if there are actual changes
git diff --quiet "$DEST" 2>/dev/null && exit 0

git add "skills/$SKILL_NAME/SKILL.md" 2>/dev/null || exit 0
git commit -m "sync: update $SKILL_NAME" --quiet 2>/dev/null || exit 0

# Push only if remote is configured without credentials
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "$REMOTE_URL" != *"@"* ]] && [[ -n "$REMOTE_URL" ]]; then
  git push origin main --quiet 2>/dev/null || true  # soft-fail push
fi

echo '{"systemMessage": "Cortex synced: '"$SKILL_NAME"' updated in local repo"}'
```

---

## Plan Decomposition

### Recommended Plan Structure

Phase 4 should be decomposed into 4 plans:

**Plan 1 — Agent Definition Files (AGNT-01 through AGNT-04)**
- Create `.claude/agents/cortex-specifier.md`
- Create `.claude/agents/cortex-critic.md`
- Create `.claude/agents/cortex-scribe.md`
- Create `.claude/agents/cortex-eval-designer.md`
- Create `.claude/hooks/cortex-write-guard.sh` (shared path guard used by specifier and scribe)
Dependencies: None. Agents are standalone files.

**Plan 2 — Session Lifecycle Hooks (HOOK-01, HOOK-07, HOOK-08, HOOK-09)**
- Create `.claude/hooks/cortex-session-start.sh` (SessionStart — hydrate)
- Create `.claude/hooks/cortex-precompact.sh` (PreCompact — snapshot)
- Create `.claude/hooks/cortex-postcompact.sh` (PostCompact — last-compact-summary + next-prompt)
- Create `.claude/hooks/cortex-session-end.sh` (Stop — final state write, async)
- Register all four in `.claude/settings.json`
Dependencies: None. These hooks only read/write continuity files.

**Plan 3 — Enforcement Hooks (HOOK-02, HOOK-03, HOOK-04, HOOK-05, HOOK-06)**
- Create `.claude/hooks/cortex-phase-guard.sh` (PreToolUse Write|Edit)
- Create `.claude/hooks/cortex-validator-trigger.sh` (PostToolUse Write|Edit)
- Create `.claude/hooks/cortex-task-created.sh` (TaskCreated)
- Create `.claude/hooks/cortex-task-completed.sh` (TaskCompleted)
- Create `.claude/hooks/cortex-teammate-idle.sh` (TeammateIdle)
- Register all five in `.claude/settings.json`
Dependencies: Plan 2 (settings.json must exist).

**Plan 4 — cortex-sync Fix + Continuity Wiring Validation (HOOK-10, CONT-01/02/03, LOOP requirements)**
- Fix `.claude/hooks/cortex-sync.sh` (or `hooks/cortex-sync.sh` in repo + update ~/.claude/hooks/)
- Update hook registration to reflect canonical local repo path
- Verify CONT-01/02/03 end-to-end: session-start reads current-state.md, precompact writes snapshot, postcompact refreshes next-prompt, cortex-status reconstructs fully after simulated /clear
- Document LOOP-01 through LOOP-04 enforcement in CONTINUITY.md as "how the loop is enforced"
Dependencies: Plans 1, 2, 3 complete.

---

## Validation Architecture

`nyquist_validation: true` in config.json — this section is required.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | bash assertions + file existence checks |
| Config file | none — direct shell commands |
| Quick run command | `bash .claude/hooks/<hook>.sh < test-input.json` |
| Full suite command | `bash .planning/phases/04-subagents-and-hooks/validate-04.sh` |

No automated test runner (jest/pytest) is needed — all validations are file existence + grep patterns + hook output checks that run in under 5 seconds.

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AGNT-01 | cortex-specifier.md has correct frontmatter | grep | `grep -q "name: cortex-specifier" .claude/agents/cortex-specifier.md && grep -q "^tools:" .claude/agents/cortex-specifier.md` | Wave 0 |
| AGNT-02 | cortex-critic.md has tools allowlist with no Write/Edit | grep | `grep -q "name: cortex-critic" .claude/agents/cortex-critic.md && ! grep -q "Write" .claude/agents/cortex-critic.md` | Wave 0 |
| AGNT-03 | cortex-scribe.md has correct frontmatter | grep | `grep -q "name: cortex-scribe" .claude/agents/cortex-scribe.md` | Wave 0 |
| AGNT-04 | cortex-eval-designer.md has correct frontmatter | grep | `grep -q "name: cortex-eval-designer" .claude/agents/cortex-eval-designer.md` | Wave 0 |
| HOOK-01 | cortex-session-start.sh exists and reads current-state.md | file+grep | `test -f .claude/hooks/cortex-session-start.sh && grep -q "current-state.md" .claude/hooks/cortex-session-start.sh` | Wave 0 |
| HOOK-02 | cortex-phase-guard.sh blocks writes in spec mode | unit | `echo '{"tool_name":"Write","tool_input":{"file_path":"/project/src/foo.ts"}}' \| MODE=spec bash .claude/hooks/cortex-phase-guard.sh \| grep -q "deny"` | Wave 0 |
| HOOK-03 | cortex-validator-trigger.sh appends to dirty-files.json | file | `test -f .claude/hooks/cortex-validator-trigger.sh && grep -q "dirty-files.json" .claude/hooks/cortex-validator-trigger.sh` | Wave 0 |
| HOOK-04 | cortex-task-created.sh rejects task missing validator | unit | `echo '{"task_subject":"thing","task_description":"no validator"}' \| bash .claude/hooks/cortex-task-created.sh \| grep -q "continue.*false"` | Wave 0 |
| HOOK-05 | cortex-task-completed.sh exists and checks validators | grep | `test -f .claude/hooks/cortex-task-completed.sh && grep -q "validator" .claude/hooks/cortex-task-completed.sh` | Wave 0 |
| HOOK-06 | cortex-teammate-idle.sh exists | file | `test -f .claude/hooks/cortex-teammate-idle.sh` | Wave 0 |
| HOOK-07 | cortex-precompact.sh writes snapshot | grep | `test -f .claude/hooks/cortex-precompact.sh && grep -q "precompact-" .claude/hooks/cortex-precompact.sh` | Wave 0 |
| HOOK-08 | cortex-postcompact.sh writes last-compact-summary.md | grep | `test -f .claude/hooks/cortex-postcompact.sh && grep -q "last-compact-summary" .claude/hooks/cortex-postcompact.sh` | Wave 0 |
| HOOK-09 | cortex-session-end.sh uses Stop event (wired in settings.json) | grep | `test -f .claude/hooks/cortex-session-end.sh && grep -q "Stop" .claude/settings.json` | Wave 0 |
| HOOK-10 | cortex-sync.sh has no credential URL | grep | `! grep -q "@github.com" .claude/hooks/cortex-sync.sh` | Wave 0 |
| CONT-01 | current-state.md exists and has required fields | grep | `grep -q "mode:" docs/cortex/handoffs/current-state.md && grep -q "slug:" docs/cortex/handoffs/current-state.md` | Exists |
| CONT-02 | current-state.md schema has all 8 required fields | grep | `for f in slug mode approval_status active_contract_path recent_artifacts open_questions blockers next_action; do grep -q "$f" docs/cortex/handoffs/current-state.md || exit 1; done` | Exists |
| CONT-03 | next-prompt.md exists and contains paste-ready text | file | `test -f docs/cortex/handoffs/next-prompt.md && wc -l < docs/cortex/handoffs/next-prompt.md \| awk '{exit ($1 >= 3 ? 0 : 1)}'` | Exists |
| LOOP-01 | TaskCompleted hook checks validator field | grep | `grep -q "validator" .claude/hooks/cortex-task-completed.sh` | Wave 0 |
| LOOP-02 | Documentation: repair protocol documented in CONTINUITY.md | grep | `grep -q "repair" docs/CONTINUITY.md` | Exists |
| LOOP-03 | cortex-validator-trigger wires dirty-files.json | grep | `grep -q "dirty-files.json" .claude/hooks/cortex-validator-trigger.sh` | Wave 0 |
| LOOP-04 | state.json has mode field with valid values | file | `jq -e '.mode' .cortex/state.json > /dev/null` | Exists |

### Sampling Rate

- **Per task commit:** `test -f .claude/hooks/<hook>.sh && grep -q "<key-pattern>" .claude/hooks/<hook>.sh`
- **Per wave merge:** Full set of grep/file checks above
- **Phase gate:** All 22 checks green before `/gsd:verify-work`

### Wave 0 Gaps

All hook scripts and agent files are Phase 4 deliverables — none exist yet. The following must be created:

- [ ] `.claude/agents/cortex-specifier.md` — covers AGNT-01
- [ ] `.claude/agents/cortex-critic.md` — covers AGNT-02
- [ ] `.claude/agents/cortex-scribe.md` — covers AGNT-03
- [ ] `.claude/agents/cortex-eval-designer.md` — covers AGNT-04
- [ ] `.claude/hooks/cortex-session-start.sh` — covers HOOK-01
- [ ] `.claude/hooks/cortex-phase-guard.sh` — covers HOOK-02
- [ ] `.claude/hooks/cortex-validator-trigger.sh` — covers HOOK-03
- [ ] `.claude/hooks/cortex-task-created.sh` — covers HOOK-04
- [ ] `.claude/hooks/cortex-task-completed.sh` — covers HOOK-05
- [ ] `.claude/hooks/cortex-teammate-idle.sh` — covers HOOK-06
- [ ] `.claude/hooks/cortex-precompact.sh` — covers HOOK-07
- [ ] `.claude/hooks/cortex-postcompact.sh` — covers HOOK-08
- [ ] `.claude/hooks/cortex-session-end.sh` — covers HOOK-09
- [ ] `.claude/hooks/cortex-sync.sh` (fixed) — covers HOOK-10
- [ ] `.claude/settings.json` — hook registration for all 10 events
- [ ] `.claude/hooks/cortex-write-guard.sh` — shared path enforcement for agents

---

## Anti-Patterns to Avoid

- **Running validators inside hooks:** Hook timeout is 10s by default. Running a full test suite inside a PostToolUse hook will cause timeouts. Hooks should only append to dirty-files.json and invoke validators asynchronously.
- **Using `set -e` in hooks:** A hook that exits non-zero (unexpectedly) will be treated as a non-blocking error. If you also have `set -e`, any uncaught error becomes exit 1 which users see as noise. Use `set -uo pipefail` without `-e`.
- **Blocking PostToolUse:** The tool has already executed when PostToolUse fires. Using exit 2 here doesn't undo the write. Use PostToolUse for side effects (logging, triggering validators), not enforcement.
- **Writing agent system prompts that instruct write path compliance:** Instructions alone are insufficient for path enforcement. Always pair write-restricted agents with a PreToolUse hook that enforces paths mechanically.
- **Using SessionEnd for continuity writes:** No SessionEnd event exists. Use Stop (async) for opportunistic writes and PreCompact for compaction-triggered writes.
- **Hardcoding repo paths in hooks:** Use `$CLAUDE_PROJECT_DIR` for the project root. Never hardcode `/home/agent/projects/cortex`.

---

## Open Questions

1. **TaskCreated/TaskCompleted event in practice**
   - What we know: Both events are in the official docs with blocking support
   - What's unclear: How widely these are used in practice; the `task_subject` and `task_description` fields are what HOOK-04 would parse for required-field validation
   - Recommendation: Implement HOOK-04 to parse `task_description` for JSON or structured content containing validator/contract fields; default to allow if description is plain text

2. **cortex-session-end as Stop event**
   - What we know: No SessionEnd event exists; Stop fires after every agent response
   - What's unclear: Whether Stop-based session-end is too frequent (fires on every response, not just at true session end)
   - Recommendation: Implement as async Stop hook with a guard that compares current state.json mtime vs last written mtime; only write continuity files if state has changed since last write

3. **TeammateIdle implementation**
   - What we know: TeammateIdle fires when an agent team teammate goes idle; exit 2 keeps them working
   - What's unclear: What context HOOK-06 has about which deliverables the idle teammate owes
   - Recommendation: Implement HOOK-06 to read current-state.md and extract open_questions/blockers, returning them as feedback in the `stopReason` field

---

## Sources

### Primary (HIGH confidence)
- [Claude Code hooks reference](https://code.claude.com/docs/en/hooks) — Full event model, stdin schema, exit codes, response JSON format
- [Claude Code sub-agents docs](https://code.claude.com/docs/en/sub-agents) — Full agent file format, frontmatter schema, tools allowlist/denylist, invocation patterns
- `/home/agent/.claude/settings.json` — Live hook registration format in production use on this machine
- `/home/agent/projects/cortex/hooks/cortex-sync.sh` — Existing hook script confirming stdin parsing patterns and identifying bugs

### Secondary (MEDIUM confidence)
- `/home/agent/projects/cortex/docs/CONTINUITY.md` — Project-defined continuity architecture (authoritative for this project)
- `/home/agent/projects/cortex/docs/AGENTS.md` — Project-defined agent specifications (authoritative for this project)
- `/home/agent/projects/cortex/skills/cortex-status/SKILL.md` — Existing cortex-status behavior (establishes baseline for CONT-01)

### Tertiary (LOW confidence)
- None — all claims are verified by primary or secondary sources

---

## Metadata

**Confidence breakdown:**
- Agent file format: HIGH — sourced from official Claude Code sub-agents documentation
- Hook event model: HIGH — sourced from official Claude Code hooks reference
- Hook script patterns: HIGH — confirmed against live settings.json and existing cortex-sync.sh
- Continuity wiring: HIGH — all schemas pre-defined in docs/CONTINUITY.md
- SessionEnd limitation: HIGH — confirmed by absence of SessionEnd in official event table
- Contract loop: MEDIUM — behavioral design, not a technical API question; sound by design but cannot be integration-tested without live TaskCreated/TaskCompleted events

**Research date:** 2026-03-29
**Valid until:** 2026-04-29 (agent file format and hook model are stable; check changelog if Claude Code major version changes)
