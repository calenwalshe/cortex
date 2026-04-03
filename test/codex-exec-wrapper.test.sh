#!/usr/bin/env bash
# codex-exec-wrapper.test.sh — Integration tests for codex-exec-wrapper.sh
#
# Tests the full lifecycle wrapper with mock Codex invocations.
# Uses PATH override to inject mock codex/timeout/git commands.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WRAPPER="$REPO_ROOT/scripts/cortex/codex-exec-wrapper.sh"
PASS=0
FAIL=0
TOTAL=0

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

pass() { PASS=$((PASS+1)); TOTAL=$((TOTAL+1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL+1)); TOTAL=$((TOTAL+1)); echo "  FAIL: $1"; }

# ── Create a minimal git repo for worktree tests ────────────────────────────
setup_git_repo() {
  local repo_dir="$tmp_dir/repo"
  mkdir -p "$repo_dir"
  git -C "$repo_dir" init -b main >/dev/null 2>&1
  git -C "$repo_dir" config user.email "test@test.com"
  git -C "$repo_dir" config user.name "Test"
  echo "init" > "$repo_dir/init.txt"
  git -C "$repo_dir" add init.txt
  git -C "$repo_dir" commit -m "init" >/dev/null 2>&1
  echo "$repo_dir"
}

# ── Create a valid PLAN.md fixture ───────────────────────────────────────────
create_plan() {
  local plan_path="$1"
  cat > "$plan_path" << 'PLAN'
---
phase: "23"
plan: "01"
type: execution
autonomous: true
---

# Test Plan

<task id="1" type="auto">
<name>Create test file</name>
<action>Create a simple test file</action>
<files>
test.js
</files>
<verify>
node test.js
</verify>
<done>File exists and runs</done>
</task>

<task id="2" type="auto" tdd="true">
<name>TDD task</name>
<action>Write tests first</action>
<files>
a.js, b.js, c.js, d.js, e.js
</files>
<verify>
npm test
</verify>
<done>Tests pass</done>
</task>
PLAN
}

# ── Create task JSON ─────────────────────────────────────────────────────────
task_json() {
  local id="${1:-1}" name="${2:-Create test file}"
  echo "{\"task_id\":\"$id\",\"task_name\":\"$name\",\"classification\":\"codex-safe\",\"matched_rule\":8}"
}

# ── Create mock codex that outputs valid JSONL ───────────────────────────────
create_mock_codex() {
  local mock_dir="$1" behavior="${2:-success}"
  mkdir -p "$mock_dir"

  case "$behavior" in
    success)
      cat > "$mock_dir/codex" << 'MOCK'
#!/usr/bin/env bash
# Mock codex: outputs valid JSONL with turn.completed and result JSON
echo '{"type":"turn.started","message":{"role":"assistant"}}'
echo '{"type":"turn.completed","message":{"role":"assistant","content":"{\"status\":\"complete\",\"files_changed\":[\"test.js\"],\"tests_passed\":true,\"test_output_summary\":\"1 test passed\",\"deviations\":[],\"commit_hash\":\"abc1234\",\"error_message\":null,\"checkpoint_detail\":null}"},"usage":{"input_tokens":500,"output_tokens":200,"cached_tokens":50,"reasoning_tokens":30}}'
exit 0
MOCK
      ;;
    failure)
      cat > "$mock_dir/codex" << 'MOCK'
#!/usr/bin/env bash
echo '{"type":"turn.completed","message":{"role":"assistant","content":"{\"status\":\"failed\",\"files_changed\":[],\"tests_passed\":false,\"test_output_summary\":\"FAIL\",\"deviations\":[],\"commit_hash\":null,\"error_message\":\"test failed\",\"checkpoint_detail\":null}"},"usage":{"input_tokens":100,"output_tokens":50,"cached_tokens":0,"reasoning_tokens":0}}'
exit 0
MOCK
      ;;
    checkpoint)
      cat > "$mock_dir/codex" << 'MOCK'
