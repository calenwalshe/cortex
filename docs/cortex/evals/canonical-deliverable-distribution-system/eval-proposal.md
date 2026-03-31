# Eval Proposal — Canonical Deliverable Distribution System

---
slug: canonical-deliverable-distribution-system
contract: docs/cortex/contracts/canonical-deliverable-distribution-system/contract-001.md
generated: 20260331T071500Z
approval_required: true
Approval Status: approved
---

## Summary

This proposal defines how contract `canonical-deliverable-distribution-system-001` will be evaluated. The contract delivers an async PostToolUse hook pipeline (shell dispatcher + Python distributor) that fans Cortex artifacts out to Gmail and NotebookLM. Evaluation covers functional correctness, integration across three components, regression safety for existing hooks, security of credential handling, resilience against external API failures, code style, and user-facing email formatting.

---

## Dimension Decisions

### 1. Functional Correctness — INCLUDE
`approval_required: false`

Every done criterion in the contract is mechanically verifiable: write a file to a target path, confirm email received, confirm NLM notebook created, confirm log entry written. Pass/fail is deterministic.

**Tests:**
- Write `docs/cortex/recipes/smoke-recipe.md` → assert email arrives at `calen.walshe@gmail.com` within 30s
- Write `docs/cortex/research/canonical-deliverable-distribution-system/smoke-research.md` → assert NLM notebook created (visible via `nlm notebook list`)
- Write `docs/cortex/specs/canonical-deliverable-distribution-system/off-target.md` → assert NO email sent, NO NLM notebook created, log shows early exit
- Write async timing: assert Claude's Write tool returns before distribution completes (check that the hook PID is still running when Write returns)
- Write a file that triggers SMTP failure (bad creds temporarily) → assert hook exits 0, failure logged, Claude unaffected

---

### 2. Regression — INCLUDE
`approval_required: false`

The contract modifies `~/.claude/settings.json` by appending to the PostToolUse array. Existing hooks (`cortex-sync.sh`, `cortex-validator-trigger.sh`) must continue to function exactly as before.

**Tests:**
- After hook registration: trigger a write to `~/.claude/skills/cortex-test/SKILL.md` → assert `cortex-sync.sh` still fires (log entry or sync artifact produced)
- After hook registration: confirm `cortex-validator-trigger.sh` still active in `execute` mode — trigger a dummy dirty-file scenario and confirm validator fires
- Parse `~/.claude/settings.json` with `jq` → assert the PostToolUse array has exactly N+1 entries (where N is count before registration), no existing entries removed or mutated

---

### 3. Integration — INCLUDE
`approval_required: false`

Three components interact across process boundaries: Claude Code hook runtime → shell dispatcher → Python distributor → Gmail SMTP / NotebookLM MCP. The highest risk is the subprocess MCP session boundary (confirmed unknown in the research dossier).

**Tests:**
- Probe test (step 1 of sequencing): verify stdin JSON schema received by hook subprocess — assert `tool_input.file_path` and `tool_input.content` present
- MCP subprocess test (step 2): call `notebook_create` from Python subprocess — assert either MCP succeeds or `nlm` CLI fallback produces equivalent result
- Tmpfile handoff: assert Python distributor can read content written to tmpfile by shell dispatcher for content ≥ 10KB (large research doc)
- End-to-end: single Write event → two surface confirmations (email + NLM) within 60s

---

### 4. Safety/Security — INCLUDE
`approval_required: false`

Gmail credentials (`app_password` from `~/.gmail_creds.json`) are read by a hook subprocess. Risk: credential leakage to log, shell history, or process args.

**Tests:**
- Assert `~/.gmail_creds.json` is never written to the log file (`grep -v app_password ~/.claude/hooks/logs/cortex-distribute.log`)
- Assert Gmail `app_password` is not passed as a command-line argument (would appear in `ps aux`) — must be read from file inside Python, not passed as arg from shell
- Assert tmpfile created with `mktemp` is deleted after Python distributor exits (no content residue on disk)
- Assert `cortex-distribute.sh` exits 0 for any input, including malformed JSON (fuzz with `echo "" | bash cortex-distribute.sh`)

---

### 5. Performance — EXCLUDE

The hook runs `async: true` — it is explicitly decoupled from Claude's execution path. No latency, throughput, or resource usage thresholds are specified in the contract. Distribution of large content (research docs) via tmpfile is already the chosen approach. No performance dimension warranted for v1.

---

### 6. Resilience — INCLUDE
`approval_required: false`

The distributor depends on two external services (Gmail SMTP, NotebookLM MCP/nlm CLI). Both can fail independently. The contract specifies fallback behavior and no-crash guarantee.

**Tests:**
- Gmail SMTP unreachable (block port 465 via iptables briefly or use bad host): assert hook exits 0, failure logged with stack trace, Claude unaffected
- NotebookLM MCP call fails (mock a failure): assert fallback to `nlm` CLI attempted; if both fail, assert failure logged, hook exits 0
- `nlm` CLI not found: assert graceful failure (log entry), no crash
- Concurrent writes (two artifacts written rapidly): assert both distribution attempts complete without race condition on log file (append-safe)

---

### 7. Style — INCLUDE
`approval_required: false`

Two new code files: `cortex-distribute.sh` (shell) and `cortex-distribute.py` (Python). Style is mechanically checkable.

**Checks:**
- Shell: `shellcheck ~/.claude/hooks/cortex-distribute.sh` — zero errors, zero warnings
- Python: `ruff check ~/.claude/hooks/cortex-distribute.py` (or `flake8` if ruff unavailable) — zero errors
- Python: functions ≤ 30 lines, no bare `except:` clauses, all exceptions caught explicitly
- Shell: all variables quoted, `set -euo pipefail` or equivalent guard at top, `exit 0` explicit at end

---

### 8. UX/Taste — INCLUDE
`approval_required: true`

The email surface produces user-facing content: the subject line and plain-text body are what lands in the human's inbox. Quality matters — a garbled subject or broken markdown stripping is a real UX failure.

**Review criteria (human approval required):**
- Subject line format: human reads `"Recipe: Soul Food Sous Vide Oxtail"` and judges it clear, not `"20260331T063000Z-soul-food-sous-vide.md"`
- Body: markdown stripped cleanly — `## Section` → `SECTION`, `**bold**` → `bold`, no raw asterisks or `#` chars visible in email
- No metadata headers (slug, timestamp, frontmatter) leaked into email body
- Research docs in NLM: notebook title format `"Research — {human-readable title}"` is readable and consistent

**Fixtures:** Two sample artifacts will be distributed during smoke test. Human reviews the received email and NLM notebook title before approving this dimension.

---

## Document-Level Approval

`approval_required: true` — UX/taste dimension requires human review of actual email and NLM notebook output before the eval plan can be finalized.

**Required before proceeding:**
1. Human reviews this proposal
2. Updates `Approval Status: pending` → `Approval Status: approved` in this file
3. Re-runs `/cortex-research --write-plan`
