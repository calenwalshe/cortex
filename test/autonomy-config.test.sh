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

# Helper: pipe JSON to resolver and capture output
resolve() {
  echo "$1" | node "$RESOLVER"
}

# Helper: extract a specific gate value from resolver JSON output
gate_value() {
  local json="$1"
  local gate="$2"
  echo "$json" | node -e "
    let d=''; process.stdin.setEncoding('utf8');
    process.stdin.on('data',c=>d+=c);
    process.stdin.on('end',()=>{
      const r=JSON.parse(d);
      console.log(r.gates['$gate']);
    });
  "
}

echo ""
echo "Autonomy Config Test Suite"
echo "$(printf '─%.0s' {1..50})"

# ── Test 1 — AUTON-11: Missing config defaults to supervised ──────────────────

echo ""
echo "1. Missing config defaults to supervised preset (AUTON-11)"

OUTPUT=$(resolve '{}')
PRESET=$(echo "$OUTPUT" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>console.log(JSON.parse(d).preset));")
GATE_COUNT=$(echo "$OUTPUT" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>console.log(Object.keys(JSON.parse(d).gates).length));")
ALL_TRUE=$(echo "$OUTPUT" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{const g=JSON.parse(d).gates;const allTrue=Object.values(g).every(v=>v===true);console.log(allTrue);});")

if [[ "$PRESET" == "supervised" ]]; then
  assert_pass "No config → preset is 'supervised'"
else
  assert_fail "No config → preset is 'supervised'" "got: $PRESET"
fi

if [[ "$GATE_COUNT" == "13" ]]; then
  assert_pass "No config → 13 gates present"
else
  assert_fail "No config → 13 gates present" "got: $GATE_COUNT"
fi

if [[ "$ALL_TRUE" == "true" ]]; then
  assert_pass "No config → all 13 gates are true"
else
  assert_fail "No config → all 13 gates are true" "some gates false"
fi

# ── Test 2 — AUTON-03: Per-gate override enables gate in full-auto ───────────

echo ""
echo "2. Per-gate override enables gate in full-auto preset (AUTON-03)"

OUTPUT=$(resolve '{"projectConfig":{"preset":"full-auto","gates":{"contract_approval":true}}}')
VAL=$(gate_value "$OUTPUT" "contract_approval")

if [[ "$VAL" == "true" ]]; then
  assert_pass "Per-gate override: contract_approval:true in full-auto → true"
else
  assert_fail "Per-gate override: contract_approval:true in full-auto → true" "got: $VAL"
fi

# ── Test 3 — AUTON-03: Per-gate override disables gate in supervised ─────────

echo ""
echo "3. Per-gate override disables gate in supervised preset (AUTON-03)"

OUTPUT=$(resolve '{"projectConfig":{"preset":"supervised","gates":{"slug_conflict":false}}}')
VAL=$(gate_value "$OUTPUT" "slug_conflict")

if [[ "$VAL" == "false" ]]; then
  assert_pass "Per-gate override: slug_conflict:false in supervised → false"
else
  assert_fail "Per-gate override: slug_conflict:false in supervised → false" "got: $VAL"
fi

# ── Tests 4/5/6 — AUTON-04: Mandatory gates survive override ─────────────────

echo ""
echo "4-6. Mandatory gates cannot be disabled (AUTON-04)"

for gate in reclarify ux_taste_eval human_action; do
  OUTPUT=$(resolve "{\"projectConfig\":{\"preset\":\"full-auto\",\"gates\":{\"$gate\":false}}}")
  VAL=$(gate_value "$OUTPUT" "$gate")
  if [[ "$VAL" == "true" ]]; then
    assert_pass "Mandatory gate $gate: full-auto + $gate:false → still true"
  else
    assert_fail "Mandatory gate $gate: full-auto + $gate:false → still true" "got: $VAL"
  fi
done

# ── Test 7 — AUTON-07: Invocation overrides project ──────────────────────────

echo ""
echo "7. Invocation flags override project config (AUTON-07)"

OUTPUT=$(resolve '{"invocationFlags":{"gates":{"slug_conflict":true}},"projectConfig":{"preset":"supervised","gates":{"slug_conflict":false}}}')
VAL=$(gate_value "$OUTPUT" "slug_conflict")

if [[ "$VAL" == "true" ]]; then
  assert_pass "Invocation overrides project: invocation slug_conflict:true wins over project false"
else
  assert_fail "Invocation overrides project: invocation slug_conflict:true wins over project false" "got: $VAL"
fi

# ── Test 8 — AUTON-07: Project overrides global ───────────────────────────────

echo ""
echo "8. Project config overrides global config (AUTON-07)"

