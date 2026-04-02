#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_FILE="$REPO_DIR/skills/cortex-bridge/SKILL.md"
PASS=0
FAIL=0
TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

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
echo "Bridge Output Test Suite"
echo "$(printf '─%.0s' {1..50})"

# ── Test 1 — SKILL.md references all 6 output artifacts ──────────────────────

echo ""
echo "1. SKILL.md references all 6 required output artifacts"

if grep -q "PROJECT.md" "$SKILL_FILE" && \
   grep -q "ROADMAP.md" "$SKILL_FILE" && \
   grep -q "REQUIREMENTS.md" "$SKILL_FILE" && \
   grep -q "STATE.md" "$SKILL_FILE" && \
   grep -q "config.json" "$SKILL_FILE" && \
   grep -q "CONTEXT.md" "$SKILL_FILE"; then
  assert_pass "SKILL.md references all 6 output artifacts"
else
  assert_fail "SKILL.md references all 6 output artifacts" "one or more artifact references missing"
fi

# ── Test 2 — AUTON-06: SKILL.md has verbatim done_criteria instruction ────────

echo ""
echo "2. SKILL.md instructs verbatim done_criteria mapping (AUTON-06)"

if grep -q "done_criteria" "$SKILL_FILE" && \
   (grep -q "verbatim" "$SKILL_FILE" || grep -q "exact" "$SKILL_FILE"); then
  assert_pass "SKILL.md contains verbatim/exact done_criteria mapping instruction (AUTON-06)"
else
  assert_fail "SKILL.md contains verbatim/exact done_criteria mapping instruction (AUTON-06)" "missing 'done_criteria' or 'verbatim'/'exact' text"
fi

# Verify AUTON-06 is explicitly called out
if grep -q "AUTON-06" "$SKILL_FILE"; then
  assert_pass "SKILL.md explicitly references AUTON-06 compliance requirement"
else
  assert_fail "SKILL.md explicitly references AUTON-06 compliance requirement" "AUTON-06 not mentioned"
fi

# ── Test 3 — SKILL.md references all required input artifact paths ────────────

echo ""
echo "3. SKILL.md references all 3 required input artifact paths"

if grep -q "gsd-handoff.md" "$SKILL_FILE" && \
   grep -q "spec.md" "$SKILL_FILE" && \
   grep -q "contract-001.md" "$SKILL_FILE"; then
  assert_pass "SKILL.md references gsd-handoff.md, spec.md, and contract-001.md as inputs"
else
  assert_fail "SKILL.md references gsd-handoff.md, spec.md, and contract-001.md as inputs" "one or more input paths missing"
fi

# ── Test 4 — SKILL.md has --dry-run handling instructions ────────────────────

echo ""
echo "4. SKILL.md has --dry-run mode instructions"

if grep -q "dry-run" "$SKILL_FILE" && \
   grep -q "No files written" "$SKILL_FILE"; then
  assert_pass "SKILL.md has --dry-run flag with 'No files written' output instruction"
else
  assert_fail "SKILL.md has --dry-run flag with 'No files written' output instruction" "missing dry-run handling or 'No files written' text"
fi

# ── Test 5 — SKILL.md has autonomy flag sync instructions ────────────────────

echo ""
echo "5. SKILL.md has autonomy flag sync instructions (discuss_phase → config.json)"

if grep -q "autonomy" "$SKILL_FILE" && \
   grep -q "discuss_phase" "$SKILL_FILE" && \
   grep -q "skip_discuss_cortex" "$SKILL_FILE"; then
  assert_pass "SKILL.md syncs autonomy discuss_phase gate to config.json skip_discuss_cortex"
else
  assert_fail "SKILL.md syncs autonomy discuss_phase gate to config.json skip_discuss_cortex" "missing autonomy sync instruction"
fi

# ── Test 6 — SKILL.md has slug discovery instructions ────────────────────────

echo ""
echo "6. SKILL.md has slug discovery instructions"

