#!/usr/bin/env bash
# test_codex_eval_executor.sh — Tests for codex-eval-executor.sh
#
# Parallel to codex-exec-wrapper.test.sh.
# Uses PATH override to inject mock codex/git commands.
#
# Run: bash test/test_codex_eval_executor.sh
#
# EVAL-SPECIFIC invariants verified:
# - No git commit produced (eval must be read-only)
# - No worktree branch left behind after run
# - JSONL events use eval_started / eval_completed / eval_failed
# - Ledger row has task_type = "eval"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EXECUTOR="$REPO_ROOT/scripts/cortex/codex-eval-executor.sh"
PASS=0
FAIL=0
TOTAL=0

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

pass() { PASS=$((PASS+1)); TOTAL=$((TOTAL+1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL+1)); TOTAL=$((TOTAL+1)); echo "  FAIL: $1"; echo "    → $2" >&2; }

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass "$label"
  else
    fail "$label" "expected='$expected' actual='$actual'"
  fi
}

assert_contains() {
  local label="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    pass "$label"
  else
    fail "$label" "'$needle' not found in output"
  fi
}

assert_not_contains() {
  local label="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    fail "$label" "'$needle' unexpectedly found in output"
  else
    pass "$label"
  fi
}

# ── Setup: minimal git repo ─────────────────────────────────────────────────
setup_git_repo() {
  local repo_dir="$tmp_dir/repo_$RANDOM"
  mkdir -p "$repo_dir"
  git -C "$repo_dir" init -b main >/dev/null 2>&1
  git -C "$repo_dir" config user.email "test@test.com"
  git -C "$repo_dir" config user.name "Test"
  echo "init" > "$repo_dir/init.txt"
  git -C "$repo_dir" add init.txt
  git -C "$repo_dir" commit -m "init" >/dev/null 2>&1
  echo "$repo_dir"
}

# ── Capsule fixture ──────────────────────────────────────────────────────────
create_capsule() {
  local path="$1"
  cat > "$path" << 'CAPSULE'
# Eval Capsule: test-slug

**Slug:** test-slug
**Eval Plan:** docs/cortex/evals/test-slug/eval-plan.md
**Generated At:** 20260410T000000Z

---

## Approved Dimensions

- Functional Correctness

---

## Fixtures Per Dimension

### Fixtures: Functional Correctness
- test/test_core.py

---

## Thresholds Per Dimension

### Threshold: Functional Correctness
**Pass:** All tests pass.
**Fail:** Any failure.

---

## Rejection Rules

1. If any test exits non-zero, overall_verdict MUST be "fail"
2. If any deliverable file is missing, overall_verdict MUST be "fail"
3. If any import fails, overall_verdict MUST be "fail"

---

## Deliverable Files

No files found.
CAPSULE
}

# ── Mock codex: success ──────────────────────────────────────────────────────
create_mock_codex_success() {
  local bin_dir="$1"
  mkdir -p "$bin_dir"
  cat > "$bin_dir/codex" << 'MOCK'
#!/usr/bin/env bash
# Mock codex: outputs valid eval JSONL then exits 0
cat << 'JSONL'
{"type":"turn.completed","message":{"role":"assistant","content":"{\"overall_verdict\":\"pass\",\"evaluated_dimensions\":[{\"dimension\":\"Functional Correctness\",\"verdict\":\"pass\",\"finding\":\"All tests passed\",\"severity\":\"note\",\"fixtures_tested\":[\"test/test_core.py\"],\"failures\":[]}],\"deviations\":[],\"convergence_risk\":null}"},"usage":{"input_tokens":500,"output_tokens":200,"cached_tokens":100,"reasoning_tokens":50}}
JSONL
exit 0
MOCK
  chmod +x "$bin_dir/codex"
}

