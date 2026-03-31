# Eval Plan — Canonical Deliverable Distribution System

---
slug: canonical-deliverable-distribution-system
contract: docs/cortex/contracts/canonical-deliverable-distribution-system/contract-001.md
proposal: docs/cortex/evals/canonical-deliverable-distribution-system/eval-proposal.md
generated: 20260331T072000Z
approval_required: true
Approval Status: approved
---

## Approved Dimensions

1. Functional correctness
2. Regression
3. Integration
4. Safety/security
5. Resilience
6. Style
7. UX/taste

(Performance: excluded — hook is async, no thresholds specified)

---

## Fixtures

| Fixture | Path | Purpose |
|---------|------|---------|
| Recipe smoke artifact | `docs/cortex/recipes/eval-smoke-recipe.md` | Trigger email + NLM distribution |
| Research smoke artifact | `docs/cortex/research/canonical-deliverable-distribution-system/eval-smoke-research.md` | Trigger NLM-only distribution |
| Off-target artifact | `docs/cortex/specs/canonical-deliverable-distribution-system/eval-off-target.md` | Confirm non-matching paths exit cleanly |
| Bad SMTP config | Temporarily rename `~/.gmail_creds.json` | Test resilience: email failure |
| Gmail credentials | `~/.gmail_creds.json` | Required for email surface tests |

---

## Dimension 1: Functional Correctness

**Goal:** Every done criterion in the contract passes mechanically.

### Tests

```bash
# FC-01: Recipe write triggers email
echo "# Eval Smoke Recipe\n\nA test recipe." > /tmp/test/docs/cortex/recipes/eval-smoke-recipe.md
sleep 30
# Manual: check calen.walshe@gmail.com inbox for subject "Recipe: Eval Smoke Recipe"
grep "eval-smoke-recipe" ~/.claude/hooks/logs/cortex-distribute.log | grep "email.*success"

# FC-02: Research write triggers NLM notebook
echo "# Eval Smoke Research\n\nA test dossier." > /tmp/test/docs/cortex/research/canonical-deliverable-distribution-system/eval-smoke-research.md
sleep 30
nlm notebook list | grep -i "eval smoke research"
grep "eval-smoke-research" ~/.claude/hooks/logs/cortex-distribute.log | grep "notebooklm.*success"

# FC-03: Off-target path does NOT trigger distribution
echo "# Off Target" > /tmp/test/docs/cortex/specs/canonical-deliverable-distribution-system/eval-off-target.md
sleep 5
grep "eval-off-target" ~/.claude/hooks/logs/cortex-distribute.log | grep "early.exit\|no.match"
# Expected: log shows early exit OR no entry at all for this path

# FC-04: Hook is async (Claude Write returns before distribution completes)
# Verified implicitly: if Write tool does not block visibly, async is confirmed.
# Explicit check: hook subprocess PID should be alive immediately after Write returns.

# FC-05: Gmail failure does not crash hook
mv ~/.gmail_creds.json ~/.gmail_creds.json.bak
echo "# Failure Test" > /tmp/test/docs/cortex/recipes/eval-failure-test.md
sleep 10
grep "eval-failure-test" ~/.claude/hooks/logs/cortex-distribute.log | grep -i "error\|fail"
mv ~/.gmail_creds.json.bak ~/.gmail_creds.json
# Expected: failure logged, hook exited 0, no crash
```

**Pass criteria:** All 5 checks produce expected output. FC-01 and FC-02 require manual inbox/NLM verification.

---

## Dimension 2: Regression

**Goal:** Existing PostToolUse hooks (`cortex-sync.sh`, `cortex-validator-trigger.sh`) unchanged.

### Tests