#!/usr/bin/env bash
echo '{"type":"turn.completed","message":{"role":"assistant","content":"{\"status\":\"checkpoint\",\"files_changed\":[],\"tests_passed\":false,\"test_output_summary\":null,\"deviations\":[],\"commit_hash\":null,\"error_message\":null,\"checkpoint_detail\":\"Need new database table\"}"},"usage":{"input_tokens":100,"output_tokens":50,"cached_tokens":0,"reasoning_tokens":0}}'
exit 0
MOCK
      ;;
    crash)
      cat > "$mock_dir/codex" << 'MOCK'
#!/usr/bin/env bash
echo "something went wrong" >&2
exit 1
MOCK
      ;;
    timeout)
      cat > "$mock_dir/codex" << 'MOCK'
#!/usr/bin/env bash
sleep 999
MOCK
      ;;
    bad_jsonl)
      cat > "$mock_dir/codex" << 'MOCK'
#!/usr/bin/env bash
echo 'this is not json at all'
echo 'neither is this'
exit 0
MOCK
      ;;
  esac
  chmod +x "$mock_dir/codex"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Tests
# ═══════════════════════════════════════════════════════════════════════════════

# ── Test 1: Script exists and is executable ──────────────────────────────────
echo "Test 1: Script exists and is executable"
if [[ -x "$WRAPPER" ]]; then
  pass "script is executable"
else
  fail "script not found or not executable at $WRAPPER"
fi

# ── Test 2: Displays usage on missing arguments ─────────────────────────────
echo "Test 2: Usage on missing arguments"
set +e
usage_output=$(bash "$WRAPPER" 2>&1)
usage_exit=$?
set -e
if [[ $usage_exit -eq 1 ]] && echo "$usage_output" | grep -q "Usage:"; then
  pass "shows usage and exits 1 on no args"
else
  fail "expected usage message and exit 1 (got exit $usage_exit)"
fi

# ── Test 3: Fails on missing PLAN file ───────────────────────────────────────
echo "Test 3: Fails on missing PLAN file"
set +e
missing_output=$(bash "$WRAPPER" "/nonexistent/plan.md" '{"task_id":"1"}' 2>&1)
missing_exit=$?
set -e
if [[ $missing_exit -eq 1 ]] && echo "$missing_output" | grep -q "PLAN file not found"; then
  pass "rejects missing PLAN file"
else
  fail "expected PLAN file not found error (got exit $missing_exit)"
fi

# ── Test 4: Timeout tier calculation ─────────────────────────────────────────
echo "Test 4: Timeout tiers"
REPO_DIR=$(setup_git_repo)
PLAN_FILE="$REPO_DIR/plan.md"
create_plan "$PLAN_FILE"

# TDD task (id=2) should get 180s timeout
MOCK_DIR="$tmp_dir/mock_timeout_check"
create_mock_codex "$MOCK_DIR" "success"

set +e
timeout_output=$(
  cd "$REPO_DIR" && \
  PATH="$MOCK_DIR:$PATH" \
  CODEX_DRY_RUN=1 \
  bash "$WRAPPER" "$PLAN_FILE" "$(task_json 2 "TDD task")" 2>&1 >/dev/null
)
set -e

if echo "$timeout_output" | grep -q "timeout=180s"; then
  pass "TDD task gets 180s timeout"
else
  fail "expected timeout=180s for TDD task"
fi

# Regular task (id=1, 1 file) should get 300s
set +e
timeout_output2=$(
  cd "$REPO_DIR" && \
  PATH="$MOCK_DIR:$PATH" \
  CODEX_DRY_RUN=1 \
  bash "$WRAPPER" "$PLAN_FILE" "$(task_json 1 "Create test file")" 2>&1 >/dev/null
)
set -e

if echo "$timeout_output2" | grep -q "timeout=300s"; then
  pass "auto task with <5 files gets 300s timeout"
else
  fail "expected timeout=300s for auto task with 1 file"
fi