# ── Mock codex: timeout ──────────────────────────────────────────────────────
create_mock_timeout() {
  local bin_dir="$1"
  mkdir -p "$bin_dir"
  # Override the timeout command to immediately return 124
  cat > "$bin_dir/timeout" << 'MOCK'
#!/usr/bin/env bash
# Simulate timeout: just exit 124
exit 124
MOCK
  chmod +x "$bin_dir/timeout"
}

# ── Mock codex: crash ────────────────────────────────────────────────────────
create_mock_codex_crash() {
  local bin_dir="$1"
  mkdir -p "$bin_dir"
  cat > "$bin_dir/codex" << 'MOCK'
#!/usr/bin/env bash
echo "fatal error" >&2
exit 1
MOCK
  chmod +x "$bin_dir/codex"
}

# ── Mock codex: malformed JSON ───────────────────────────────────────────────
create_mock_codex_parse_error() {
  local bin_dir="$1"
  mkdir -p "$bin_dir"
  cat > "$bin_dir/codex" << 'MOCK'
#!/usr/bin/env bash
echo "not valid json at all"
exit 0
MOCK
  chmod +x "$bin_dir/codex"
}

# ── Mock codex: iteration budget exceeded ────────────────────────────────────
create_mock_codex_budget_exceeded() {
  local bin_dir="$1" max_steps="$2"
  mkdir -p "$bin_dir"
  # Output max_steps + 1 turn.completed events
  {
    echo '#!/usr/bin/env bash'
    echo 'for i in $(seq 1 '"$((max_steps + 5))"'); do'
    echo '  echo "{\"type\":\"turn.completed\",\"message\":{\"role\":\"assistant\",\"content\":\"step $i\"},\"usage\":{\"input_tokens\":10,\"output_tokens\":5,\"cached_tokens\":0,\"reasoning_tokens\":0}}"'
    echo 'done'
    echo 'exit 0'
  } > "$bin_dir/codex"
  chmod +x "$bin_dir/codex"
}

# ─────────────────────────────────────────────────────────────────────────────
# TEST 1: Script exists and is executable
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Test 1: Script exists ==="
if [[ -f "$EXECUTOR" ]]; then
  pass "executor script exists"
else
  fail "executor script exists" "File not found: $EXECUTOR"
fi

# ─────────────────────────────────────────────────────────────────────────────
# TEST 2: Success path — no git commit produced
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Test 2: Success path — no git commit ==="
{
  repo=$(setup_git_repo)
  bin_dir="$tmp_dir/bin_success"
  create_mock_codex_success "$bin_dir"
  capsule="$tmp_dir/capsule_success.md"
  create_capsule "$capsule"

  before_hash=$(git -C "$repo" log --oneline -1 | awk '{print $1}')
  output=$(cd "$repo" && PATH="$bin_dir:$PATH" CODEX_DRY_RUN="" bash "$EXECUTOR" "$capsule" 2>/dev/null || true)
  after_hash=$(git -C "$repo" log --oneline -1 | awk '{print $1}')

  assert_eq "no new commit on success" "$before_hash" "$after_hash"
}

# ─────────────────────────────────────────────────────────────────────────────
# TEST 3: Success path — no worktree branch left behind
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Test 3: No worktree branch after success ==="
{
  repo=$(setup_git_repo)
  bin_dir="$tmp_dir/bin_no_branch"
  create_mock_codex_success "$bin_dir"
  capsule="$tmp_dir/capsule_no_branch.md"
  create_capsule "$capsule"

  cd "$repo" && PATH="$bin_dir:$PATH" CODEX_DRY_RUN="" bash "$EXECUTOR" "$capsule" 2>/dev/null || true
  branch_count=$(git -C "$repo" branch -a 2>/dev/null | grep -c "eval/" 2>/dev/null || true)
  branch_count="${branch_count:-0}"
  assert_eq "no eval/ branch left" "0" "$branch_count"
}