```bash
# REG-01: settings.json PostToolUse array count
BEFORE=$(cat ~/.claude/settings.json | jq '[.hooks[] | select(.event=="PostToolUse")] | length')
# After registration: 
AFTER=$(cat ~/.claude/settings.json | jq '[.hooks[] | select(.event=="PostToolUse")] | length')
echo "Before: $BEFORE, After: $AFTER"
# Expected: AFTER == BEFORE + 1

# REG-02: cortex-sync.sh still fires on skill writes
# Trigger a write to ~/.claude/skills/cortex-test/SKILL.md (or any skill path)
# Confirm cortex-sync.sh log or downstream sync artifact updated

# REG-03: No existing hook entries mutated
jq '[.hooks[] | select(.event=="PostToolUse") | select(.hooks[].command | contains("cortex-sync") or contains("cortex-validator"))]' ~/.claude/settings.json
# Expected: both entries present and unmodified
```

**Pass criteria:** AFTER = BEFORE + 1, both existing hooks confirmed active.

---

## Dimension 3: Integration

**Goal:** Three-component chain works across process boundaries.

### Tests

```bash
# INT-01: Probe — stdin JSON schema
# Run cortex-distribute-probe.sh, trigger a write, inspect probe.log
cat ~/.claude/hooks/test/probe.log | jq '.tool_input | keys'
# Expected: ["content", "file_path"] present

# INT-02: MCP subprocess — notebook_create reachable
cat ~/.claude/hooks/test/mcp-probe.log
# Expected: notebook_id returned OR "MCP unavailable, using nlm CLI fallback" logged

# INT-03: Tmpfile handoff for large content (≥ 10KB)
python3 -c "print('# Large Doc\n' + 'x ' * 5000)" > /tmp/test/docs/cortex/research/canonical-deliverable-distribution-system/eval-large-doc.md
sleep 30
grep "eval-large-doc" ~/.claude/hooks/logs/cortex-distribute.log | grep "success"
# Expected: success despite large content

# INT-04: End-to-end timing
# Single Write event → email received + NLM notebook created within 60s
# Verified by FC-01 and FC-02 combined
```

**Pass criteria:** INT-01 confirms stdin schema; INT-02 confirms MCP or fallback; INT-03 confirms large content handled; INT-04 covered by FC-01/FC-02 timing.

---

## Dimension 4: Safety/Security

**Goal:** Gmail credentials never leak; tmpfiles cleaned up.

### Tests

```bash
# SEC-01: app_password not in log
grep -c "app_password\|gmail_password" ~/.claude/hooks/logs/cortex-distribute.log
# Expected: 0

# SEC-02: app_password not in process args (would appear in ps output)
# During a distribution run: ps aux | grep cortex-distribute
# Expected: no password string visible

# SEC-03: tmpfile deleted after Python exits
# Instrument cortex-distribute.sh to log tmpfile path, then check it's gone
ls /tmp/cortex-distribute-* 2>/dev/null | wc -l
# Expected: 0 (or only in-flight files if a distribution is active)

# SEC-04: Malformed stdin does not crash
echo "" | bash ~/.claude/hooks/cortex-distribute.sh
echo $?
# Expected: exit code 0

echo "not json" | bash ~/.claude/hooks/cortex-distribute.sh
echo $?
# Expected: exit code 0
```

**Pass criteria:** All 4 checks pass. SEC-01 is mandatory — failure here is a hard block.

---

## Dimension 5: Resilience

**Goal:** External failures are isolated; hook always exits 0.

### Tests

```bash
# RES-01: Gmail SMTP unreachable
mv ~/.gmail_creds.json ~/.gmail_creds.json.bak
echo "# Resilience Test" > /tmp/test/docs/cortex/recipes/eval-resilience-recipe.md
sleep 10
grep "eval-resilience-recipe" ~/.claude/hooks/logs/cortex-distribute.log | grep -i "error\|fail\|smtp"
mv ~/.gmail_creds.json.bak ~/.gmail_creds.json
# Expected: failure logged with stack trace; hook exit 0

# RES-02: NotebookLM MCP + nlm CLI both fail
# Temporarily make nlm unavailable: PATH_BAK=$PATH; export PATH=/usr/bin
# Trigger a research write
# Expected: failure logged, hook exits 0
# Restore: export PATH=$PATH_BAK

# RES-03: Concurrent writes (two files in rapid succession)
echo "# Recipe A" > /tmp/test/docs/cortex/recipes/eval-concurrent-a.md && echo "# Recipe B" > /tmp/test/docs/cortex/recipes/eval-concurrent-b.md
sleep 30
grep "eval-concurrent" ~/.claude/hooks/logs/cortex-distribute.log | wc -l
# Expected: 2 entries (one per file), no interleaved corruption in log
```

