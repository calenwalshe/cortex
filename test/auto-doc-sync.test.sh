#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK_SCRIPT="$REPO_DIR/hooks/auto-doc-sync.sh"
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

# Create a temp directory for each test's git repo
setup_test_repo() {
  local test_dir
  test_dir=$(mktemp -d)
  cd "$test_dir"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"

  # Copy hook script
  cp "$HOOK_SCRIPT" "$test_dir/hook.sh"
  chmod +x "$test_dir/hook.sh"

  # Create minimal config
  cat > "$test_dir/.auto-doc-sync.json" << 'CFGEOF'
[
  {
    "id": "test-skill",
    "source_glob": "skills/test-skill/SKILL.md",
    "target_doc": "docs/COMMANDS.md",
    "target_section": "## /test-skill",
    "prompt_hint": "Update Purpose and Inputs only."
  }
]
CFGEOF

  # Create target doc
  mkdir -p docs
  cat > docs/COMMANDS.md << 'DOCEOF'
# Commands

## /test-skill

**Purpose:** Does test things.

**Inputs:** None.

## /other-skill

**Purpose:** Other stuff.
DOCEOF

  # Create source file
  mkdir -p skills/test-skill
  echo "# Test Skill" > skills/test-skill/SKILL.md

  # Initial commit
  git add -A
  git commit -q -m "initial"

  echo "$test_dir"
}

cleanup_test_repo() {
  local test_dir="$1"
  cd /
  rm -rf "$test_dir"
}

echo ""
echo "Auto-Doc-Sync Test Suite"
echo "$(printf '─%.0s' {1..50})"

# ── Test 1: skip-if-no-key ────────────────────────────────────

echo ""
echo "1. Skip when ANTHROPIC_API_KEY is unset"
TEST_DIR=$(setup_test_repo)
cd "$TEST_DIR"

# Stage a mapped file
echo "# Updated" > skills/test-skill/SKILL.md
git add skills/test-skill/SKILL.md

OUTPUT=$(unset ANTHROPIC_API_KEY; SKIP_LLM_GITHOOK="" SKIP="" bash hook.sh 2>&1) || true
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]] && echo "$OUTPUT" | grep -qF "ANTHROPIC_API_KEY is not set"; then
  assert_pass "exits 0 and warns when ANTHROPIC_API_KEY unset"
else
  assert_fail "exits 0 and warns when ANTHROPIC_API_KEY unset" "exit=$EXIT_CODE output=$OUTPUT"
fi

cleanup_test_repo "$TEST_DIR"

# ── Test 2: skip-if-no-match ─────────────────────────────────

echo ""
echo "2. Skip when no staged files match any mapping"
TEST_DIR=$(setup_test_repo)
cd "$TEST_DIR"

# Stage an unmapped file
echo "unrelated" > README.md
git add README.md

OUTPUT=$(ANTHROPIC_API_KEY="test-key" SKIP_LLM_GITHOOK="" SKIP="" bash hook.sh 2>&1) || true
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]] && [[ -z "$OUTPUT" ]]; then
  assert_pass "exits 0 silently when no files match"
else
  assert_fail "exits 0 silently when no files match" "exit=$EXIT_CODE output=$OUTPUT"
fi

cleanup_test_repo "$TEST_DIR"

# ── Test 3: skip-if-staged ───────────────────────────────────

echo ""
echo "3. Skip when target doc is already staged"
TEST_DIR=$(setup_test_repo)
cd "$TEST_DIR"

# Stage both source and target
echo "# Updated skill" > skills/test-skill/SKILL.md
echo "# Updated docs" >> docs/COMMANDS.md
git add skills/test-skill/SKILL.md docs/COMMANDS.md

OUTPUT=$(ANTHROPIC_API_KEY="test-key" SKIP_LLM_GITHOOK="" SKIP="" FORCE_DOC_SYNC="" bash hook.sh 2>&1) || true
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]] && echo "$OUTPUT" | grep -qF "already staged"; then
  assert_pass "exits 0 and reports skip when target is staged"
else
  assert_fail "exits 0 and reports skip when target is staged" "exit=$EXIT_CODE output=$OUTPUT"
fi

cleanup_test_repo "$TEST_DIR"

# ── Test 4: skip-if-marker ───────────────────────────────────

echo ""
echo "4. Skip when target doc has skip marker"
TEST_DIR=$(setup_test_repo)
cd "$TEST_DIR"

# Add skip marker to target doc
sed -i '1i <!-- auto-doc-sync:skip -->' docs/COMMANDS.md
git add docs/COMMANDS.md
git commit -q -m "add skip marker"

# Now stage a source change
echo "# New content" > skills/test-skill/SKILL.md
git add skills/test-skill/SKILL.md