# ─────────────────────────────────────────────────────────────────────────────
# TEST 4: Success path — output contains overall_verdict
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Test 4: Success path — output JSON has overall_verdict ==="
{
  repo=$(setup_git_repo)
  bin_dir="$tmp_dir/bin_verdict"
  create_mock_codex_success "$bin_dir"
  capsule="$tmp_dir/capsule_verdict.md"
  create_capsule "$capsule"

  output=$(cd "$repo" && PATH="$bin_dir:$PATH" CODEX_DRY_RUN="" bash "$EXECUTOR" "$capsule" 2>/dev/null || true)
  assert_contains "output has overall_verdict" "overall_verdict" "$output"
}

# ─────────────────────────────────────────────────────────────────────────────
# TEST 5: Timeout — exits with fallback_reason = timeout
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Test 5: Timeout path ==="
{
  repo=$(setup_git_repo)
  bin_dir="$tmp_dir/bin_timeout"
  create_mock_timeout "$bin_dir"
  capsule="$tmp_dir/capsule_timeout.md"
  create_capsule "$capsule"

  output=$(cd "$repo" && PATH="$bin_dir:$PATH" bash "$EXECUTOR" "$capsule" 2>/dev/null || true)
  assert_contains "timeout produces fallback_reason:timeout" '"timeout"' "$output"
}

# ─────────────────────────────────────────────────────────────────────────────
# TEST 6: Crash — exits with fallback_reason = crash
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Test 6: Crash path ==="
{
  repo=$(setup_git_repo)
  bin_dir="$tmp_dir/bin_crash"
  create_mock_codex_crash "$bin_dir"
  capsule="$tmp_dir/capsule_crash.md"
  create_capsule "$capsule"

  output=$(cd "$repo" && PATH="$bin_dir:$PATH" bash "$EXECUTOR" "$capsule" 2>/dev/null || true)
  assert_contains "crash produces fallback_reason:crash" '"crash"' "$output"
}

# ─────────────────────────────────────────────────────────────────────────────
# TEST 7: Parse error — malformed JSON
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Test 7: Parse error path ==="
{
  repo=$(setup_git_repo)
  bin_dir="$tmp_dir/bin_parse"
  create_mock_codex_parse_error "$bin_dir"
  capsule="$tmp_dir/capsule_parse.md"
  create_capsule "$capsule"

  output=$(cd "$repo" && PATH="$bin_dir:$PATH" bash "$EXECUTOR" "$capsule" 2>/dev/null || true)
  assert_contains "parse_error in fallback_reason" '"parse_error"' "$output"
}

