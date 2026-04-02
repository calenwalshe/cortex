#!/usr/bin/env bash
set -euo pipefail

RESOLVER="scripts/cortex/resolve-autonomy.js"
PASS=0
FAIL=0

assert_gate() {
  local test_name="$1"
  local input="$2"
  local gate_name="$3"
  local expected="$4"

  local result
  result=$(echo "$input" | node "$RESOLVER" 2>/dev/null)
  local actual
  actual=$(echo "$result" | node -e "const d=require('fs').readFileSync('/dev/stdin','utf8');const g=JSON.parse(d).gates;console.log(g['$gate_name'])")

  if [ "$actual" = "$expected" ]; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name (expected $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

echo "Gate Conditional Tests"
echo "════════════════════════════════════════"

echo ""
echo "1. Supervised preset (default) — all gates true"
assert_gate "slug_conflict supervised" '{}' "slug_conflict" "true"
assert_gate "eval_proposal supervised" '{}' "eval_proposal" "true"
assert_gate "critical_uncertainty supervised" '{}' "critical_uncertainty" "true"
assert_gate "evidence_backing supervised" '{}' "evidence_backing" "true"
assert_gate "contract_approval supervised" '{}' "contract_approval" "true"
assert_gate "eval_validation supervised" '{}' "eval_validation" "true"
assert_gate "compliance_verdict supervised" '{}' "compliance_verdict" "true"
assert_gate "security_verdict supervised" '{}' "security_verdict" "true"

echo ""
echo "2. Full-auto preset — non-mandatory gates false"
FA='{"projectConfig":{"preset":"full-auto"}}'
assert_gate "slug_conflict full-auto" "$FA" "slug_conflict" "false"
assert_gate "eval_proposal full-auto" "$FA" "eval_proposal" "false"
assert_gate "critical_uncertainty full-auto" "$FA" "critical_uncertainty" "false"
assert_gate "evidence_backing full-auto" "$FA" "evidence_backing" "false"
assert_gate "contract_approval full-auto" "$FA" "contract_approval" "false"
assert_gate "eval_validation full-auto" "$FA" "eval_validation" "false"
assert_gate "compliance_verdict full-auto" "$FA" "compliance_verdict" "false"
assert_gate "security_verdict full-auto" "$FA" "security_verdict" "false"

echo ""
echo "3. Full-auto preset — mandatory gates still true"
assert_gate "reclarify full-auto mandatory" "$FA" "reclarify" "true"
assert_gate "ux_taste_eval full-auto mandatory" "$FA" "ux_taste_eval" "true"
assert_gate "human_action full-auto mandatory" "$FA" "human_action" "true"

echo ""
echo "4. Gates-only preset — approval gates true, review gates false"
GO='{"projectConfig":{"preset":"gates-only"}}'
assert_gate "contract_approval gates-only" "$GO" "contract_approval" "true"
assert_gate "slug_conflict gates-only" "$GO" "slug_conflict" "false"
assert_gate "eval_proposal gates-only" "$GO" "eval_proposal" "false"
assert_gate "eval_validation gates-only" "$GO" "eval_validation" "false"
assert_gate "compliance_verdict gates-only" "$GO" "compliance_verdict" "false"
assert_gate "security_verdict gates-only" "$GO" "security_verdict" "false"

echo ""
echo "5. Invocation override — per-gate override wins over preset"
INV='{"invocationFlags":{"gates":{"contract_approval":true}},"projectConfig":{"preset":"full-auto"}}'
assert_gate "contract_approval invocation override" "$INV" "contract_approval" "true"
assert_gate "slug_conflict still false" "$INV" "slug_conflict" "false"

echo ""
echo "6. Invocation override — cannot disable mandatory gate"
MAND='{"invocationFlags":{"gates":{"reclarify":false}},"projectConfig":{"preset":"full-auto"}}'
assert_gate "reclarify cannot be disabled" "$MAND" "reclarify" "true"

echo ""
echo "════════════════════════════════════════"
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && echo "ALL TESTS PASSED" || { echo "SOME TESTS FAILED"; exit 1; }
