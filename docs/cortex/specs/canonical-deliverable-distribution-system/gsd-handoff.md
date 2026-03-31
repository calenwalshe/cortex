# GSD Handoff — Canonical Deliverable Distribution System

---
slug: canonical-deliverable-distribution-system
contract: docs/cortex/contracts/canonical-deliverable-distribution-system/contract-001.md
generated: 20260331T070000Z
---

## Objective

Build a PostToolUse async hook system that automatically distributes Cortex artifacts to Gmail and NotebookLM when they are written to `docs/cortex/recipes/` or `docs/cortex/research/`. The artifact is written once to the canonical git store; the hook fans it out to human-native surfaces without any manual publish step. Success = a recipe write triggers an email, a research write creates a NotebookLM notebook, and nothing else is affected.

## Deliverables

| Artifact | Path |
|----------|------|
| Shell dispatcher | `~/.claude/hooks/cortex-distribute.sh` |
| Python distributor | `~/.claude/hooks/cortex-distribute.py` |
| Hook registration | `~/.claude/settings.json` (PostToolUse array) |
| Log directory | `~/.claude/hooks/logs/cortex-distribute.log` |

## Requirements

None formalized.

## Tasks

- [ ] **Probe test** — Write `~/.claude/hooks/test/cortex-distribute-probe.sh`. Register it temporarily. Trigger a test write and confirm stdin JSON contains `tool_input.file_path` and `tool_input.content`. Log output to `~/.claude/hooks/test/probe.log`.
- [ ] **MCP subprocess test** — Write `~/.claude/hooks/test/mcp-probe.py`. Call from probe hook. Attempt `notebook_create(title="probe-test")`. Log result. Determine: MCP works in subprocess (use MCP) or not (use `nlm` CLI fallback).
- [ ] **Shell dispatcher** — Write `~/.claude/hooks/cortex-distribute.sh`:
  - Read stdin, extract `file_path` and `content` via jq
  - Write content to tmpfile (`mktemp`)
  - Match: `docs/cortex/recipes/` → surfaces=email,notebooklm; `docs/cortex/research/` → surfaces=notebooklm
  - No match → exit 0 immediately
  - Derive title from filename (strip date prefix, replace hyphens, title-case)
  - Call: `python3 ~/.claude/hooks/cortex-distribute.py --file-path "$path" --tmpfile "$tmp" --surfaces "$surfaces" --title "$title"`
  - Exit 0 always
- [ ] **Python distributor — email** — Implement `email` surface in `cortex-distribute.py`:
  - Load `~/.gmail_creds.json` → `email` + `app_password` keys
  - Strip markdown: `#` headers → ALL CAPS, `**bold**` → remove asterisks, preserve body
  - Send via `smtplib.SMTP_SSL('smtp.gmail.com', 465)`
  - Log success/failure with timestamp to `~/.claude/hooks/logs/cortex-distribute.log`
- [ ] **Python distributor — NotebookLM** — Implement `notebooklm` surface in `cortex-distribute.py`:
  - If MCP subprocess available: `notebook_create(title=title)` → `source_add(source_type="text", text=content, document_id=notebook_id)`
  - Else: `nlm notebook create --title "$title"` → `nlm source add --notebook <id> --text-file "$tmpfile"`
  - Log notebook_id and success/failure
- [ ] **Hook registration** — Add to `~/.claude/settings.json` under `hooks > PostToolUse`:
  ```json
  {"matcher": "Write|Edit", "hooks": [{"type": "command", "command": "/home/agent/.claude/hooks/cortex-distribute.sh", "async": true}]}
  ```
  (Append to existing PostToolUse array — do not replace existing hooks)
- [ ] **End-to-end smoke test** — Write `docs/cortex/recipes/smoke-test-$(date +%s).md` with minimal content. Confirm: email received at `calen.walshe@gmail.com`, NotebookLM notebook visible. Write `docs/cortex/research/canonical-deliverable-distribution-system/smoke-test.md`. Confirm: NLM notebook created, no email. Check log for both entries.

## Acceptance Criteria

- [ ] Writing any `.md` file to `docs/cortex/recipes/` triggers an email to `calen.walshe@gmail.com` with the artifact title as subject and content as plain text body
- [ ] Writing any `.md` file to `docs/cortex/research/` triggers a new NotebookLM notebook created with the artifact content as a text source
- [ ] Writing any `.md` file outside `docs/cortex/recipes/` or `docs/cortex/research/` does NOT trigger email or NLM (confirmed via log showing early exit)
- [ ] Hook exits async — Claude's Write tool returns without waiting for distribution to complete
- [ ] All distribution attempts (success and failure) are logged to `~/.claude/hooks/logs/cortex-distribute.log` with timestamp and outcome
- [ ] Gmail SMTP failure does not crash the hook or produce a non-zero exit visible to Claude
- [ ] NotebookLM failure falls back to `nlm` CLI or logs failure without crashing
- [ ] End-to-end smoke test passes: test recipe → email received, test research doc → notebook visible in NLM

## Contract Link

docs/cortex/contracts/canonical-deliverable-distribution-system/contract-001.md
