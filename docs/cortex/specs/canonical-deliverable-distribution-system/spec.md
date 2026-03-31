# Spec — Canonical Deliverable Distribution System

---
slug: canonical-deliverable-distribution-system
status: approved
timestamp: 20260331T070000Z
---

## 1. Problem

Cortex produces artifacts — recipes, research docs, specs, reports — that land in `docs/cortex/` and stay there. They exist only in git. When the human is on a phone, in Gmail, or using NotebookLM to think through a problem, those artifacts are not findable. The canonical location is correct but the distribution is zero. This spec addresses the gap: artifacts written to the canonical store must automatically reach the surfaces where the human actually works, without requiring a manual publish step for each deliverable.

## 2. Scope

**In scope:**
- PostToolUse hook (`async: true`) that fires on writes to `docs/cortex/recipes/` and `docs/cortex/research/`
- Shell dispatcher (`~/.claude/hooks/cortex-distribute.sh`) — reads stdin JSON, matches path, delegates to Python
- Python distributor (`~/.claude/hooks/cortex-distribute.py`) — sends to Gmail SMTP and/or NotebookLM
- Hook registration in `~/.claude/settings.json` PostToolUse array
- Log file at `~/.claude/hooks/logs/cortex-distribute.log`
- v1 surfaces: Gmail (SMTP) and NotebookLM (MCP)

**Out of scope:**
- YAML routing config (hardcoded v1; YAML is a v2 concern when a third deliverable type is added)
- Two-way sync — surfaces receive only, no write-back to canonical
- Calendar, Slack, phone, or any surface beyond Gmail and NotebookLM
- Google Tasks surface (v2)
- Versioning or diff-tracking on distributed copies
- Distribution of specs, contracts, audits, or investigation artifacts (recipes + research only)
- A general-purpose document management layer

## 3. Architecture Decision

**Chosen approach:** PostToolUse async hook → shell dispatcher → Python distributor

The hook reads stdin JSON (already available from the Claude Code hook runtime), extracts `file_path` and `content`, matches against hardcoded path patterns, and spawns a Python script that handles surface-specific delivery. The Python script calls Gmail SMTP and NotebookLM MCP directly.

**Rationale:** This is zero new infrastructure. The hook runtime, SMTP credentials (`~/.gmail_creds.json`), and NotebookLM MCP are already in place. The pattern is identical to `cortex-sync.sh` and `cortex-validator-trigger.sh`. Adding a new PostToolUse hook is the lowest-friction, lowest-risk integration point.

**Alternatives considered:**
- **Explicit `/cortex-distribute` command (manual trigger):** Rejected — requires human to remember to run it after every artifact write; defeats the goal of automatic distribution.
- **Git post-commit hook:** Rejected — fires too late (after the agent session may have moved on), and artifacts aren't always committed immediately.
- **Dedicated daemon/watcher (inotifywait, fswatch):** Rejected — adds infrastructure, requires a separate process to stay running, no benefit over a PostToolUse hook which is already in-session.
- **YAML routing table from day 1:** Rejected — YAGNI. Only two deliverable types in v1. Hardcoded match is 5 lines; add YAML when a third type appears.
- **Aggregated notebook per deliverable type (one "Recipes" notebook):** Rejected — granular per-deliverable notebooks give better NLM context, simpler lifecycle (delete the notebook = done), and cross-notebook query still works via MCP.

## 4. Interfaces

| Interface | Owner | This spec reads | This spec writes |
|-----------|-------|-----------------|-----------------|
| `~/.claude/settings.json` PostToolUse array | Claude Code harness | existing hooks | new `cortex-distribute.sh` entry |
| `~/.claude/hooks/cortex-distribute.sh` | this spec | (created) | stdin JSON from hook runtime |
| `~/.claude/hooks/cortex-distribute.py` | this spec | (created) | called by shell dispatcher |
| `~/.gmail_creds.json` | user | `app_password` key | — |
| NotebookLM MCP | notebooklm MCP server | — | `notebook_create`, `source_add` |
| `~/.claude/hooks/logs/cortex-distribute.log` | this spec | — | success/failure entries |
| PostToolUse stdin JSON | Claude Code runtime | `tool_input.file_path`, `tool_input.content` | — |