if grep -q "state.json" "$SKILL_FILE" && \
   grep -q "slug" "$SKILL_FILE" && \
   grep -q "\-\-slug" "$SKILL_FILE"; then
  assert_pass "SKILL.md describes slug discovery from .cortex/state.json and --slug flag"
else
  assert_fail "SKILL.md describes slug discovery from .cortex/state.json and --slug flag" "missing slug discovery instructions"
fi

# ── Test 7 — SKILL.md has commit instruction ──────────────────────────────────

echo ""
echo "7. SKILL.md has commit instruction after artifact generation"

if grep -q "commit" "$SKILL_FILE" && \
   grep -q "gsd-tools.cjs" "$SKILL_FILE"; then
  assert_pass "SKILL.md includes commit step using gsd-tools.cjs"
else
  assert_fail "SKILL.md includes commit step using gsd-tools.cjs" "missing commit instruction with gsd-tools.cjs"
fi

# ── Test 8 — SKILL.md instructs .planning/ write root and phase directories ──

echo ""
echo "8. SKILL.md writes to .planning/ and creates phase directories"

if grep -q "\.planning/" "$SKILL_FILE" && \
   grep -q "phases/" "$SKILL_FILE"; then
  assert_pass "SKILL.md writes to .planning/ and creates phase subdirectories"
else
  assert_fail "SKILL.md writes to .planning/ and creates phase subdirectories" "missing .planning/ or phases/ write instruction"
fi

# ── Test 9 — SKILL.md handles missing Cortex artifacts with specific errors ───

echo ""
echo "9. SKILL.md has explicit error handling for missing required artifacts"

if grep -q "Missing" "$SKILL_FILE" && \
   grep -q "No active slug" "$SKILL_FILE"; then
  assert_pass "SKILL.md has explicit error messages for missing artifacts and missing slug"
else
  assert_fail "SKILL.md has explicit error messages for missing artifacts and missing slug" "missing error handling instructions"
fi

# ── Test 10 — SKILL.md has mandatory gate list for autonomy ───────────────────

echo ""
echo "10. SKILL.md references mandatory gates (AUTON-04 alignment)"

if grep -q "ux_taste_eval" "$SKILL_FILE" && \
   grep -q "human_action" "$SKILL_FILE" && \
   grep -q "reclarify" "$SKILL_FILE"; then
  assert_pass "SKILL.md lists mandatory gates (ux_taste_eval, human_action, reclarify)"
else
  assert_fail "SKILL.md lists mandatory gates (ux_taste_eval, human_action, reclarify)" "mandatory gates not listed"
fi

# ── Test 11 — SKILL.md generates STATE.md with gsd_state_version ─────────────

echo ""
echo "11. SKILL.md includes gsd_state_version in generated STATE.md"

if grep -q "gsd_state_version" "$SKILL_FILE" && \
   grep -q "status: planning" "$SKILL_FILE"; then
  assert_pass "SKILL.md STATE.md template has gsd_state_version and status: planning"
else
  assert_fail "SKILL.md STATE.md template has gsd_state_version and status: planning" "missing STATE.md frontmatter"
fi

# ── Test 12 — SKILL.md generates config.json with required workflow flags ─────

echo ""
echo "12. SKILL.md generates config.json with required workflow flags"

if grep -q '"auto_advance"' "$SKILL_FILE" && \
   grep -q '"nyquist_validation"' "$SKILL_FILE" && \
   grep -q '"plan_check"' "$SKILL_FILE"; then
  assert_pass "SKILL.md config.json template includes auto_advance, nyquist_validation, plan_check flags"
else
  assert_fail "SKILL.md config.json template includes auto_advance, nyquist_validation, plan_check flags" "missing workflow flags in config.json template"
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "$(printf '─%.0s' {1..50})"
TOTAL=$((PASS + FAIL))
echo "bridge-output: $PASS passed, $FAIL failed"

if [[ $FAIL -gt 0 ]]; then
  echo "SOME TESTS FAILED"
  exit 1
fi

echo "ALL TESTS PASSED"
exit 0
