#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST_PATH="$REPO_DIR/runtime-manifest.json"
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

readarray -t SKILLS < <(python3 -c "import json; d=json.load(open('$MANIFEST_PATH')); [print(x['name'] if isinstance(x, dict) else x) for x in d['skills'] if (x.get('profiles', ['core','full']) if isinstance(x, dict) else ['core','full']).__contains__('core')]")
SKILL_FAILS=0
for skill in "${SKILLS[@]}"; do
  if [ ! -L "$TEST_HOME/.claude/skills/$skill" ]; then
    SKILL_FAILS=$((SKILL_FAILS + 1))
  fi
done
if [ "$SKILL_FAILS" -eq 0 ]; then
  assert_pass "all ${#SKILLS[@]} core skills symlinked to ~/.claude/skills/"
else
  assert_fail "all ${#SKILLS[@]} core skills symlinked" "$SKILL_FAILS skills missing"
fi

readarray -t AGENTS < <(python3 -c "import json; d=json.load(open('$MANIFEST_PATH')); [print(x) for x in d['agents']]")
AGENT_FAILS=0
for agent in "${AGENTS[@]}"; do
  if [ ! -L "$TEST_HOME/.claude/agents/$agent" ]; then
    AGENT_FAILS=$((AGENT_FAILS + 1))
  fi
done
if [ "$AGENT_FAILS" -eq 0 ]; then
  assert_pass "all ${#AGENTS[@]} agents symlinked to ~/.claude/agents/"
else
  assert_fail "all ${#AGENTS[@]} agents symlinked" "$AGENT_FAILS agents missing"
fi

readarray -t HOOKS < <(python3 -c "import json; d=json.load(open('$MANIFEST_PATH')); [print(x['file']) for x in d['hooks']]")
HOOK_FAILS=0
for hook in "${HOOKS[@]}"; do
  if [ ! -L "$TEST_HOME/.claude/hooks/$hook" ]; then
    HOOK_FAILS=$((HOOK_FAILS + 1))
  fi
done
if [ "$HOOK_FAILS" -eq 0 ]; then
  assert_pass "all ${#HOOKS[@]} hooks symlinked to ~/.claude/hooks/"
else
  assert_fail "all ${#HOOKS[@]} hooks symlinked" "$HOOK_FAILS hooks missing"
fi

echo ""
echo "2b. Project runtime bootstrap"
TARGET_PROJECT="$TEST_HOME/target-project"
HOME="$TEST_HOME" node "$REPO_DIR/bin/install.js" --project "$TARGET_PROJECT" > /dev/null 2>&1
if [ -d "$TARGET_PROJECT/docs/cortex" ] && [ -f "$TARGET_PROJECT/.cortex/state.json" ]; then
  assert_pass "project bootstrap creates docs/cortex and .cortex/state.json"
else
  assert_fail "project bootstrap runtime scaffold" "missing docs/cortex or .cortex/state.json"
fi

