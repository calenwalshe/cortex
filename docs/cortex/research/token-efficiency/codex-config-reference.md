# Codex Config Reference

Configuration section for Codex task routing in `.planning/config.json`.

## Location

```
.planning/config.json → codex {}
```

## Settings

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `codex.enabled` | bool | `false` | Master toggle. When `false` or absent, Steps 4.5 and 5a in execute-plan.md are skipped entirely. All tasks route to the Claude executor. |
| `codex.timeout_seconds` | int | `300` | Maximum wall-clock seconds per Codex task. If exceeded, the task is treated as failed (subject to `fallback_on_failure`). |
| `codex.max_file_count` | int | `8` | Tasks touching more than this many files are classified as claude-required by task-router.js. Codex works best on focused, single-file or few-file tasks. |
| `codex.fallback_on_failure` | bool | `true` | When a Codex task fails, re-route it to the Claude executor in Step 5b. When `false`, the task is marked failed and skipped. |

## Example config.json

```json
{
  "mode": "yolo",
  "codex": {
    "enabled": true,
    "timeout_seconds": 300,
    "max_file_count": 8,
    "fallback_on_failure": true
  }
}
```

## Behavior Matrix

| `codex.enabled` | Codex CLI available | Effect |
|-----------------|---------------------|--------|
| `false` / absent | any | Skip 4.5 and 5a. All tasks to Claude executor (Step 5b). |
| `true` | no (`which codex` fails) | Step 4.5 runs classification, Step 5a skips (no CLI). All tasks to Claude executor. |
| `true` | yes | Step 4.5 classifies tasks. Step 5a executes codex_tasks. Step 5b handles remaining claude_tasks with completed_tasks context. |

## Routing Criteria (task-router.js)

Tasks are classified as **claude-required** when any of:
- Task type is `checkpoint:*` (requires human interaction loop)
- Task has `tdd="true"` (requires test-run-fix cycle)
- Task touches more than `codex.max_file_count` files
- Task references interactive tools (AskUserQuestion, TodoWrite)

All other `type="auto"` tasks are classified as **codex-safe**.

## Requirement

**TE-11**: `codex.enabled: false` in config.json bypasses Codex routing entirely.
