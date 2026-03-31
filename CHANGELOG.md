# Changelog

## [Unreleased]

### Added — canonical-deliverable-distribution-system (2026-03-31)

**PostToolUse async hook: automatic artifact distribution to Gmail + NotebookLM**

When Claude writes a Cortex artifact, it is now automatically fanned out to human-native surfaces without any manual publish step.

#### Routing

| Path pattern | Surfaces |
|---|---|
| `docs/cortex/recipes/**` | Email (Gmail) + NotebookLM |
| `docs/cortex/research/**` | NotebookLM only |
| Everything else | No-op (silent early exit) |

#### New files

- `.claude/hooks/cortex-distribute.sh` — shell dispatcher. Reads PostToolUse stdin JSON, extracts `file_path` + `content`, pattern-matches path, derives human-readable title, writes content to tmpfile, delegates to Python async.
- `.claude/hooks/cortex-distribute.py` — distributor. Gmail surface sends via SMTP SSL with markdown-stripped plain text body. NotebookLM surface creates a new notebook and adds content as a text source via `nlm` CLI.
- `.claude/hooks/nlm-refresh.py` — CDP auth refresh helper. Pulls fresh cookies from Chrome on port 9222 before each NLM operation.

#### Hook registration (user-local, not repo-tracked)

Add to `~/.claude/settings.json` under `hooks > PostToolUse`:

```json
{
  "matcher": "Write|Edit",
  "hooks": [{"type": "command", "command": "/home/agent/.claude/hooks/cortex-distribute.sh", "async": true}]
}
```

#### Eval results (all 7 dimensions — 2026-03-31)

| Dimension | Result |
|---|---|
| STY: static analysis (shellcheck, ruff) | PASS |
| REG: existing hooks unchanged | PASS |
| SEC: no credential leakage, malformed stdin exits 0 | PASS (minor: 2 stray tmpfiles from prior SIGKILL, no creds) |
| INT: stdin schema + nlm/MCP integration | PASS |
| FC: functional correctness (email + NLM confirmed live) | PASS |
| RES: SMTP failure, NLM failure, concurrent writes | PASS |
| UX: email formatting + NLM notebook structure | PASS (human sign-off) |