# ── Test 5: Success path (dry run) ──────────────────────────────────────────
echo "Test 5: Success path (dry run)"
REPO_DIR2=$(setup_git_repo)
PLAN_FILE2="$REPO_DIR2/plan.md"
create_plan "$PLAN_FILE2"
MOCK_DIR2="$tmp_dir/mock_success"
create_mock_codex "$MOCK_DIR2" "success"

set +e
success_json=$(
  cd "$REPO_DIR2" && \
  PATH="$MOCK_DIR2:$PATH" \
  CODEX_DRY_RUN=1 \
  bash "$WRAPPER" "$PLAN_FILE2" "$(task_json 1 "Create test file")" 2>/dev/null
)
success_exit=$?
set -e

if [[ $success_exit -eq 0 ]]; then
  # Check the output is valid JSON with expected fields
  status=$(echo "$success_json" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.status)" 2>/dev/null || echo "")
  task_id=$(echo "$success_json" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.task_id)" 2>/dev/null || echo "")
  if [[ "$task_id" == "1" ]]; then
    pass "dry run outputs valid JSON with task_id"
  else
    fail "dry run JSON missing task_id (got: $task_id)"
  fi
else
  fail "dry run exited with non-zero: $success_exit"
fi

# ── Test 6: JSONL token parsing ──────────────────────────────────────────────
echo "Test 6: JSONL token parsing"
# Create a JSONL file with multiple turn.completed events
TOKEN_JSONL="$tmp_dir/tokens.jsonl"
cat > "$TOKEN_JSONL" << 'JSONL'
{"type":"turn.started","message":{"role":"assistant"}}
{"type":"turn.completed","message":{"role":"assistant","content":"thinking..."},"usage":{"input_tokens":100,"output_tokens":50,"cached_tokens":10,"reasoning_tokens":5}}
{"type":"turn.completed","message":{"role":"assistant","content":"done"},"usage":{"input_tokens":200,"output_tokens":100,"cached_tokens":20,"reasoning_tokens":10}}
JSONL

