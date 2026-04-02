#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESOLVER="$REPO_DIR/scripts/cortex/resolve-autonomy.js"
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
echo "Observability Test Suite (Phase 16)"
echo "$(printf '─%.0s' {1..50})"

# ── Section 1: Dry-run resolver output (AUTON-08) ─────────────────────────────

echo ""
echo "1. Dry-run resolver output (AUTON-08)"

DRY_OUTPUT=$(echo '{"_dry_run":true,"projectConfig":{"preset":"full-auto"}}' | node "$RESOLVER")

if echo "$DRY_OUTPUT" | grep -q "AUTONOMY DRY-RUN"; then
  assert_pass "dry-run output contains 'AUTONOMY DRY-RUN'"
else
  assert_fail "dry-run output contains 'AUTONOMY DRY-RUN'" "got: $DRY_OUTPUT"
fi

if echo "$DRY_OUTPUT" | grep -q "Preset: full-auto"; then
  assert_pass "dry-run output shows 'Preset: full-auto'"
else
  assert_fail "dry-run output shows 'Preset: full-auto'" "not found in output"
fi

if echo "$DRY_OUTPUT" | grep -q "ux_taste_eval" && echo "$DRY_OUTPUT" | grep "ux_taste_eval" | grep -q "mandatory"; then
  assert_pass "dry-run output shows ux_taste_eval with mandatory source"
else
  assert_fail "dry-run output shows ux_taste_eval with mandatory source" "not found"
fi

if echo "$DRY_OUTPUT" | grep -q "contract_approval" && echo "$DRY_OUTPUT" | grep "contract_approval" | grep -q "preset"; then
  assert_pass "dry-run output shows contract_approval with preset source"
else
  assert_fail "dry-run output shows contract_approval with preset source" "not found"
fi

DEFAULT_DRY=$(echo '{"_dry_run":true}' | node "$RESOLVER")
if echo "$DEFAULT_DRY" | grep -q "Preset: supervised"; then
  assert_pass "dry-run with no config defaults to 'Preset: supervised'"
else
  assert_fail "dry-run with no config defaults to 'Preset: supervised'" "got: $DEFAULT_DRY"
fi

# ── Section 2: Source-layer resolver output (AUTON-08) ────────────────────────

echo ""
echo "2. Source-layer resolver output (AUTON-08)"

SOURCES_JSON=$(echo '{"_sources":true,"projectConfig":{"preset":"full-auto"}}' | node "$RESOLVER")

UX_SRC=$(echo "$SOURCES_JSON" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>console.log(JSON.parse(d).sources.ux_taste_eval));")
if [[ "$UX_SRC" == "mandatory" ]]; then
  assert_pass "sources: ux_taste_eval source is 'mandatory'"
else
  assert_fail "sources: ux_taste_eval source is 'mandatory'" "got: $UX_SRC"
fi

CA_SRC=$(echo "$SOURCES_JSON" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>console.log(JSON.parse(d).sources.contract_approval));")
if [[ "$CA_SRC" == "preset" ]]; then
  assert_pass "sources: contract_approval source is 'preset' for full-auto"
else
  assert_fail "sources: contract_approval source is 'preset' for full-auto" "got: $CA_SRC"
fi

PROJECT_OVERRIDE_JSON=$(echo '{"_sources":true,"projectConfig":{"preset":"full-auto","gates":{"contract_approval":true}}}' | node "$RESOLVER")
CA_PROJ_SRC=$(echo "$PROJECT_OVERRIDE_JSON" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>console.log(JSON.parse(d).sources.contract_approval));")
if [[ "$CA_PROJ_SRC" == "project" ]]; then
  assert_pass "sources: project gate override → source is 'project'"
else
  assert_fail "sources: project gate override → source is 'project'" "got: $CA_PROJ_SRC"
fi

INVOKE_JSON=$(echo '{"_sources":true,"invocationFlags":{"gates":{"slug_conflict":true}},"projectConfig":{"preset":"full-auto"}}' | node "$RESOLVER")
SLUG_INVOKE_SRC=$(echo "$INVOKE_JSON" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>console.log(JSON.parse(d).sources.slug_conflict));")
if [[ "$SLUG_INVOKE_SRC" == "invocation" ]]; then
  assert_pass "sources: invocation gate override → source is 'invocation'"
else
  assert_fail "sources: invocation gate override → source is 'invocation'" "got: $SLUG_INVOKE_SRC"
fi

# ── Section 3: Decision logging instructions (AUTON-09) ───────────────────────

echo ""
echo "3. Decision logging instructions (AUTON-09)"

DECISIONS_FILE="$REPO_DIR/docs/cortex/handoffs/decisions.md"

if grep -q "Autonomy Decisions" "$DECISIONS_FILE"; then
  assert_pass "decisions.md has 'Autonomy Decisions' section"
else
  assert_fail "decisions.md has 'Autonomy Decisions' section" "not found in $DECISIONS_FILE"
