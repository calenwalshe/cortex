---
phase: 04-subagents-and-hooks
plan: "01"
subsystem: agents
tags: [claude-agents, subagents, hooks, write-guard, path-enforcement]

# Dependency graph
requires:
  - phase: 03-new-and-updated-skills
    provides: cortex commands that invoke agents (cortex-spec, cortex-review, cortex-research)
provides:
  - cortex-specifier agent definition with write scope enforcement
  - cortex-critic read-only agent definition
  - cortex-scribe agent definition with write scope enforcement
  - cortex-eval-designer agent definition with write scope enforcement
  - cortex-write-guard.sh shared PreToolUse path enforcement hook
affects:
  - 04-02-session-lifecycle-hooks
  - any phase involving cortex command execution that delegates to sub-agents

# Tech tracking
tech-stack:
  added: [claude-code-subagents, claude-code-hooks]
  patterns:
    - Agent frontmatter with explicit tools allowlist for write restriction
    - PreToolUse hook on Write|Edit for mechanical path enforcement
    - Single shared guard script per-agent case dispatch

key-files:
  created:
    - .claude/agents/cortex-specifier.md
    - .claude/agents/cortex-critic.md
    - .claude/agents/cortex-scribe.md
    - .claude/agents/cortex-eval-designer.md
    - .claude/hooks/cortex-write-guard.sh
  modified: []

key-decisions:
  - "Agent files live at .claude/agents/ (project-scope) not ~/.claude/agents/ — checked into repo, symlinked globally in Phase 6"
  - "cortex-critic declared read-only via tools allowlist (no Write/Edit) — no hook needed since no write tools available"
  - "Write-restricted agents use both tools allowlist AND PreToolUse hook — allowlist restricts tool types, hook enforces paths"
  - "Single shared cortex-write-guard.sh dispatches by agent name — avoids duplicating enforcement logic across agents"

patterns-established:
  - "Write restriction pattern: tools allowlist (blocks tool type) + PreToolUse hook (enforces path within allowed tool)"
  - "Agent frontmatter hooks block: matcher on Write|Edit triggers cortex-write-guard.sh"
  - "Guard script reads agent_name from hook input JSON for per-agent path dispatch"

requirements-completed: [AGNT-01, AGNT-02, AGNT-03, AGNT-04]

# Metrics
duration: 26min
completed: 2026-03-29
---

# Phase 4 Plan 01: Agent Definition Files Summary

**Four Cortex sub-agent definitions with mechanical write-path enforcement via shared PreToolUse guard hook**

## Performance

- **Duration:** 26 min
- **Started:** 2026-03-29T05:06:00Z
- **Completed:** 2026-03-29T05:32:03Z
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments

- Four agent `.md` files created at `.claude/agents/` with correct YAML frontmatter (name, description, tools, model, hooks)
- cortex-critic enforced as strictly read-only via tools allowlist (`Read, Glob, Grep, Bash` only — no Write or Edit)
- Three write-restricted agents (specifier, scribe, eval-designer) wired to `cortex-write-guard.sh` via `PreToolUse` hook on `Write|Edit`
- Single shared `cortex-write-guard.sh` enforces per-agent path restrictions mechanically, independent of instruction compliance

## Task Commits

1. **T1: Create cortex-specifier and cortex-critic agents** - `b426282` (feat)
2. **T2: Create cortex-scribe and cortex-eval-designer agents** - `a1719f7` (feat)
3. **T3: Create cortex-write-guard.sh shared path enforcement hook** - `bd4ae78` (feat)

## Files Created/Modified

- `.claude/agents/cortex-specifier.md` — Write-restricted agent for spec/contract drafting; wired to write-guard
- `.claude/agents/cortex-critic.md` — Read-only adversarial review agent; no Write/Edit in tools
- `.claude/agents/cortex-scribe.md` — Write-restricted agent for continuity artifact maintenance; wired to write-guard
- `.claude/agents/cortex-eval-designer.md` — Write-restricted agent for eval proposal creation; wired to write-guard
- `.claude/hooks/cortex-write-guard.sh` — Shared PreToolUse bash hook; dispatches by agent name, outputs permissionDecision deny for out-of-scope writes

## Decisions Made

- Agent files live at `.claude/agents/` (project-scoped, checked into repo). Phase 6 installer will symlink to `~/.claude/agents/` for global availability.
- cortex-critic is read-only by tools allowlist alone — no hook needed since no write tools are available to restrict paths on.
- Write-restricted agents need both: tools allowlist (permits Write/Edit tool type) and PreToolUse hook (restricts which paths those tools can target). One without the other is insufficient.
- A single shared guard script with agent-name case dispatch was chosen over per-agent hook scripts to keep enforcement logic in one place.

## Deviations from Plan

None — plan executed exactly as written. Agent file content, hook structure, and YAML frontmatter all match plan specifications.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required. Agent files are self-contained in the repo.

## Next Phase Readiness

- All four agent definitions ready for use via `@cortex-specifier`, `@cortex-critic`, `@cortex-scribe`, `@cortex-eval-designer` or automatic delegation
- `cortex-write-guard.sh` is installed and executable — will fire on any Write/Edit attempt from write-scoped agents
- Phase 4 Plan 02 (session lifecycle hooks) can proceed — agents exist as named targets for hook invocations

---
*Phase: 04-subagents-and-hooks*
*Completed: 2026-03-29*