DIRTY_SCHEMA_OK=$(python3 -c "
import json, sys
with open('$TARGET_PROJECT/.cortex/dirty-files.json') as f:
    data = json.load(f)
print('ok' if isinstance(data, dict) and isinstance(data.get('dirty'), list) else 'bad')
" 2>/dev/null || echo "bad")
if [ "$DIRTY_SCHEMA_OK" = "ok" ]; then
  assert_pass "dirty-files.json uses {\"dirty\": []} schema"
else
  assert_fail "dirty-files schema" "expected object with dirty array"
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
manifest = json.load(open('$MANIFEST_PATH'))
expected = len(manifest['hook_events'])
with open('$TEST_HOME/.claude/settings.json') as f:
    s = json.load(f)
hooks = s.get('hooks', {})
count = 0
for event, entries in hooks.items():
    for entry in entries:
        for h in entry.get('hooks', []):
            cmd = h.get('command', '')
            if 'cortex-' in cmd or 'token-ledger' in cmd:
                count += 1
print(f'{count}:{expected}')
" 2>/dev/null || echo "0")

# Run a third time to check no duplicates were added
HOME="$TEST_HOME" node "$REPO_DIR/bin/install.js" > /dev/null 2>&1
CORTEX_ENTRIES_AFTER=$(python3 -c "
import json, sys
manifest = json.load(open('$MANIFEST_PATH'))
expected = len(manifest['hook_events'])
with open('$TEST_HOME/.claude/settings.json') as f:
    s = json.load(f)
hooks = s.get('hooks', {})
count = 0
for event, entries in hooks.items():
    for entry in entries:
        for h in entry.get('hooks', []):
            cmd = h.get('command', '')
            if 'cortex-' in cmd or 'token-ledger' in cmd:
                count += 1
print(f'{count}:{expected}')
" 2>/dev/null || echo "0")

if [ "$CORTEX_ENTRIES" = "$CORTEX_ENTRIES_AFTER" ] && [ "${CORTEX_ENTRIES%%:*}" -eq "${CORTEX_ENTRIES##*:}" ] && [ "${CORTEX_ENTRIES%%:*}" -gt 0 ]; then
  assert_pass "settings.json has ${CORTEX_ENTRIES%%:*} cortex entries (manifest-aligned), no duplicates after third run"
else
  assert_fail "settings.json dedup" "entries before=$CORTEX_ENTRIES after=$CORTEX_ENTRIES_AFTER (expected equal and > 0)"
fi

echo ""
echo "4b. Repo settings manifest sync"
RENDERED_SETTINGS="$(mktemp)"
node "$REPO_DIR/bin/render-project-settings.js" "$RENDERED_SETTINGS"
if cmp -s "$RENDERED_SETTINGS" "$REPO_DIR/.claude/settings.json"; then
  assert_pass ".claude/settings.json is generated from runtime-manifest.json"
else
  assert_fail "repo settings sync" "run: node bin/render-project-settings.js .claude/settings.json"
fi
rm -f "$RENDERED_SETTINGS"

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

# ── Test 6: profile=core installs only framework skills ───
echo ""
echo "6. Profile: core"
CORE_HOME="$(mktemp -d)"
trap 'rm -rf "$CORE_HOME"' EXIT
mkdir -p "$CORE_HOME/.claude/skills" "$CORE_HOME/.claude/hooks"
echo '{}' > "$CORE_HOME/.claude/settings.json"
mkdir -p "$CORE_HOME/projects"
ln -s "$REPO_DIR" "$CORE_HOME/projects/cortex"

HOME="$CORE_HOME" node "$REPO_DIR/bin/install.js" --profile=core > /dev/null 2>&1

# core-profile skills should be symlinked
readarray -t CORE_SKILLS < <(python3 -c "import json; d=json.load(open('$MANIFEST_PATH')); [print(x['name'] if isinstance(x,dict) else x) for x in d['skills'] if ('core' in (x.get('profiles',['core','full']) if isinstance(x,dict) else ['core','full']))]")
CORE_SKILL_FAILS=0
for skill in "${CORE_SKILLS[@]}"; do
  if [ ! -L "$CORE_HOME/.claude/skills/$skill" ]; then
    CORE_SKILL_FAILS=$((CORE_SKILL_FAILS + 1))
  fi
done
if [ "$CORE_SKILL_FAILS" -eq 0 ]; then
  assert_pass "--profile=core: all ${#CORE_SKILLS[@]} framework skills symlinked"
else
  assert_fail "--profile=core: framework skills" "$CORE_SKILL_FAILS missing"
fi

# full-only skills must NOT be symlinked
readarray -t FULL_ONLY_SKILLS < <(python3 -c "import json; d=json.load(open('$MANIFEST_PATH')); [print(x['name'] if isinstance(x,dict) else x) for x in d['skills'] if isinstance(x,dict) and x.get('profiles') == ['full']]")
UNWANTED_FAILS=0
for skill in "${FULL_ONLY_SKILLS[@]}"; do
  if [ -L "$CORE_HOME/.claude/skills/$skill" ] || [ -e "$CORE_HOME/.claude/skills/$skill" ]; then
    UNWANTED_FAILS=$((UNWANTED_FAILS + 1))
  fi
done
if [ "$UNWANTED_FAILS" -eq 0 ]; then
  assert_pass "--profile=core: no tool skill symlinks (web/ai/google/cli absent)"
else
  assert_fail "--profile=core: tool skill symlinks should be absent" "$UNWANTED_FAILS found"
fi

# .cortex-profile marker must contain "core"
MARKER_VAL="$(cat "$CORE_HOME/.claude/.cortex-profile" 2>/dev/null || echo '')"
if [ "$MARKER_VAL" = "core" ]; then
  assert_pass "--profile=core: ~/.claude/.cortex-profile contains 'core'"
else
  assert_fail "--profile=core: .cortex-profile" "expected 'core', got '$MARKER_VAL'"
fi

# core output must not mention API keys
CORE_OUTPUT="$(HOME="$CORE_HOME" node "$REPO_DIR/bin/install.js" --profile=core 2>&1)"
if echo "$CORE_OUTPUT" | grep -qE "TAVILY_API_KEY|PPLX_API_KEY|FIRECRAWL_API_KEY|GEMINI_API_KEY"; then
  assert_fail "--profile=core: output must not mention API keys" "API key string found"
else
  assert_pass "--profile=core: output contains no API key references"
fi

rm -rf "$CORE_HOME"

# ── Test 7: profile=full installs all skills ───────────────
echo ""
echo "7. Profile: full"
FULL_HOME="$(mktemp -d)"
trap 'rm -rf "$FULL_HOME"' EXIT
mkdir -p "$FULL_HOME/.claude/skills" "$FULL_HOME/.claude/hooks"
echo '{}' > "$FULL_HOME/.claude/settings.json"
mkdir -p "$FULL_HOME/projects"
ln -s "$REPO_DIR" "$FULL_HOME/projects/cortex"

HOME="$FULL_HOME" node "$REPO_DIR/bin/install.js" --profile=full > /dev/null 2>&1

readarray -t ALL_SKILLS < <(python3 -c "import json; d=json.load(open('$MANIFEST_PATH')); [print(x['name'] if isinstance(x,dict) else x) for x in d['skills']]")
FULL_SKILL_FAILS=0
for skill in "${ALL_SKILLS[@]}"; do
  if [ ! -L "$FULL_HOME/.claude/skills/$skill" ]; then
    FULL_SKILL_FAILS=$((FULL_SKILL_FAILS + 1))
  fi
done
if [ "$FULL_SKILL_FAILS" -eq 0 ]; then
  assert_pass "--profile=full: all ${#ALL_SKILLS[@]} skills symlinked (framework + tool)"
else
  assert_fail "--profile=full: skills" "$FULL_SKILL_FAILS missing"
fi

FULL_MARKER="$(cat "$FULL_HOME/.claude/.cortex-profile" 2>/dev/null || echo '')"
if [ "$FULL_MARKER" = "full" ]; then
  assert_pass "--profile=full: ~/.claude/.cortex-profile contains 'full'"
else
  assert_fail "--profile=full: .cortex-profile" "expected 'full', got '$FULL_MARKER'"
fi

rm -rf "$FULL_HOME"

# ── Test 8: core→full upgrade adds tool skills ─────────────
echo ""
echo "8. Upgrade: core → full"
UPGRADE_HOME="$(mktemp -d)"
trap 'rm -rf "$UPGRADE_HOME"' EXIT
mkdir -p "$UPGRADE_HOME/.claude/skills" "$UPGRADE_HOME/.claude/hooks"
echo '{}' > "$UPGRADE_HOME/.claude/settings.json"
mkdir -p "$UPGRADE_HOME/projects"
ln -s "$REPO_DIR" "$UPGRADE_HOME/projects/cortex"

HOME="$UPGRADE_HOME" node "$REPO_DIR/bin/install.js" --profile=core > /dev/null 2>&1
HOME="$UPGRADE_HOME" node "$REPO_DIR/bin/install.js" --profile=full > /dev/null 2>&1

# All skills present after upgrade
UPGRADE_FAILS=0
for skill in "${ALL_SKILLS[@]}"; do
  if [ ! -L "$UPGRADE_HOME/.claude/skills/$skill" ]; then
    UPGRADE_FAILS=$((UPGRADE_FAILS + 1))
  fi
done
if [ "$UPGRADE_FAILS" -eq 0 ]; then
  assert_pass "core→full upgrade: all ${#ALL_SKILLS[@]} skills present after upgrade"
else
  assert_fail "core→full upgrade" "$UPGRADE_FAILS skills missing after upgrade"
fi

UPGRADE_MARKER="$(cat "$UPGRADE_HOME/.claude/.cortex-profile" 2>/dev/null || echo '')"
if [ "$UPGRADE_MARKER" = "full" ]; then
  assert_pass "core→full upgrade: .cortex-profile updated to 'full'"
else
  assert_fail "core→full upgrade: .cortex-profile" "expected 'full', got '$UPGRADE_MARKER'"
fi

rm -rf "$UPGRADE_HOME"

# ── Summary ────────────────────────────────────────────────
echo ""
echo "$(printf '─%.0s' {1..50})"
echo "Results: $PASS passed, $FAIL failed"
echo ""

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