OUTPUT=$(ANTHROPIC_API_KEY="test-key" SKIP_LLM_GITHOOK="" SKIP="" bash hook.sh 2>&1) || true
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]] && echo "$OUTPUT" | grep -qF "skip marker found"; then
  assert_pass "exits 0 and reports skip when marker present"
else
  assert_fail "exits 0 and reports skip when marker present" "exit=$EXIT_CODE output=$OUTPUT"
fi

cleanup_test_repo "$TEST_DIR"

# ── Test 5: valid-response-parse ─────────────────────────────

echo ""
echo "5. Parse valid JSON response and write target file"
TEST_DIR=$(setup_test_repo)
cd "$TEST_DIR"

# Stage a source change
echo -e "# Test Skill\n\nNew behavior added." > skills/test-skill/SKILL.md
git add skills/test-skill/SKILL.md

# Create a mock curl that returns a valid API response
MOCK_DIR=$(mktemp -d)
cat > "$MOCK_DIR/curl" << 'CURLEOF'
#!/usr/bin/env bash
# Mock curl — returns a valid Anthropic API response
cat << 'RESPEOF'
{
  "content": [
    {
      "type": "text",
      "text": "[{\"target_doc\": \"docs/COMMANDS.md\", \"target_section\": \"## /test-skill\", \"updated_content\": \"## /test-skill\\n\\n**Purpose:** Does test things with new behavior.\\n\\n**Inputs:** A string argument.\"}]"
    }
  ]
}
RESPEOF
CURLEOF
chmod +x "$MOCK_DIR/curl"

# Save original doc for comparison
ORIGINAL=$(cat docs/COMMANDS.md)

OUTPUT=$(PATH="$MOCK_DIR:$PATH" ANTHROPIC_API_KEY="test-key" SKIP_LLM_GITHOOK="" SKIP="" bash hook.sh 2>&1) || true
EXIT_CODE=$?

UPDATED=$(cat docs/COMMANDS.md)

if [[ $EXIT_CODE -eq 0 ]] && [[ "$ORIGINAL" != "$UPDATED" ]] && echo "$UPDATED" | grep -qF "new behavior"; then
  assert_pass "writes updated content to target doc"
else
  assert_fail "writes updated content to target doc" "exit=$EXIT_CODE"
fi

# Verify git add was NOT called (file should not be staged)
STAGED_AFTER=$(git diff --cached --name-only docs/COMMANDS.md 2>/dev/null || true)
if [[ -z "$STAGED_AFTER" ]]; then
  assert_pass "does not stage the updated file"
else
  assert_fail "does not stage the updated file" "docs/COMMANDS.md was staged"
fi

rm -rf "$MOCK_DIR"
cleanup_test_repo "$TEST_DIR"

# ── Test 6: invalid-response-handle ──────────────────────────

echo ""
echo "6. Handle invalid JSON response gracefully"
TEST_DIR=$(setup_test_repo)
cd "$TEST_DIR"

# Stage a source change
echo -e "# Test Skill\n\nAnother change." > skills/test-skill/SKILL.md
git add skills/test-skill/SKILL.md

# Create a mock curl that returns invalid JSON
MOCK_DIR=$(mktemp -d)
cat > "$MOCK_DIR/curl" << 'CURLEOF'
#!/usr/bin/env bash
cat << 'RESPEOF'
{
  "content": [
    {
      "type": "text",
      "text": "This is not valid JSON at all {broken"
    }
  ]
}
RESPEOF
CURLEOF
chmod +x "$MOCK_DIR/curl"

ORIGINAL=$(cat docs/COMMANDS.md)

OUTPUT=$(PATH="$MOCK_DIR:$PATH" ANTHROPIC_API_KEY="test-key" SKIP_LLM_GITHOOK="" SKIP="" bash hook.sh 2>&1) || true
EXIT_CODE=$?

AFTER=$(cat docs/COMMANDS.md)

if [[ $EXIT_CODE -eq 0 ]] && echo "$OUTPUT" | grep -qF "Invalid JSON"; then
  assert_pass "exits 0 and warns on invalid JSON"
else
  assert_fail "exits 0 and warns on invalid JSON" "exit=$EXIT_CODE output=$OUTPUT"
fi

if [[ "$ORIGINAL" == "$AFTER" ]]; then
  assert_pass "does not modify target file on invalid response"
else
  assert_fail "does not modify target file on invalid response" "file was modified"
fi

rm -rf "$MOCK_DIR"
cleanup_test_repo "$TEST_DIR"

# ── Summary ──────────────────────────────────────────────────

echo ""
echo "$(printf '─%.0s' {1..50})"
TOTAL=$((PASS + FAIL))
echo "Results: $PASS/$TOTAL passed, $FAIL failed"

if [[ $FAIL -gt 0 ]]; then
  echo "SOME TESTS FAILED"
  exit 1
fi

echo "ALL TESTS PASSED"
exit 0