## 5. Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| Python 3 | ≥3.8 | distributor script runtime |
| `smtplib` (stdlib) | — | Gmail SMTP_SSL |
| `json` (stdlib) | — | parse stdin, load gmail creds |
| `jq` | installed | extract fields from stdin JSON in shell dispatcher |
| `~/.gmail_creds.json` | — | Gmail app password (`app_password` key, `email` key) |
| NotebookLM MCP server | active in session | `notebook_create`, `source_add(source_type="text")` |
| `nlm` CLI | installed | fallback if MCP subprocess call fails |
| `cortex-sync.sh` | existing | reference pattern; no functional dependency |

## 6. Risks

- **MCP session inheritance in hook subprocess** — A PostToolUse hook spawns a child process. It is unconfirmed whether the MCP session context is inherited by that subprocess. Mitigation: test this first with a minimal probe script before building the full distributor. Fallback: use `nlm` CLI instead of MCP calls if subprocess MCP is not available.
- **Large content in tmpfile** — Research docs can be long. Passing content via tmpfile avoids arg length limits. Mitigation: write content to a tmpfile in the shell dispatcher; Python reads from path, not arg.
- **Gmail SMTP auth failure silently drops distribution** — async hook has no feedback channel. Mitigation: write all failures with stack trace to `~/.claude/hooks/logs/cortex-distribute.log`; human can inspect log.
- **Hook fires on non-target paths (every Write/Edit)** — The hook is registered for all Write|Edit events. Mitigation: shell dispatcher checks `file_path` against 2 patterns and exits 0 immediately for non-matching paths (< 5ms overhead).
- **NotebookLM rate limits** — Creating a notebook + adding a source on every artifact write could hit rate limits for high-volume sessions. Mitigation: v1 scope is recipes + research only, not all Cortex writes; accept rate limit errors in log without retry for now.

## 7. Sequencing

1. **Probe test** — Write a minimal shell hook that logs stdin JSON to a file and verify it receives `file_path` + `content` on a test write. Confirm async exit behavior. Produces: `~/.claude/hooks/test/cortex-distribute-probe.sh` + log evidence.
2. **MCP subprocess test** — Write a minimal Python script called from the probe hook that attempts `notebook_create` and logs the result. Determines whether MCP is available in subprocess or if `nlm` CLI fallback is needed. Produces: test result in log.
3. **Shell dispatcher** — Write `cortex-distribute.sh`: parse stdin, match path patterns, write content to tmpfile, call Python. Exit 0 always. Produces: `~/.claude/hooks/cortex-distribute.sh`.
4. **Python distributor — email surface** — Implement Gmail SMTP send. Test with a recipe artifact. Produces: working email delivery + log entry.
5. **Python distributor — NotebookLM surface** — Implement `notebook_create` + `source_add`. Test with a research doc. Produces: new NLM notebook visible in the user's account.
6. **Hook registration** — Add entry to `~/.claude/settings.json` PostToolUse array. Produces: live hook active in next session.
7. **End-to-end smoke test** — Write a test recipe artifact to `docs/cortex/recipes/test-artifact.md` and confirm email received + notebook created. Produces: passing smoke test log entry.

## 8. Tasks

- [ ] Write probe shell hook and test stdin JSON receipt (step 1)
- [ ] Write MCP subprocess test and confirm session inheritance or fallback path (step 2)
- [ ] Write `~/.claude/hooks/cortex-distribute.sh` shell dispatcher
- [ ] Write `~/.claude/hooks/cortex-distribute.py` — email surface (Gmail SMTP)
- [ ] Write `~/.claude/hooks/cortex-distribute.py` — NotebookLM surface (notebook_create + source_add)
- [ ] Register hook in `~/.claude/settings.json` PostToolUse array
- [ ] Write end-to-end smoke test and verify email + NLM notebook produced

## 9. Acceptance Criteria

- [ ] Writing any `.md` file to `docs/cortex/recipes/` triggers an email to `calen.walshe@gmail.com` with the artifact title as subject and content as plain text body
- [ ] Writing any `.md` file to `docs/cortex/research/` triggers a new NotebookLM notebook created with the artifact content as a text source
- [ ] Writing any `.md` file outside `docs/cortex/recipes/` or `docs/cortex/research/` does NOT trigger email or NLM (confirmed via log showing early exit)
- [ ] Hook exits async — Claude's Write tool returns without waiting for distribution to complete
- [ ] All distribution attempts (success and failure) are logged to `~/.claude/hooks/logs/cortex-distribute.log` with timestamp and outcome
- [ ] Gmail SMTP failure does not crash the hook or produce a non-zero exit visible to Claude
- [ ] NotebookLM failure falls back to `nlm` CLI or logs failure without crashing
- [ ] End-to-end smoke test passes: test recipe → email received, test research doc → notebook visible in NLM
