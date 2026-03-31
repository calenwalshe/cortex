# Contract — canonical-deliverable-distribution-system-001

---
id: canonical-deliverable-distribution-system-001
slug: canonical-deliverable-distribution-system
phase: execute
status: approved
generated: 20260331T070000Z
---

## Objective

Build the PostToolUse async hook pipeline (`cortex-distribute.sh` + `cortex-distribute.py`) so that any Cortex artifact written to `docs/cortex/recipes/` is emailed to `calen.walshe@gmail.com` and any artifact written to `docs/cortex/research/` is added as a new NotebookLM notebook — automatically, without manual intervention.

## Deliverables

| Artifact | Path |
|----------|------|
| Shell dispatcher | `~/.claude/hooks/cortex-distribute.sh` |
| Python distributor | `~/.claude/hooks/cortex-distribute.py` |
| Hook registration | `~/.claude/settings.json` PostToolUse array entry |
| Log file (created at runtime) | `~/.claude/hooks/logs/cortex-distribute.log` |

## Scope

**In scope:**
- `~/.claude/hooks/cortex-distribute.sh` — stdin parsing, path matching, tmpfile, Python delegation
- `~/.claude/hooks/cortex-distribute.py` — email surface (Gmail SMTP) + NotebookLM surface (MCP or `nlm` CLI fallback)
- `~/.claude/settings.json` — add one PostToolUse hook entry
- Probe tests confirming stdin schema and MCP subprocess behavior

**Out of scope:**
- YAML routing config
- Google Tasks surface
- Calendar, Slack, phone surfaces
- Distribution of specs, contracts, audits, or handoff artifacts
- Two-way sync from surfaces back to canonical store
- Multi-user or team distribution

## Write Roots

- `~/.claude/hooks/cortex-distribute.sh`
- `~/.claude/hooks/cortex-distribute.py`
- `~/.claude/hooks/test/` (probe scripts only)
- `~/.claude/hooks/logs/cortex-distribute.log`
- `~/.claude/settings.json` (PostToolUse array only)

## Done Criteria

- [ ] Writing any `.md` file to `docs/cortex/recipes/` triggers an email to `calen.walshe@gmail.com` with the artifact title as subject and content as plain text body
- [ ] Writing any `.md` file to `docs/cortex/research/` triggers a new NotebookLM notebook created with the artifact content as a text source
- [ ] Writing any `.md` file outside `docs/cortex/recipes/` or `docs/cortex/research/` does NOT trigger email or NLM (confirmed via log showing early exit)
- [ ] Hook exits async — Claude's Write tool returns without waiting for distribution to complete
- [ ] All distribution attempts (success and failure) are logged to `~/.claude/hooks/logs/cortex-distribute.log` with timestamp and outcome
- [ ] Gmail SMTP failure does not crash the hook or produce a non-zero exit visible to Claude
- [ ] NotebookLM failure falls back to `nlm` CLI or logs failure without crashing
- [ ] End-to-end smoke test passes: test recipe → email received, test research doc → notebook visible in NLM

## Validators

```bash
# 1. Confirm hook is registered
grep -c "cortex-distribute.sh" ~/.claude/settings.json

# 2. Trigger a test recipe write and check log
echo "# Smoke Test" > /tmp/test/docs/cortex/recipes/smoke-test.md
sleep 5
grep "smoke-test" ~/.claude/hooks/logs/cortex-distribute.log

# 3. Confirm NLM notebook created for research doc (manual check in NLM UI or via nlm list)
nlm notebook list | grep -i "research"

# 4. Confirm non-target path does NOT appear in log
echo "# Off-target" > /tmp/test/docs/cortex/specs/test.md
sleep 2
grep -c "off-target\|specs/test" ~/.claude/hooks/logs/cortex-distribute.log  # should return 0
```

## Eval Plan

docs/cortex/evals/canonical-deliverable-distribution-system/eval-plan.md

## Approvals

- [x] Spec and contract reviewed and approved by human
- [x] Evals plan reviewed and approved by human

## Rollback Hints

- Remove hook entry from `~/.claude/settings.json` PostToolUse array
- Delete `~/.claude/hooks/cortex-distribute.sh`
- Delete `~/.claude/hooks/cortex-distribute.py`
- Delete `~/.claude/hooks/test/cortex-distribute-probe.sh` and `~/.claude/hooks/test/mcp-probe.py`
- `~/.claude/hooks/logs/cortex-distribute.log` can be left or deleted — contains no state