**Pass criteria:** RES-01 and RES-02 confirm graceful failure; RES-03 confirms log append-safety.

---

## Dimension 6: Style

**Goal:** New code passes static analysis with zero errors.

### Tests

```bash
# STY-01: Shell
shellcheck ~/.claude/hooks/cortex-distribute.sh
# Expected: exit 0, zero errors, zero warnings

# STY-02: Python
ruff check ~/.claude/hooks/cortex-distribute.py 2>/dev/null || flake8 ~/.claude/hooks/cortex-distribute.py
# Expected: exit 0, zero issues

# STY-03: Python function length
awk '/^def /{fn=$0; count=0} /^def /{if(count>30) print fn" is "count" lines"} {count++}' ~/.claude/hooks/cortex-distribute.py
# Expected: no functions > 30 lines

# STY-04: No bare except
grep -n "except:" ~/.claude/hooks/cortex-distribute.py
# Expected: no matches

# STY-05: Shell safety guard
head -3 ~/.claude/hooks/cortex-distribute.sh | grep -E "set -.*e.*u|set -euo pipefail"
# Expected: match found
```

**Pass criteria:** All 5 checks zero errors. STY-01 and STY-02 are hard gates.

---

## Dimension 7: UX/Taste

**Goal:** Email and NLM output are readable and well-formatted. Human approval required.

### Review Checklist (human judgment)

Run the smoke test (FC-01, FC-02). Then review:

**Email (check inbox at calen.walshe@gmail.com):**
- [ ] Subject line is human-readable: e.g. `"Recipe: Eval Smoke Recipe"` — not a raw filename or slug
- [ ] Body contains no raw markdown: no `#`, `**`, or `---` visible in plain text
- [ ] Section headers are rendered as ALL CAPS plain text
- [ ] No frontmatter (slug, timestamp, generated) leaked into email body
- [ ] Email is readable on mobile without horizontal scrolling

**NotebookLM (check NLM UI or `nlm notebook list`):**
- [ ] Notebook title format: `"Research — Eval Smoke Research"` — readable, not a filename
- [ ] Content renders correctly as a text source in NLM (not corrupted)

**Pass criteria:** Human reviews email + NLM notebook and checks all boxes above. This dimension requires explicit human sign-off before the eval is considered complete.

---

## Run Order

1. STY-01, STY-02, STY-03, STY-04, STY-05 (static — run first, fast)
2. REG-01, REG-03 (settings.json inspection — fast)
3. SEC-04 (malformed input — fast, no network)
4. INT-01, INT-02 (probe tests — must pass before live tests)
5. FC-01, FC-02, FC-03 (live distribution — requires email + NLM access)
6. FC-05, RES-01, RES-02 (failure simulation)
7. INT-03, RES-03 (large content, concurrency)
8. SEC-01, SEC-02, SEC-03 (credential leak checks — run after live tests have generated log entries)
9. UX-01 (human review — run last, after email and NLM artifacts exist)

---

## Thresholds

| Metric | Threshold |
|--------|-----------|
| Email delivery | Within 30s of Write tool returning |
| NLM notebook creation | Within 60s of Write tool returning |
| Hook overhead for non-matching paths | < 100ms (exit 0 immediately) |
| Log entry present for every distribution attempt | 100% (no silent failures) |