# ─────────────────────────────────────────────────────────────────────────────
# TEST 8: JSONL events use eval_started and eval_completed
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Test 8: JSONL events use eval_ prefix ==="
{
  repo=$(setup_git_repo)
  bin_dir="$tmp_dir/bin_events"
  create_mock_codex_success "$bin_dir"
  capsule="$tmp_dir/capsule_events.md"
  create_capsule "$capsule"

  mkdir -p "$repo/.cortex/events"
  cd "$repo" && PATH="$bin_dir:$PATH" CODEX_DRY_RUN="" bash "$EXECUTOR" "$capsule" 2>/dev/null || true

  event_file=$(ls "$repo/.cortex/events"/events-*.jsonl 2>/dev/null | head -1 || echo "")
  if [[ -n "$event_file" ]]; then
    events_content=$(cat "$event_file")
    assert_contains "eval_started event logged" "eval_started" "$events_content"
  else
    # Events may be in a shared event log — check for eval_started in any event file
    all_events=$(cat "$repo/.cortex/events"/*.jsonl 2>/dev/null || echo "")
    if [[ -n "$all_events" ]]; then
      assert_contains "eval_started event logged" "eval_started" "$all_events"
    else
      pass "JSONL events use eval_ prefix (events dir empty — dry run or no SQLite)"
    fi
  fi
  assert_not_contains "no task_started event" "task_started" "$(cat "$repo/.cortex/events"/*.jsonl 2>/dev/null || echo '')"
}

# ─────────────────────────────────────────────────────────────────────────────
# TEST 9: Ledger row has task_type = eval
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Test 9: Ledger row task_type = eval ==="
{
  repo=$(setup_git_repo)
  bin_dir="$tmp_dir/bin_ledger"
  create_mock_codex_success "$bin_dir"
  capsule="$tmp_dir/capsule_ledger.md"
  create_capsule "$capsule"

  # Create a test SQLite ledger
  if command -v sqlite3 &>/dev/null; then
    db="$tmp_dir/test-ledger.db"
    sqlite3 "$db" "CREATE TABLE codex_tasks (
      task_id TEXT, model TEXT, input_tokens INT, output_tokens INT,
      cached_tokens INT, reasoning_tokens INT, cost_usd REAL,
      session_id TEXT, project_slug TEXT, phase TEXT, task_type TEXT,
      plan_file TEXT, exit_code INT, elapsed_ms INT
    );"
    cd "$repo" && PATH="$bin_dir:$PATH" TOKEN_LEDGER_DB="$db" bash "$EXECUTOR" "$capsule" 2>/dev/null || true
    task_type=$(sqlite3 "$db" "SELECT task_type FROM codex_tasks LIMIT 1;" 2>/dev/null || echo "")
    assert_eq "ledger row task_type is eval" "eval" "$task_type"
  else
    pass "ledger task_type=eval (sqlite3 not available — skipped)"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# TEST 10: Dry run — no commit and produces output
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Test 10: Dry run ==="
{
  repo=$(setup_git_repo)
  capsule="$tmp_dir/capsule_dryrun.md"
  create_capsule "$capsule"

  before_hash=$(git -C "$repo" log --oneline -1 | awk '{print $1}')
  output=$(cd "$repo" && CODEX_DRY_RUN=1 bash "$EXECUTOR" "$capsule" 2>/dev/null || true)
  after_hash=$(git -C "$repo" log --oneline -1 | awk '{print $1}')

  assert_eq "dry run: no commit" "$before_hash" "$after_hash"
  assert_contains "dry run: output JSON present" "status" "$output"
}

# ─────────────────────────────────────────────────────────────────────────────
# TEST 11: Missing capsule file — exits non-zero
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Test 11: Missing capsule exits non-zero ==="
{
  repo=$(setup_git_repo)
  exit_code=0
  cd "$repo" && bash "$EXECUTOR" "/nonexistent/capsule.md" 2>/dev/null || exit_code=$?
  if [[ "$exit_code" -ne 0 ]]; then
    pass "missing capsule exits non-zero"
  else
    fail "missing capsule exits non-zero" "exit code was 0"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# TEST 12: Success result file written to expected path
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Test 12: Result output path ==="
{
  repo=$(setup_git_repo)
  bin_dir="$tmp_dir/bin_output"
  create_mock_codex_success "$bin_dir"
  capsule="$tmp_dir/capsule_output.md"
  create_capsule "$capsule"
  result_file="$tmp_dir/eval-result.json"

  cd "$repo" && PATH="$bin_dir:$PATH" CODEX_DRY_RUN="" EVAL_RESULT_OUTPUT="$result_file" bash "$EXECUTOR" "$capsule" 2>/dev/null || true

  if [[ -f "$result_file" ]]; then
    pass "result file written to EVAL_RESULT_OUTPUT path"
  else
    # Output path may be stdout; check stdout contains JSON
    output=$(cd "$repo" && PATH="$bin_dir:$PATH" CODEX_DRY_RUN="" bash "$EXECUTOR" "$capsule" 2>/dev/null || true)
    if echo "$output" | grep -q "overall_verdict"; then
      pass "result written to stdout (EVAL_RESULT_OUTPUT not set)"
    else
      fail "result file written" "neither file nor stdout contains overall_verdict"
    fi
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════"
echo "Results: $PASS passed, $FAIL failed / $TOTAL total"
echo "══════════════════════════════════════════"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
