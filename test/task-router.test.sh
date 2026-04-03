#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ROUTER="$REPO_ROOT/scripts/cortex/task-router.js"
PASS=0
FAIL=0
TOTAL=0

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

pass() { PASS=$((PASS+1)); TOTAL=$((TOTAL+1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL+1)); TOTAL=$((TOTAL+1)); echo "  FAIL: $1"; }

assert_classification() {
  local fixture="$1" task_id="$2" expected_class="$3" expected_rule="$4" label="$5"
  local result
  result=$(node "$ROUTER" "$fixture" 2>/dev/null) || { fail "$label (script error)"; return; }
  local actual
  actual=$(echo "$result" | node -e "
    const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
    const t=d.find(x=>x.task_id==='$task_id');
    if(!t){process.exit(1);}
    console.log(t.classification+':'+t.matched_rule);
  " 2>/dev/null) || { fail "$label (parse error)"; return; }
  local actual_class="${actual%%:*}"
  local actual_rule="${actual##*:}"
  if [[ "$actual_class" == "$expected_class" && "$actual_rule" == "$expected_rule" ]]; then
    pass "$label"
  else
    fail "$label (got $actual_class rule $actual_rule, expected $expected_class rule $expected_rule)"
  fi
}

# ── Rule 1: autonomous: false → all claude-required ──────────────────────────
echo "Rule 1: autonomous false"
cat > "$tmp_dir/rule1.md" << 'FIXTURE'
---
autonomous: false
---
<task id="1" type="auto">
  <name>Simple task</name>
  <action>Write a file</action>
  <files>foo.js</files>
  <verify>node foo.js</verify>
  <done>File exists</done>
</task>
FIXTURE
assert_classification "$tmp_dir/rule1.md" "1" "claude-required" "1" "autonomous false → claude-required"

# ── Rule 2: checkpoint type → claude-required ────────────────────────────────
echo "Rule 2: checkpoint type"
cat > "$tmp_dir/rule2.md" << 'FIXTURE'
---
autonomous: true
---
<task id="1" type="checkpoint:human-verify">
  <name>Verify deployment</name>
  <action>Check the site</action>
  <files>site.js</files>
  <verify>curl localhost</verify>
  <done>Site works</done>
</task>
FIXTURE
assert_classification "$tmp_dir/rule2.md" "1" "claude-required" "2" "checkpoint type → claude-required"

# ── Rule 3: auth patterns → claude-required ──────────────────────────────────
echo "Rule 3: auth patterns"
for pattern in "login to the server" "deploy the app" "set the API key"; do
  cat > "$tmp_dir/rule3.md" << FIXTURE
---
autonomous: true
---
<task id="1" type="auto">
  <name>Auth task</name>
  <action>$pattern</action>
  <files>foo.js</files>
  <verify>node foo.js</verify>
  <done>Done</done>
</task>
FIXTURE
  assert_classification "$tmp_dir/rule3.md" "1" "claude-required" "3" "auth pattern '$pattern' → claude-required"
done

# ── Rule 4: >8 files → claude-required ───────────────────────────────────────
echo "Rule 4: file count >8"
cat > "$tmp_dir/rule4.md" << 'FIXTURE'
---
autonomous: true
---
<task id="1" type="auto">
  <name>Big task</name>
  <action>Update many files</action>
  <files>a.js, b.js, c.js, d.js, e.js, f.js, g.js, h.js, i.js</files>
  <verify>node test.js</verify>
  <done>Done</done>
</task>
FIXTURE
assert_classification "$tmp_dir/rule4.md" "1" "claude-required" "4" ">8 files → claude-required"

# ── Rule 5: subjective acceptance → claude-required ──────────────────────────
echo "Rule 5: subjective acceptance"
for subj in "looks right" "user-friendly"; do
  cat > "$tmp_dir/rule5.md" << FIXTURE
---
autonomous: true
---
<task id="1" type="auto">
  <name>UI task</name>
  <action>Create a component</action>
  <files>ui.js</files>
  <verify>node test.js</verify>
  <done>Output $subj</done>
</task>
FIXTURE
  assert_classification "$tmp_dir/rule5.md" "1" "claude-required" "5" "subjective '$subj' → claude-required"
done

# ── Rule 6: architectural patterns → claude-required ─────────────────────────
echo "Rule 6: architectural patterns"
for arch in "create a new table" "schema change needed" "breaking change here"; do
  cat > "$tmp_dir/rule6.md" << FIXTURE
---
autonomous: true
---
<task id="1" type="auto">
  <name>Arch task</name>
  <action>$arch</action>
  <files>db.js</files>
  <verify>node test.js</verify>
  <done>Done</done>
</task>
FIXTURE
  assert_classification "$tmp_dir/rule6.md" "1" "claude-required" "6" "arch pattern '$arch' → claude-required"
done

# ── Rule 7: auto + tdd → codex-safe ─────────────────────────────────────────
echo "Rule 7: auto + tdd"
cat > "$tmp_dir/rule7.md" << 'FIXTURE'
---
autonomous: true
---
<task id="1" type="auto" tdd="true">
  <name>TDD task</name>
  <action>Write tests then code</action>
  <files>src.js, test.js</files>
  <verify>node test.js</verify>
  <done>Tests pass</done>
</task>
FIXTURE
assert_classification "$tmp_dir/rule7.md" "1" "codex-safe" "7" "auto + tdd → codex-safe"

# ── Rule 8: auto + automated verify → codex-safe ────────────────────────────
echo "Rule 8: auto + automated verify"
cat > "$tmp_dir/rule8.md" << 'FIXTURE'
---
autonomous: true
---
<task id="1" type="auto">
  <name>Auto task</name>
  <action>Write a script</action>
  <files>script.js</files>
  <verify>node script.js --test</verify>
  <done>Script runs correctly</done>
</task>
FIXTURE
assert_classification "$tmp_dir/rule8.md" "1" "codex-safe" "8" "auto + verify → codex-safe"

# ── Rule 9: auto but no verify → claude-required ────────────────────────────
echo "Rule 9: auto, no usable verify"
cat > "$tmp_dir/rule9.md" << 'FIXTURE'
---
autonomous: true
---
<task id="1" type="auto">
  <name>No verify task</name>
  <action>Write documentation</action>
  <files>docs.md</files>
  <done>Docs written</done>
</task>
FIXTURE
assert_classification "$tmp_dir/rule9.md" "1" "claude-required" "9" "auto, no verify → claude-required"

# ── Rule 9 variant: verify says MISSING ──────────────────────────────────────
echo "Rule 9: verify=MISSING"
cat > "$tmp_dir/rule9b.md" << 'FIXTURE'
---
autonomous: true
---
<task id="1" type="auto">
  <name>Missing verify task</name>
  <action>Write documentation</action>
  <files>docs.md</files>
  <verify>MISSING</verify>
  <done>Docs written</done>
</task>
FIXTURE
assert_classification "$tmp_dir/rule9b.md" "1" "claude-required" "9" "verify=MISSING → claude-required"

# ── Rule 10: unknown type → claude-required (fallback) ───────────────────────
echo "Rule 10: unknown type"
cat > "$tmp_dir/rule10.md" << 'FIXTURE'
---
autonomous: true
---
<task id="1" type="weird">
  <name>Unknown task</name>
  <action>Do something</action>
  <files>foo.js</files>
  <verify>node test.js</verify>
  <done>Done</done>
</task>
FIXTURE
assert_classification "$tmp_dir/rule10.md" "1" "claude-required" "10" "unknown type → claude-required"

# ── Valid JSON output ────────────────────────────────────────────────────────
echo "Output format"
result=$(node "$ROUTER" "$tmp_dir/rule8.md" 2>/dev/null) || { fail "JSON output (script error)"; }
echo "$result" | node -e "
  const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
  if(!Array.isArray(d)) process.exit(1);
  const t=d[0];
  if(!t.task_id||!t.task_name||!t.classification||!t.matched_rule||!t.rule_description) process.exit(1);
" 2>/dev/null && pass "output has all required fields" || fail "output missing fields"

# ── Exit code: missing file → non-zero ───────────────────────────────────────
echo "Error handling"
{ node "$ROUTER" 2>/dev/null; ec=$?; } || ec=$?
[[ "$ec" -ne 0 ]] && pass "no args → exit 1" || fail "no args should exit 1"

{ node "$ROUTER" "$tmp_dir/nonexistent.md" 2>/dev/null; ec=$?; } || ec=$?
[[ "$ec" -ne 0 ]] && pass "missing file → exit non-zero" || fail "missing file should exit non-zero"

# ── Empty plan (no tasks) → empty array ──────────────────────────────────────
echo "Edge cases"
cat > "$tmp_dir/empty.md" << 'FIXTURE'
---
autonomous: true
---
No tasks here.
FIXTURE
result=$(node "$ROUTER" "$tmp_dir/empty.md" 2>/dev/null) || { fail "empty plan (script error)"; }
echo "$result" | node -e "
  const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
  process.exit(d.length===0?0:1);
" 2>/dev/null && pass "empty plan → empty array" || fail "empty plan should produce []"

# ── Multiple tasks classified independently ──────────────────────────────────
echo "Multiple tasks"
cat > "$tmp_dir/multi.md" << 'FIXTURE'
---
autonomous: true
---
<task id="1" type="auto" tdd="true">
  <name>TDD task</name>
  <action>Write tests</action>
  <files>test.js</files>
  <verify>node test.js</verify>
  <done>Tests pass</done>
</task>
<task id="2" type="checkpoint:decision">
  <name>Pick approach</name>
  <action>Choose A or B</action>
  <files>config.json</files>
  <done>Decision made</done>
</task>
<task id="3" type="auto">
  <name>Simple script</name>
  <action>Write utility</action>
  <files>util.js</files>
  <verify>node util.js</verify>
  <done>Utility works</done>
</task>
FIXTURE
assert_classification "$tmp_dir/multi.md" "1" "codex-safe" "7" "multi: task 1 tdd → codex-safe"
assert_classification "$tmp_dir/multi.md" "2" "claude-required" "2" "multi: task 2 checkpoint → claude-required"
assert_classification "$tmp_dir/multi.md" "3" "codex-safe" "8" "multi: task 3 auto+verify → codex-safe"

# ── Stderr traceability ─────────────────────────────────────────────────────
echo "Stderr traceability"
stderr=$(node "$ROUTER" "$tmp_dir/multi.md" 2>&1 1>/dev/null) || true
echo "$stderr" | grep -q '\[task-router\]' && pass "stderr has traceability lines" || fail "stderr should have [task-router] lines"

# ── Real PLAN.md integration: 20-01 (all codex-safe) ─────────────────────────
echo "Real plan integration"
REAL_PLAN="/home/agent/projects/cortex/.planning/phases/20-token-report-cli/20-01-PLAN.md"
if [[ -f "$REAL_PLAN" ]]; then
  result=$(node "$ROUTER" "$REAL_PLAN" 2>/dev/null) || { fail "real plan 20-01 (script error)"; }
  echo "$result" | node -e "
    const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
    if(d.length!==3){process.stderr.write('expected 3 tasks, got '+d.length+'\n');process.exit(1);}
    if(!d.every(t=>t.classification==='codex-safe')){process.stderr.write('not all codex-safe\n');process.exit(1);}
    process.exit(0);
  " 2>/dev/null && pass "real 20-01: 3 tasks all codex-safe" || fail "real 20-01: expected 3 codex-safe tasks"

  # Validate JSON parseable by downstream
  echo "$result" | node -e "JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'))" 2>/dev/null \
    && pass "real 20-01: output is parseable JSON" || fail "real 20-01: JSON parse failed"
else
  echo "  SKIP: 20-01-PLAN.md not found at $REAL_PLAN"
fi

# ── Real PLAN.md integration: 08-01 (older format, fallback) ─────────────────
REAL_PLAN_08="$REPO_ROOT/.planning/phases/08-discovery-loop-design-docs-and-templates/08-01-PLAN.md"
if [[ -f "$REAL_PLAN_08" ]]; then
  result=$(node "$ROUTER" "$REAL_PLAN_08" 2>/dev/null) || { fail "real plan 08-01 (script error)"; }
  echo "$result" | node -e "
    const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
    if(d.length<1){process.exit(1);}
    // Older format uses different XML tags — tasks should classify as claude-required (fallback)
    if(!d.every(t=>t.classification==='claude-required')){process.exit(1);}
    process.exit(0);
  " 2>/dev/null && pass "real 08-01: older format tasks → claude-required" || fail "real 08-01: expected claude-required"
else
  echo "  SKIP: 08-01-PLAN.md not found at $REAL_PLAN_08"
fi

# ── Script conventions ──────────────────────────────────────────────────────
echo "Script conventions"
head -1 "$ROUTER" | grep -q "#!/usr/bin/env node" && pass "correct shebang" || fail "wrong shebang"
grep -q "'use strict'" "$ROUTER" && pass "strict mode" || fail "missing strict mode"
test -x "$ROUTER" && pass "script is executable" || fail "script not executable"

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed out of $TOTAL tests"
if [[ "$FAIL" -gt 0 ]]; then
  echo "FAIL"
  exit 1
else
  echo "ALL PASS"
fi
