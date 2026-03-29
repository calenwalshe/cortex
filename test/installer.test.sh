#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

assert_pass() {
  local name="$1"
  PASS=$((PASS + 1))
  printf "  PASS  %s\n" "$name"
}

assert_fail() {
  local name="$1"
  local msg="$2"
  FAIL=$((FAIL + 1))
  printf "  FAIL  %s — %s\n" "$name" "$msg"
}

echo ""
echo "Cortex Installer Test Suite"
echo "$(printf '─%.0s' {1..50})"

# ── Setup: isolated temp HOME ──────────────────────────────
TEST_HOME="$(mktemp -d)"
trap 'rm -rf "$TEST_HOME"' EXIT

# Create ~/.claude skeleton (Claude Code always has this)
mkdir -p "$TEST_HOME/.claude/skills" "$TEST_HOME/.claude/hooks"
echo '{}' > "$TEST_HOME/.claude/settings.json"

# Point ~/projects/cortex → real repo (so live install has source files)
mkdir -p "$TEST_HOME/projects"
ln -s "$REPO_DIR" "$TEST_HOME/projects/cortex"

# ── Test 1: dry-run exits 0 when repo absent ───────────────
echo ""
echo "1. Dry-run without repo"
DRY_TEST_HOME="$(mktemp -d)"
trap 'rm -rf "$DRY_TEST_HOME"' EXIT
mkdir -p "$DRY_TEST_HOME/.claude"
echo '{}' > "$DRY_TEST_HOME/.claude/settings.json"
# No projects/cortex created — repo is absent
if HOME="$DRY_TEST_HOME" node "$REPO_DIR/bin/install.js" --dry-run > /dev/null 2>&1; then
  assert_pass "dry-run exits 0 when repo absent"
else
  assert_fail "dry-run exits 0 when repo absent" "exited non-zero"
fi
rm -rf "$DRY_TEST_HOME"

# ── Test 2: symlinks after live install ────────────────────
echo ""
echo "2. Live install symlinks"
HOME="$TEST_HOME" node "$REPO_DIR/bin/install.js" > /dev/null 2>&1

SKILL_FAILS=0
for skill in cortex-audit cortex-clarify cortex-investigate cortex-research cortex-review cortex-spec cortex-status; do
  if [ ! -L "$TEST_HOME/.claude/skills/$skill" ]; then
    SKILL_FAILS=$((SKILL_FAILS + 1))
  fi
done
if [ "$SKILL_FAILS" -eq 0 ]; then
  assert_pass "all 7 skills symlinked to ~/.claude/skills/"
else
  assert_fail "all 7 skills symlinked" "$SKILL_FAILS skills missing"
fi

AGENT_FAILS=0
for agent in cortex-critic.md cortex-eval-designer.md cortex-scribe.md cortex-specifier.md; do
  if [ ! -L "$TEST_HOME/.claude/agents/$agent" ]; then
    AGENT_FAILS=$((AGENT_FAILS + 1))
  fi
done
if [ "$AGENT_FAILS" -eq 0 ]; then
  assert_pass "all 4 agents symlinked to ~/.claude/agents/"
else
  assert_fail "all 4 agents symlinked" "$AGENT_FAILS agents missing"
fi

HOOK_FAILS=0
for hook in cortex-phase-guard.sh cortex-postcompact.sh cortex-precompact.sh cortex-session-end.sh cortex-session-start.sh cortex-sync.sh cortex-task-completed.sh cortex-task-created.sh cortex-teammate-idle.sh cortex-validator-trigger.sh cortex-write-guard.sh; do
  if [ ! -L "$TEST_HOME/.claude/hooks/$hook" ]; then
    HOOK_FAILS=$((HOOK_FAILS + 1))
  fi
done
if [ "$HOOK_FAILS" -eq 0 ]; then
  assert_pass "all 11 hooks symlinked to ~/.claude/hooks/"
else
  assert_fail "all 11 hooks symlinked" "$HOOK_FAILS hooks missing"
fi

# ── Test 3: idempotency ────────────────────────────────────
echo ""
echo "3. Idempotency (second run)"
if HOME="$TEST_HOME" node "$REPO_DIR/bin/install.js" 2>&1 | grep -q "error"; then
  assert_fail "second run clean" "error found in output"
else
  assert_pass "second run exits 0, no errors"
fi

# ── Test 4: settings.json dedup ────────────────────────────
echo ""
echo "4. Settings.json dedup"
CORTEX_ENTRIES=$(python3 -c "
import json, sys
with open('$TEST_HOME/.claude/settings.json') as f:
    s = json.load(f)
hooks = s.get('hooks', {})
count = 0
for event, entries in hooks.items():
    for entry in entries:
        for h in entry.get('hooks', []):
            if 'cortex-' in h.get('command', ''):
                count += 1
print(count)
" 2>/dev/null || echo "0")

# Run a third time to check no duplicates were added
HOME="$TEST_HOME" node "$REPO_DIR/bin/install.js" > /dev/null 2>&1
CORTEX_ENTRIES_AFTER=$(python3 -c "
import json, sys
with open('$TEST_HOME/.claude/settings.json') as f:
    s = json.load(f)
hooks = s.get('hooks', {})
count = 0
for event, entries in hooks.items():
    for entry in entries:
        for h in entry.get('hooks', []):
            if 'cortex-' in h.get('command', ''):
                count += 1
print(count)
" 2>/dev/null || echo "0")

if [ "$CORTEX_ENTRIES" -eq "$CORTEX_ENTRIES_AFTER" ] && [ "$CORTEX_ENTRIES" -gt 0 ]; then
  assert_pass "settings.json has $CORTEX_ENTRIES cortex entries, no duplicates after third run"
else
  assert_fail "settings.json dedup" "entries before=$CORTEX_ENTRIES after=$CORTEX_ENTRIES_AFTER (expected equal and > 0)"
fi

# ── Test 5: credential audit ───────────────────────────────
echo ""
echo "5. Credential audit"
CRED_COUNT=$({ grep -rn 'https://.*:.*@' \
  "$REPO_DIR/bin/" \
  "$REPO_DIR/hooks/" \
  "$REPO_DIR/.claude/" \
  "$REPO_DIR/scripts/" \
  --include='*.sh' --include='*.js' 2>/dev/null || true; } | wc -l)
if [ "$CRED_COUNT" -eq 0 ]; then
  assert_pass "no credential URLs in bin/, hooks/, .claude/, scripts/"
else
  assert_fail "credential audit" "$CRED_COUNT credential URL(s) found"
fi

# ── Summary ────────────────────────────────────────────────
echo ""
echo "$(printf '─%.0s' {1..50})"
echo "Results: $PASS passed, $FAIL failed"
echo ""

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