fi

if grep -q "auto-skipped" "$DECISIONS_FILE"; then
  assert_pass "decisions.md documents 'auto-skipped' format"
else
  assert_fail "decisions.md documents 'auto-skipped' format" "not found"
fi

for skill in cortex-clarify cortex-research cortex-spec cortex-review cortex-audit; do
  SKILL_FILE="$REPO_DIR/skills/$skill/SKILL.md"
  if grep -q "decisions.md" "$SKILL_FILE"; then
    assert_pass "$skill/SKILL.md references decisions.md"
  else
    assert_fail "$skill/SKILL.md references decisions.md" "not found in $SKILL_FILE"
  fi
done

# ── Section 4: --dry-run instructions in SKILL.md files (AUTON-08) ───────────

echo ""
echo "4. --dry-run instructions in SKILL.md files (AUTON-08)"

for skill in cortex-clarify cortex-research cortex-spec cortex-review cortex-audit; do
  SKILL_FILE="$REPO_DIR/skills/$skill/SKILL.md"
  if grep -q "dry-run Mode\|--dry-run Mode\|dry_run Mode" "$SKILL_FILE"; then
    assert_pass "$skill/SKILL.md has dry-run Mode section"
  else
    assert_fail "$skill/SKILL.md has dry-run Mode section" "not found in $SKILL_FILE"
  fi
done

BRIDGE_SKILL="$REPO_DIR/skills/cortex-bridge/SKILL.md"
if grep -q "resolveAutonomyWithSources" "$BRIDGE_SKILL"; then
  assert_pass "cortex-bridge/SKILL.md references resolveAutonomyWithSources"
else
  assert_fail "cortex-bridge/SKILL.md references resolveAutonomyWithSources" "not found"
fi

# ── Section 5: /cortex-status autonomy display (AUTON-12) ────────────────────

echo ""
echo "5. /cortex-status autonomy display (AUTON-12)"

STATUS_SKILL="$REPO_DIR/skills/cortex-status/SKILL.md"

if grep -q "Resolve Autonomy Config" "$STATUS_SKILL"; then
  assert_pass "cortex-status/SKILL.md has 'Resolve Autonomy Config' phase"
else
  assert_fail "cortex-status/SKILL.md has 'Resolve Autonomy Config' phase" "not found"
fi

if grep -q "Preset:" "$STATUS_SKILL"; then
  assert_pass "cortex-status/SKILL.md output template has 'Preset:'"
else
  assert_fail "cortex-status/SKILL.md output template has 'Preset:'" "not found"
fi

if grep -q "Active:" "$STATUS_SKILL"; then
  assert_pass "cortex-status/SKILL.md output template has 'Active:'"
else
  assert_fail "cortex-status/SKILL.md output template has 'Active:'" "not found"
fi

if grep -q "Skipped:" "$STATUS_SKILL"; then
  assert_pass "cortex-status/SKILL.md output template has 'Skipped:'"
else
  assert_fail "cortex-status/SKILL.md output template has 'Skipped:'" "not found"
fi

if grep -q "Mandatory:" "$STATUS_SKILL"; then
  assert_pass "cortex-status/SKILL.md output template has 'Mandatory:'"
else
  assert_fail "cortex-status/SKILL.md output template has 'Mandatory:'" "not found"
fi

if grep -q "resolve-autonomy" "$STATUS_SKILL"; then
  assert_pass "cortex-status/SKILL.md references resolve-autonomy script"
else
  assert_fail "cortex-status/SKILL.md references resolve-autonomy script" "not found"
fi

# ── Section 6: Backward compatibility ────────────────────────────────────────

echo ""
echo "6. Backward compatibility"

DEFAULT_JSON=$(echo '{}' | node "$RESOLVER")
DEFAULT_PRESET=$(echo "$DEFAULT_JSON" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{const r=JSON.parse(d);console.log(r.preset);});")
DEFAULT_GATE_COUNT=$(echo "$DEFAULT_JSON" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{const r=JSON.parse(d);console.log(Object.keys(r.gates).length);});")

if [[ "$DEFAULT_PRESET" == "supervised" ]] && [[ "$DEFAULT_GATE_COUNT" == "13" ]]; then
  assert_pass "empty input {} returns valid JSON with supervised preset and 13 gates"
else
  assert_fail "empty input {} returns valid JSON with supervised preset and 13 gates" "preset=$DEFAULT_PRESET gates=$DEFAULT_GATE_COUNT"
fi

EXIT_CODE=0
bash "$REPO_DIR/test/autonomy-config.test.sh" > /dev/null 2>&1 || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]]; then
  assert_pass "autonomy-config.test.sh still passes (no regression)"
else
  assert_fail "autonomy-config.test.sh still passes (no regression)" "exit code: $EXIT_CODE"
fi

# ── Summary ───────────────────────────────────────────────────────────────────

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
