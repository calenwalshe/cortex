#!/usr/bin/env bash
# codex-eval-executor.sh — Read-only eval execution wrapper
#
# Fork of codex-exec-wrapper.sh specialised for evaluation runs.
# EVAL-SPECIFIC divergences from exec-wrapper (marked with # EVAL-SPECIFIC:):
#   1. Arguments: <CAPSULE_FILE> only — no PLAN_PATH or TASK_JSON required
#   2. No merge-on-success — worktree is ALWAYS torn down; eval is read-only
#   3. --output-schema flag on codex invocation constrains output to eval-result.schema.json
#   4. JSONL events renamed: eval_started / eval_completed / eval_failed
#   5. Ledger row task_type = "eval" (hardcoded, not plan-derived)
#
# Usage: codex-eval-executor.sh <CAPSULE_FILE>
#
# Environment:
#   CODEX_SESSION_ID      Parent session ID (for ledger)
#   CODEX_PROJECT_SLUG    Project slug (for ledger)
#   TOKEN_LEDGER_DB       Override ledger DB path (default: ~/.cortex/token-ledger.db)
#   CODEX_TIMEOUT         Override timeout in seconds (default: 300)
#   CODEX_DRY_RUN         Set to 1 to skip actual Codex invocation
#   EVAL_RESULT_OUTPUT    If set, write eval-result.json to this path in addition to stdout
#
# Output: JSON on stdout with eval result.
# Diagnostics: stderr for human-readable progress.

set -euo pipefail

# ── Constants ────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
EVAL_SCHEMA="$PROJECT_ROOT/schemas/eval-result.schema.json"
DB_PATH="${TOKEN_LEDGER_DB:-$HOME/.cortex/token-ledger.db}"

# EVAL-SPECIFIC: circuit breaker namespace separate from exec-wrapper
CIRCUIT_BREAKER_THRESHOLD="${CODEX_CIRCUIT_BREAKER:-3}"
CIRCUIT_BREAKER_FILE="/tmp/cortex-eval-circuit-breaker-$(basename "$PWD")"

MAX_STEPS_MULTIPLIER="${CODEX_MAX_STEPS_MULTIPLIER:-10}"

# EVAL-SPECIFIC: event log uses same dir but different event names
EVENT_LOG_DIR="${PROJECT_ROOT}/.cortex/events"
mkdir -p "$EVENT_LOG_DIR" 2>/dev/null || true

CODEX_MODEL="${CODEX_MODEL:-o4-mini}"
CODEX_INPUT_PRICE="0.0000011"
CODEX_OUTPUT_PRICE="0.0000044"