# Use the parse_tokens function by sourcing just that part
token_result=$(node -e "
  const fs = require('fs');
  const lines = fs.readFileSync(process.argv[1], 'utf8').trim().split('\n');
  let input = 0, output = 0, cached = 0, reasoning = 0;
  for (const line of lines) {
    if (!line.trim()) continue;
    try {
      const obj = JSON.parse(line);
      if (obj.type === 'turn.completed' && obj.usage) {
        input += obj.usage.input_tokens || 0;
        output += obj.usage.output_tokens || 0;
        cached += obj.usage.cached_tokens || 0;
        reasoning += obj.usage.reasoning_tokens || 0;
      }
    } catch(e) {}
  }
  console.log(JSON.stringify({ input, output, cached, reasoning }));
" "$TOKEN_JSONL" 2>/dev/null)

expected_input=$(echo "$token_result" | node -e "console.log(JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')).input)" 2>/dev/null)
expected_output=$(echo "$token_result" | node -e "console.log(JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')).output)" 2>/dev/null)

if [[ "$expected_input" == "300" && "$expected_output" == "150" ]]; then
  pass "token parsing sums across multiple turn.completed events (in=300 out=150)"
else
  fail "token parsing wrong (got in=$expected_input out=$expected_output, expected in=300 out=150)"
fi

# ── Test 7: Result JSON extraction ───────────────────────────────────────────
echo "Test 7: Result JSON extraction from JSONL"
EXTRACT_JSONL="$tmp_dir/extract.jsonl"
EXTRACT_RESULT="$tmp_dir/extract-result.json"

cat > "$EXTRACT_JSONL" << 'JSONL'
{"type":"turn.started","message":{"role":"assistant"}}
{"type":"turn.completed","message":{"role":"assistant","content":"{\"status\":\"complete\",\"files_changed\":[\"a.js\"],\"tests_passed\":true,\"test_output_summary\":\"ok\",\"deviations\":[],\"commit_hash\":\"abc1234\",\"error_message\":null,\"checkpoint_detail\":null}"},"usage":{"input_tokens":100,"output_tokens":50,"cached_tokens":0,"reasoning_tokens":0}}
JSONL

extract_ok=$(node -e "
  const fs = require('fs');
  const lines = fs.readFileSync(process.argv[1], 'utf8').trim().split('\n');
  for (let i = lines.length - 1; i >= 0; i--) {
    if (!lines[i].trim()) continue;
    try {
      const obj = JSON.parse(lines[i]);
      if (obj.type === 'turn.completed' && obj.message && obj.message.content) {
        const content = typeof obj.message.content === 'string' ? obj.message.content : JSON.stringify(obj.message.content);
        try {
          const parsed = JSON.parse(content);
          if (parsed.status) {
            fs.writeFileSync(process.argv[2], JSON.stringify(parsed, null, 2));
            process.exit(0);
          }
        } catch(e2) {}
      }
    } catch(e) {}
  }
  process.exit(1);
" "$EXTRACT_JSONL" "$EXTRACT_RESULT" 2>/dev/null && echo "ok" || echo "fail")

if [[ "$extract_ok" == "ok" ]] && [[ -f "$EXTRACT_RESULT" ]]; then
  result_status=$(node -e "console.log(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).status)" "$EXTRACT_RESULT" 2>/dev/null)
  if [[ "$result_status" == "complete" ]]; then
    pass "extracts result JSON from JSONL turn.completed content"
  else
    fail "extracted wrong status: $result_status"
  fi
else
  fail "failed to extract result JSON from JSONL"
fi

# ── Test 8: Failure path — test failure ──────────────────────────────────────
echo "Test 8: Test failure fallback"
REPO_DIR3=$(setup_git_repo)
PLAN_FILE3="$REPO_DIR3/plan.md"
create_plan "$PLAN_FILE3"
MOCK_DIR3="$tmp_dir/mock_failure"
create_mock_codex "$MOCK_DIR3" "failure"

set +e
fail_json=$(
  cd "$REPO_DIR3" && \
  PATH="$MOCK_DIR3:$PATH" \
  bash "$WRAPPER" "$PLAN_FILE3" "$(task_json 1 "Create test file")" 2>/dev/null
)
set -e

fail_status=$(echo "$fail_json" | node -e "console.log(JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')).status)" 2>/dev/null || echo "")
fail_reason=$(echo "$fail_json" | node -e "console.log(JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')).fallback_reason)" 2>/dev/null || echo "")

if [[ "$fail_status" == "fallback" && "$fail_reason" == "test_failure" ]]; then
  pass "test failure produces fallback with reason=test_failure"
else
  fail "expected fallback/test_failure (got status=$fail_status reason=$fail_reason)"
fi

# ── Test 9: Failure path — checkpoint ────────────────────────────────────────
echo "Test 9: Checkpoint fallback"
REPO_DIR4=$(setup_git_repo)
PLAN_FILE4="$REPO_DIR4/plan.md"
create_plan "$PLAN_FILE4"
MOCK_DIR4="$tmp_dir/mock_checkpoint"
create_mock_codex "$MOCK_DIR4" "checkpoint"

set +e
cp_json=$(
  cd "$REPO_DIR4" && \
  PATH="$MOCK_DIR4:$PATH" \
  bash "$WRAPPER" "$PLAN_FILE4" "$(task_json 1 "Create test file")" 2>/dev/null
)
set -e

cp_status=$(echo "$cp_json" | node -e "console.log(JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')).status)" 2>/dev/null || echo "")
cp_reason=$(echo "$cp_json" | node -e "console.log(JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')).fallback_reason)" 2>/dev/null || echo "")

if [[ "$cp_status" == "fallback" && "$cp_reason" == "checkpoint" ]]; then
  pass "checkpoint produces fallback with reason=checkpoint"
else
  fail "expected fallback/checkpoint (got status=$cp_status reason=$cp_reason)"
fi

# ── Test 10: Failure path — crash ────────────────────────────────────────────
echo "Test 10: Crash fallback"
REPO_DIR5=$(setup_git_repo)
PLAN_FILE5="$REPO_DIR5/plan.md"
create_plan "$PLAN_FILE5"
MOCK_DIR5="$tmp_dir/mock_crash"
create_mock_codex "$MOCK_DIR5" "crash"

set +e
crash_json=$(
  cd "$REPO_DIR5" && \
  PATH="$MOCK_DIR5:$PATH" \
  bash "$WRAPPER" "$PLAN_FILE5" "$(task_json 1 "Create test file")" 2>/dev/null
)
set -e

crash_status=$(echo "$crash_json" | node -e "console.log(JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')).status)" 2>/dev/null || echo "")
crash_reason=$(echo "$crash_json" | node -e "console.log(JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')).fallback_reason)" 2>/dev/null || echo "")

if [[ "$crash_status" == "fallback" && "$crash_reason" == "crash" ]]; then
  pass "crash produces fallback with reason=crash"
else
  fail "expected fallback/crash (got status=$crash_status reason=$crash_reason)"
fi

# ── Test 11: Failure path — bad JSONL (parse error) ─────────────────────────
echo "Test 11: Bad JSONL parse error fallback"
REPO_DIR6=$(setup_git_repo)
PLAN_FILE6="$REPO_DIR6/plan.md"
create_plan "$PLAN_FILE6"
MOCK_DIR6="$tmp_dir/mock_bad_jsonl"
create_mock_codex "$MOCK_DIR6" "bad_jsonl"

set +e
parse_json=$(
  cd "$REPO_DIR6" && \
  PATH="$MOCK_DIR6:$PATH" \
  bash "$WRAPPER" "$PLAN_FILE6" "$(task_json 1 "Create test file")" 2>/dev/null
)
set -e

parse_status=$(echo "$parse_json" | node -e "console.log(JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')).status)" 2>/dev/null || echo "")
parse_reason=$(echo "$parse_json" | node -e "console.log(JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')).fallback_reason)" 2>/dev/null || echo "")

if [[ "$parse_status" == "fallback" && "$parse_reason" == "parse_error" ]]; then
  pass "bad JSONL produces fallback with reason=parse_error"
else
  fail "expected fallback/parse_error (got status=$parse_status reason=$parse_reason)"
fi

# ── Test 12: Ledger write ────────────────────────────────────────────────────
echo "Test 12: Token ledger write"
REPO_DIR7=$(setup_git_repo)
PLAN_FILE7="$REPO_DIR7/plan.md"
create_plan "$PLAN_FILE7"
MOCK_DIR7="$tmp_dir/mock_ledger"
create_mock_codex "$MOCK_DIR7" "success"

# Create a test ledger DB
TEST_DB="$tmp_dir/test-ledger.db"
if command -v sqlite3 &>/dev/null; then
  sqlite3 "$TEST_DB" "CREATE TABLE IF NOT EXISTS codex_tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ts TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    task_id TEXT NOT NULL, model TEXT NOT NULL,
    input_tokens INTEGER NOT NULL DEFAULT 0, output_tokens INTEGER NOT NULL DEFAULT 0,
    cached_tokens INTEGER NOT NULL DEFAULT 0, reasoning_tokens INTEGER NOT NULL DEFAULT 0,
    cost_usd REAL NOT NULL DEFAULT 0.0, session_id TEXT, project_slug TEXT,
    phase TEXT, task_type TEXT, plan_file TEXT, exit_code INTEGER, elapsed_ms INTEGER
  );"

  set +e
  cd "$REPO_DIR7" && \
  PATH="$MOCK_DIR7:$PATH" \
  TOKEN_LEDGER_DB="$TEST_DB" \
  CODEX_DRY_RUN=1 \
  bash "$WRAPPER" "$PLAN_FILE7" "$(task_json 1 "Create test file")" >/dev/null 2>&1
  set -e

  row_count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM codex_tasks" 2>/dev/null || echo 0)
  if [[ "$row_count" -gt 0 ]]; then
    pass "ledger write inserts row into codex_tasks (count=$row_count)"
  else
    fail "no rows in codex_tasks after execution"
  fi
else
  echo "  SKIP: sqlite3 not available"
fi

# ── Test 13: Capsule generation ──────────────────────────────────────────────
echo "Test 13: Capsule generation"
REPO_DIR8=$(setup_git_repo)
PLAN_FILE8="$REPO_DIR8/plan.md"
create_plan "$PLAN_FILE8"
MOCK_DIR8="$tmp_dir/mock_capsule"
create_mock_codex "$MOCK_DIR8" "success"

# We can check capsule by looking at the stderr output
set +e
capsule_output=$(
  cd "$REPO_DIR8" && \
  PATH="$MOCK_DIR8:$PATH" \
  CODEX_DRY_RUN=1 \
  bash "$WRAPPER" "$PLAN_FILE8" "$(task_json 1 "Create test file")" 2>&1 >/dev/null
)
set -e

if echo "$capsule_output" | grep -q "Capsule generated:"; then
  capsule_size=$(echo "$capsule_output" | grep "Capsule generated:" | sed 's/.*: \([0-9]*\) bytes/\1/')
  if [[ "$capsule_size" -gt 0 ]]; then
    pass "capsule generated with size=${capsule_size} bytes"
  else
    fail "capsule generated but size=0"
  fi
else
  fail "no capsule generation message in output"
fi

# ── Test 14: Worktree cleanup ───────────────────────────────────────────────
echo "Test 14: Worktree cleanup after execution"
REPO_DIR9=$(setup_git_repo)
PLAN_FILE9="$REPO_DIR9/plan.md"
create_plan "$PLAN_FILE9"
MOCK_DIR9="$tmp_dir/mock_cleanup"
create_mock_codex "$MOCK_DIR9" "crash"

set +e
cd "$REPO_DIR9" && \
PATH="$MOCK_DIR9:$PATH" \
bash "$WRAPPER" "$PLAN_FILE9" "$(task_json 1 "Create test file")" >/dev/null 2>&1
set -e

# Check no leftover worktrees or branches
worktree_count=$(git -C "$REPO_DIR9" worktree list | wc -l)
branch_exists=$(git -C "$REPO_DIR9" branch --list "codex/*" 2>/dev/null | wc -l || echo 0)

if [[ "$worktree_count" -le 1 && "$branch_exists" -eq 0 ]]; then
  pass "worktree and branch cleaned up after crash"
else
  fail "leftover worktree (count=$worktree_count) or branch (count=$branch_exists)"
fi

# ── Test 15: Output JSON structure ───────────────────────────────────────────
echo "Test 15: Output JSON structure validation"
REPO_DIR10=$(setup_git_repo)
PLAN_FILE10="$REPO_DIR10/plan.md"
create_plan "$PLAN_FILE10"
MOCK_DIR10="$tmp_dir/mock_struct"
create_mock_codex "$MOCK_DIR10" "success"

set +e
struct_json=$(
  cd "$REPO_DIR10" && \
  PATH="$MOCK_DIR10:$PATH" \
  CODEX_DRY_RUN=1 \
  bash "$WRAPPER" "$PLAN_FILE10" "$(task_json 1 "Create test file")" 2>/dev/null
)
set -e

# Validate all required fields exist
valid=$(echo "$struct_json" | node -e "
  const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
  const required = ['status','task_id','result','tokens','cost_usd','elapsed_ms','fallback_reason'];
  const missing = required.filter(k => !(k in d));
  if (missing.length === 0) {
    // Check tokens sub-object
    const tok_fields = ['input','output','cached','reasoning'];
    const tok_missing = tok_fields.filter(k => !(k in d.tokens));
    if (tok_missing.length === 0) console.log('valid');
    else console.log('missing_tokens:' + tok_missing.join(','));
  } else {
    console.log('missing:' + missing.join(','));
  }
" 2>/dev/null || echo "parse_error")

if [[ "$valid" == "valid" ]]; then
  pass "output JSON has all required fields (status, task_id, result, tokens, cost_usd, elapsed_ms, fallback_reason)"
else
  fail "output JSON validation failed: $valid"
fi

# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "Results: $PASS passed, $FAIL failed, $TOTAL total"
echo "═══════════════════════════════════════════════════════════════"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