OUTPUT=$(resolve '{"projectConfig":{"gates":{"contract_approval":false}},"globalConfig":{"gates":{"contract_approval":true}}}')
VAL=$(gate_value "$OUTPUT" "contract_approval")

if [[ "$VAL" == "false" ]]; then
  assert_pass "Project overrides global: project contract_approval:false wins over global true"
else
  assert_fail "Project overrides global: project contract_approval:false wins over global true" "got: $VAL"
fi

# ── Test 9 — AUTON-07: Global overrides preset ────────────────────────────────

echo ""
echo "9. Global config overrides preset defaults (AUTON-07)"

OUTPUT=$(resolve '{"globalConfig":{"gates":{"slug_conflict":true}},"projectConfig":{"preset":"full-auto"}}')
VAL=$(gate_value "$OUTPUT" "slug_conflict")

if [[ "$VAL" == "true" ]]; then
  assert_pass "Global overrides preset: global slug_conflict:true overrides full-auto default false"
else
  assert_fail "Global overrides preset: global slug_conflict:true overrides full-auto default false" "got: $VAL"
fi

# ── Test 10 — AUTON-07: Full 4-layer stack ───────────────────────────────────

echo ""
echo "10. Full 4-layer resolution stack (AUTON-07)"

OUTPUT=$(resolve '{"invocationFlags":{"gates":{"eval_proposal":true}},"projectConfig":{"preset":"full-auto","gates":{"slug_conflict":true}},"globalConfig":{"gates":{"evidence_backing":true}}}')
EVAL_PROP=$(gate_value "$OUTPUT" "eval_proposal")
SLUG_CONF=$(gate_value "$OUTPUT" "slug_conflict")
EVID_BACK=$(gate_value "$OUTPUT" "evidence_backing")
CONTRACT=$(gate_value "$OUTPUT" "contract_approval")

if [[ "$EVAL_PROP" == "true" ]]; then
  assert_pass "4-layer: eval_proposal from invocation → true"
else
  assert_fail "4-layer: eval_proposal from invocation → true" "got: $EVAL_PROP"
fi

if [[ "$SLUG_CONF" == "true" ]]; then
  assert_pass "4-layer: slug_conflict from project → true"
else
  assert_fail "4-layer: slug_conflict from project → true" "got: $SLUG_CONF"
fi

if [[ "$EVID_BACK" == "true" ]]; then
  assert_pass "4-layer: evidence_backing from global → true"
else
  assert_fail "4-layer: evidence_backing from global → true" "got: $EVID_BACK"
fi

if [[ "$CONTRACT" == "false" ]]; then
  assert_pass "4-layer: contract_approval from full-auto preset → false (no override)"
else
  assert_fail "4-layer: contract_approval from full-auto preset → false (no override)" "got: $CONTRACT"
fi

# ── Test 11 — gates-only preset defaults ─────────────────────────────────────

echo ""
echo "11. gates-only preset has correct defaults"

OUTPUT=$(resolve '{"projectConfig":{"preset":"gates-only"}}')
CONTRACT=$(gate_value "$OUTPUT" "contract_approval")
SPEC=$(gate_value "$OUTPUT" "spec_approval")
EVAL=$(gate_value "$OUTPUT" "eval_approval")
SLUG=$(gate_value "$OUTPUT" "slug_conflict")
EVAL_PROP=$(gate_value "$OUTPUT" "eval_proposal")

if [[ "$CONTRACT" == "true" ]] && [[ "$SPEC" == "true" ]] && [[ "$EVAL" == "true" ]]; then
  assert_pass "gates-only: approval gates (contract_approval, spec_approval, eval_approval) are true"
else
  assert_fail "gates-only: approval gates are true" "contract=$CONTRACT spec=$SPEC eval=$EVAL"
fi

if [[ "$SLUG" == "false" ]] && [[ "$EVAL_PROP" == "false" ]]; then
  assert_pass "gates-only: review gates (slug_conflict, eval_proposal) are false"
else
  assert_fail "gates-only: review gates are false" "slug_conflict=$SLUG eval_proposal=$EVAL_PROP"
fi

# ── Test 12 — Unknown preset throws error ─────────────────────────────────────

echo ""
echo "12. Unknown preset throws error"

EXIT_CODE=0
OUTPUT=$(resolve '{"projectConfig":{"preset":"yolo"}}' 2>&1) || EXIT_CODE=$?

if [[ $EXIT_CODE -ne 0 ]]; then
  assert_pass "Unknown preset 'yolo' → non-zero exit code"
else
  assert_fail "Unknown preset 'yolo' → non-zero exit code" "exit=0 output=$OUTPUT"
fi

# ── Summary ──────────────────────────────────────────────────────────────────

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