# ── Argument parsing ─────────────────────────────────────────────────────────
# EVAL-SPECIFIC: only takes CAPSULE_FILE — eval capsule is pre-assembled
if [[ $# -lt 1 ]]; then
  echo "Usage: $(basename "$0") <CAPSULE_FILE>" >&2
  echo "" >&2
  echo "CAPSULE_FILE: path to eval-capsule.md (from generate-eval-capsule.py)" >&2
  echo "Environment: CODEX_SESSION_ID, CODEX_PROJECT_SLUG, TOKEN_LEDGER_DB" >&2
  exit 1
fi

CAPSULE_INPUT="$1"

if [[ ! -f "$CAPSULE_INPUT" ]]; then
  echo "Error: CAPSULE_FILE not found: $CAPSULE_INPUT" >&2
  exit 1
fi

# Extract slug from capsule
SLUG=$(grep -m1 '^\*\*Slug:\*\*' "$CAPSULE_INPUT" | sed 's/\*\*Slug:\*\* *//' | tr -d '[:space:]' || echo "unknown")
EVAL_PLAN_PATH=$(grep -m1 '^\*\*Eval Plan:\*\*' "$CAPSULE_INPUT" | sed 's/\*\*Eval Plan:\*\* *//' | tr -d '[:space:]' || echo "unknown")

# EVAL-SPECIFIC: flat ID format (no phase/plan hierarchy)
TASK_ID="eval-${SLUG}-$(date +%s)"

# Timeout: fixed default for evals (no file-count scaling needed)
TIMEOUT="${CODEX_TIMEOUT:-300}"

echo "[codex-eval] Eval slug='$SLUG' capsule='$CAPSULE_INPUT' timeout=${TIMEOUT}s" >&2

# ── Temp files ───────────────────────────────────────────────────────────────
WORK_DIR=$(mktemp -d "/tmp/cortex-eval-${SLUG}-XXXXXX")
CAPSULE_FILE="$WORK_DIR/capsule.md"
JSONL_FILE="$WORK_DIR/codex-output.jsonl"
RESULT_FILE="$WORK_DIR/result.json"
WORKTREE_PATH="$WORK_DIR/worktree"

# EVAL-SPECIFIC: branch name scoped to eval namespace
BRANCH_NAME="eval/${SLUG}-$(date +%s)"

# Initialize token/cost vars
INPUT_TOKENS=0
OUTPUT_TOKENS=0
CACHED_TOKENS=0
REASONING_TOKENS=0
COST_USD="0"
ELAPSED_MS=0

# EVAL-SPECIFIC: cleanup always tears down worktree — no merge path
cleanup() {
  if git worktree list 2>/dev/null | grep -q "$WORKTREE_PATH"; then
    git worktree remove --force "$WORKTREE_PATH" >/dev/null 2>&1 || true
  fi
  git branch -D "$BRANCH_NAME" >/dev/null 2>&1 || true
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

# ── Helper: output wrapper result JSON ───────────────────────────────────────
output_result() {
  local status="$1" fallback_reason="${2:-null}"
  local result_json="${3:-null}"

  local out
  out=$(node -e "
    const out = {
      status: process.argv[1],
      task_id: process.argv[2],
      result: process.argv[3] === 'null' ? null : JSON.parse(process.argv[3]),
      tokens: {
        input: parseInt(process.argv[4]) || 0,
        output: parseInt(process.argv[5]) || 0,
        cached: parseInt(process.argv[6]) || 0,
        reasoning: parseInt(process.argv[7]) || 0
      },
      cost_usd: parseFloat(process.argv[8]) || 0,
      elapsed_ms: parseInt(process.argv[9]) || 0,
      fallback_reason: process.argv[10] === 'null' ? null : process.argv[10]
    };
    console.log(JSON.stringify(out, null, 2));
  " "$status" "$TASK_ID" "$result_json" "$INPUT_TOKENS" "$OUTPUT_TOKENS" \
    "$CACHED_TOKENS" "$REASONING_TOKENS" "$COST_USD" "$ELAPSED_MS" "$fallback_reason" 2>/dev/null || echo '{"status":"'"$status"'","fallback_reason":"'"$fallback_reason"'"}')

  echo "$out"

  # EVAL-SPECIFIC: also write to EVAL_RESULT_OUTPUT if set
  if [[ -n "${EVAL_RESULT_OUTPUT:-}" ]]; then
    if [[ "$result_json" != "null" ]]; then
      echo "$result_json" > "$EVAL_RESULT_OUTPUT"
    fi
  fi
}

# ── Helper: write to token ledger ────────────────────────────────────────────
write_ledger() {
  local exit_code="${1:-0}"
  if [[ ! -f "$DB_PATH" ]]; then
    echo "[codex-eval] Warning: Token ledger not found at $DB_PATH, skipping write" >&2
    return 0
  fi
  if ! command -v sqlite3 &>/dev/null; then
    echo "[codex-eval] Warning: sqlite3 not available, skipping ledger write" >&2
    return 0
  fi
  sqlite3 "$DB_PATH" "INSERT INTO codex_tasks (
    task_id, model, input_tokens, output_tokens, cached_tokens, reasoning_tokens,
    cost_usd, session_id, project_slug, phase, task_type, plan_file, exit_code, elapsed_ms
  ) VALUES (
    '${TASK_ID}',
    '${CODEX_MODEL}',
    ${INPUT_TOKENS},
    ${OUTPUT_TOKENS},
    ${CACHED_TOKENS},
    ${REASONING_TOKENS},
    ${COST_USD},
    '${CODEX_SESSION_ID:-unknown}',
    '${CODEX_PROJECT_SLUG:-${SLUG}}',
    'eval',
    'eval',
    '$(basename "$CAPSULE_INPUT")',
    ${exit_code},
    ${ELAPSED_MS}
  );" 2>/dev/null || echo "[codex-eval] Warning: Failed to write to token ledger" >&2
  # EVAL-SPECIFIC: task_type is hardcoded 'eval' — not plan-derived
}

# ── Helper: log execution event to JSONL ─────────────────────────────────────
log_event() {
  local event_type="$1"  # EVAL-SPECIFIC: eval_started / eval_completed / eval_failed
  local details="${2:-{}}"
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "unknown")
  local event_file="$EVENT_LOG_DIR/events-$(date +%Y%m%d).jsonl"
  node -e "
    const evt = {
      type: process.argv[1],
      timestamp: process.argv[2],
      task_id: process.argv[3],
      slug: process.argv[4],
      eval_plan: process.argv[5],
      details: JSON.parse(process.argv[6] || '{}')
    };
    console.log(JSON.stringify(evt));
  " "$event_type" "$ts" "$TASK_ID" "$SLUG" "$EVAL_PLAN_PATH" "$details" >> "$event_file" 2>/dev/null || true
}

# ── Helper: extract result JSON from JSONL ───────────────────────────────────
extract_result() {
  local jsonl_file="$1" output_file="$2"
  node -e "
    const fs = require('fs');
    const lines = fs.readFileSync(process.argv[1], 'utf8').trim().split('\\n');
    for (let i = lines.length - 1; i >= 0; i--) {
      if (!lines[i].trim()) continue;
      try {
        const obj = JSON.parse(lines[i]);
        if (obj.type === 'turn.completed' && obj.message && obj.message.content) {
          const content = typeof obj.message.content === 'string'
            ? obj.message.content
            : JSON.stringify(obj.message.content);
          const jsonMatch = content.match(/\`\`\`json\\n([\\s\\S]*?)\\n\`\`\`/);
          if (jsonMatch) {
            const parsed = JSON.parse(jsonMatch[1]);
            fs.writeFileSync(process.argv[2], JSON.stringify(parsed, null, 2));
            process.exit(0);
          }
          try {
            const parsed = JSON.parse(content);
            if (parsed.overall_verdict) {
              fs.writeFileSync(process.argv[2], JSON.stringify(parsed, null, 2));
              process.exit(0);
            }
          } catch(e2) {}
        }
      } catch(e) {}
    }
    process.exit(1);
  " "$jsonl_file" "$output_file" 2>/dev/null
}

# ── Helper: parse JSONL for token usage ──────────────────────────────────────
parse_tokens() {
  local jsonl_file="$1"
  node -e "
    const fs = require('fs');
    const lines = fs.readFileSync(process.argv[1], 'utf8').trim().split('\\n');
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
  " "$jsonl_file" 2>/dev/null || echo '{"input":0,"output":0,"cached":0,"reasoning":0}'
}

# ── Helper: record failure for circuit breaker ───────────────────────────────
record_failure() {
  local count
  count=$(cat "$CIRCUIT_BREAKER_FILE" 2>/dev/null || echo "0")
  echo $(( count + 1 )) > "$CIRCUIT_BREAKER_FILE"
  echo "[codex-eval] Circuit breaker: $(( count + 1 ))/$CIRCUIT_BREAKER_THRESHOLD consecutive failures" >&2
}

# ── Step 1: Copy capsule to work dir ─────────────────────────────────────────
cp "$CAPSULE_INPUT" "$CAPSULE_FILE"
CAPSULE_SIZE=$(wc -c < "$CAPSULE_FILE")
echo "[codex-eval] Capsule: ${CAPSULE_SIZE} bytes" >&2

# Derive file count from capsule for iteration budget
FILE_COUNT=$(grep -c '^\### `' "$CAPSULE_FILE" 2>/dev/null || true)
FILE_COUNT="${FILE_COUNT:-0}"
# grep -c returns 0 lines as "0" which is falsy for lt check — normalize
[[ -z "$FILE_COUNT" || "$FILE_COUNT" -lt 1 ]] && FILE_COUNT=3

# ── Circuit Breaker Check ────────────────────────────────────────────────────
CONSECUTIVE_FAILURES=0
if [[ -f "$CIRCUIT_BREAKER_FILE" ]]; then
  CONSECUTIVE_FAILURES=$(cat "$CIRCUIT_BREAKER_FILE" 2>/dev/null || echo "0")
fi

if [[ "$CONSECUTIVE_FAILURES" -ge "$CIRCUIT_BREAKER_THRESHOLD" ]]; then
  echo "[codex-eval] CIRCUIT BREAKER: $CONSECUTIVE_FAILURES consecutive failures (threshold: $CIRCUIT_BREAKER_THRESHOLD)" >&2
  echo "[codex-eval] Eval dispatch stopped. Reset with: rm $CIRCUIT_BREAKER_FILE" >&2
  log_event "eval_failed" "{\"reason\":\"circuit_breaker\",\"consecutive_failures\":$CONSECUTIVE_FAILURES}"
  output_result "fallback" "circuit_breaker"
  exit 0
fi

# ── Iteration Budget ─────────────────────────────────────────────────────────
MAX_STEPS=$(( FILE_COUNT * MAX_STEPS_MULTIPLIER ))
[[ "$MAX_STEPS" -lt 20 ]] && MAX_STEPS=20

echo "[codex-eval] Iteration budget: max_steps=$MAX_STEPS" >&2

# ── Step 2: Create git worktree ───────────────────────────────────────────────
echo "[codex-eval] Creating read-only worktree at $WORKTREE_PATH" >&2
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "HEAD")

if ! git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME" >/dev/null 2>&1; then
  echo "[codex-eval] ERROR: Failed to create worktree" >&2
  output_result "fallback" "worktree_create_failed"
  exit 0
fi

echo "[codex-eval] Worktree created on branch $BRANCH_NAME" >&2

# ── Step 3: Invoke Codex ──────────────────────────────────────────────────────
# EVAL-SPECIFIC: eval_started event
log_event "eval_started" "{\"file_count\":$FILE_COUNT,\"timeout\":$TIMEOUT,\"max_steps\":$MAX_STEPS}"
START_MS=$(date +%s%3N 2>/dev/null || echo "$(date +%s)000")
CODEX_EXIT=0

if [[ "${CODEX_DRY_RUN:-}" == "1" ]]; then
  echo "[codex-eval] DRY RUN: would invoke codex with timeout=${TIMEOUT}s" >&2
  cat > "$JSONL_FILE" << 'MOCK'
{"type":"turn.completed","message":{"role":"assistant","content":"{\"overall_verdict\":\"pass\",\"evaluated_dimensions\":[{\"dimension\":\"Functional Correctness\",\"verdict\":\"pass\",\"finding\":\"Dry run — no actual evaluation\",\"severity\":\"note\",\"fixtures_tested\":[],\"failures\":[]}],\"deviations\":[],\"convergence_risk\":null}"},"usage":{"input_tokens":100,"output_tokens":50,"cached_tokens":0,"reasoning_tokens":0}}
MOCK
else
  echo "[codex-eval] Invoking codex (timeout=${TIMEOUT}s)..." >&2
  set +e
  # EVAL-SPECIFIC: --output-schema constrains codex to eval-result.schema.json format
  timeout "$TIMEOUT" codex exec \
    --full-auto \
    --json \
    --output-schema "$EVAL_SCHEMA" \
    -C "$WORKTREE_PATH" \
    - < "$CAPSULE_FILE" 2>"$WORK_DIR/stderr.log" | tee "$JSONL_FILE" > /dev/null
  CODEX_EXIT=$?
  set -e
fi

END_MS=$(date +%s%3N 2>/dev/null || echo "$(date +%s)000")
ELAPSED_MS=$(( END_MS - START_MS ))

echo "[codex-eval] Codex exited with code $CODEX_EXIT (${ELAPSED_MS}ms)" >&2

# ── Step 4: Parse JSONL for token usage ──────────────────────────────────────
if [[ -f "$JSONL_FILE" ]] && [[ -s "$JSONL_FILE" ]]; then
  TOKENS_JSON=$(parse_tokens "$JSONL_FILE")
  INPUT_TOKENS=$(echo "$TOKENS_JSON" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.input)" 2>/dev/null || echo 0)
  OUTPUT_TOKENS=$(echo "$TOKENS_JSON" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.output)" 2>/dev/null || echo 0)
  CACHED_TOKENS=$(echo "$TOKENS_JSON" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.cached)" 2>/dev/null || echo 0)
  REASONING_TOKENS=$(echo "$TOKENS_JSON" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));console.log(d.reasoning)" 2>/dev/null || echo 0)
fi

COST_USD=$(node -e "
  const inp = $INPUT_TOKENS * $CODEX_INPUT_PRICE;
  const out = $OUTPUT_TOKENS * $CODEX_OUTPUT_PRICE;
  console.log((inp + out).toFixed(6));
" 2>/dev/null || echo "0")

echo "[codex-eval] Tokens: in=$INPUT_TOKENS out=$OUTPUT_TOKENS cost=\$$COST_USD" >&2

# ── Step 5: Handle failure cases ──────────────────────────────────────────────

# Iteration budget check
STEP_COUNT=0
if [[ -f "$JSONL_FILE" ]] && [[ -s "$JSONL_FILE" ]]; then
  STEP_COUNT=$(node -e "
    const fs = require('fs');
    const lines = fs.readFileSync(process.argv[1], 'utf8').trim().split('\\n');
    let steps = 0;
    for (const line of lines) {
      try {
        const obj = JSON.parse(line);
        if (obj.type === 'turn.completed') steps++;
      } catch(e) {}
    }
    console.log(steps);
  " "$JSONL_FILE" 2>/dev/null || echo "0")

  if [[ "$STEP_COUNT" -ge "$MAX_STEPS" ]]; then
    echo "[codex-eval] ITERATION BUDGET EXCEEDED: $STEP_COUNT steps >= $MAX_STEPS" >&2
    # EVAL-SPECIFIC: eval_failed event
    log_event "eval_failed" "{\"reason\":\"iteration_budget_exceeded\",\"step_count\":$STEP_COUNT,\"max_steps\":$MAX_STEPS}"
    record_failure
    write_ledger "1"
    output_result "fallback" "iteration_budget_exceeded"
    exit 0
  fi
fi

# Timeout
if [[ "$CODEX_EXIT" -eq 124 ]]; then
  echo "[codex-eval] TIMEOUT after ${TIMEOUT}s" >&2
  # EVAL-SPECIFIC: no partial merge on timeout — just log and report
  record_failure
  write_ledger "$CODEX_EXIT"
  output_result "fallback" "timeout"
  exit 0
fi

# Process crash
if [[ "$CODEX_EXIT" -ne 0 ]]; then
  echo "[codex-eval] CRASH: codex exited with code $CODEX_EXIT" >&2
  if [[ -f "$WORK_DIR/stderr.log" ]]; then
    head -20 "$WORK_DIR/stderr.log" >&2
  fi
  record_failure
  write_ledger "$CODEX_EXIT"
  output_result "fallback" "crash"
  exit 0
fi

# ── Step 6: Extract result JSON from JSONL ────────────────────────────────────
if ! extract_result "$JSONL_FILE" "$RESULT_FILE"; then
  echo "[codex-eval] PARSE ERROR: Could not extract eval result JSON from JSONL" >&2
  record_failure
  write_ledger "0"
  output_result "fallback" "parse_error"
  exit 0
fi

echo "[codex-eval] Eval result extracted successfully" >&2
RESULT_CONTENT=$(cat "$RESULT_FILE")

# EVAL-SPECIFIC: no merge step — worktree is torn down by cleanup trap
# The cleanup trap fires on EXIT and removes the worktree unconditionally.

# Reset circuit breaker on success
rm -f "$CIRCUIT_BREAKER_FILE"

# EVAL-SPECIFIC: eval_completed event (not task_completed)
log_event "eval_completed" "{\"exit_code\":0,\"step_count\":${STEP_COUNT},\"elapsed_ms\":$ELAPSED_MS}"

# ── Step 7: Write to token ledger ─────────────────────────────────────────────
write_ledger "0"

# Output eval result
output_result "complete" "null" "$RESULT_CONTENT"
