#!/usr/bin/env bash
# codex-exec-wrapper.sh — Full lifecycle Codex execution wrapper
#
# Usage: codex-exec-wrapper.sh <PLAN_PATH> <TASK_JSON>
#
# TASK_JSON is a single task-router output entry (JSON object on one line):
#   { "task_id": "1", "task_name": "...", "classification": "codex-safe", ... }
#
# The script also reads task details from the PLAN.md file directly.
#
# Environment:
#   CODEX_SESSION_ID   Parent Claude session ID (for ledger)
#   CODEX_PHASE        Current GSD phase (for ledger)
#   CODEX_PROJECT_SLUG Project slug (for ledger)
#   TOKEN_LEDGER_DB    Override ledger DB path (default: ~/.cortex/token-ledger.db)
#   CODEX_TIMEOUT      Override timeout (default: auto-calculated)
#   CODEX_DRY_RUN      Set to 1 to skip actual Codex invocation
#
# Output: JSON on stdout with wrapper result.
# Diagnostics: stderr for human-readable progress.

set -euo pipefail

# ── Constants ────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORTEX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CAPSULE_TEMPLATE="$CORTEX_ROOT/templates/cortex/task-capsule.md"
DB_PATH="${TOKEN_LEDGER_DB:-$HOME/.cortex/token-ledger.db}"

# Codex model for pricing (o4-mini default)
CODEX_MODEL="${CODEX_MODEL:-o4-mini}"
CODEX_INPUT_PRICE="0.0000011"   # $1.10/1M
CODEX_OUTPUT_PRICE="0.0000044"  # $4.40/1M

# ── Argument parsing ────────────────────────────────────────────────────────
if [[ $# -lt 2 ]]; then
  echo "Usage: $(basename "$0") <PLAN_PATH> <TASK_JSON>" >&2
  echo "" >&2
  echo "TASK_JSON: single-line JSON from task-router.js output" >&2
  echo "Environment: CODEX_SESSION_ID, CODEX_PHASE, CODEX_PROJECT_SLUG" >&2
  exit 1
fi

PLAN_PATH="$1"
TASK_JSON="$2"

if [[ ! -f "$PLAN_PATH" ]]; then
  echo "Error: PLAN file not found: $PLAN_PATH" >&2
  exit 1
fi

# ── Parse task info ──────────────────────────────────────────────────────────
TASK_ID=$(echo "$TASK_JSON" | node -e "
  const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
  console.log(d.task_id);
" 2>/dev/null) || { echo "Error: Failed to parse TASK_JSON" >&2; exit 1; }

TASK_NAME=$(echo "$TASK_JSON" | node -e "
  const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
  console.log(d.task_name || '');
" 2>/dev/null) || TASK_NAME=""

# Extract phase and plan from PLAN.md frontmatter
PHASE=$(sed -n 's/^phase: *"\{0,1\}\([^"]*\)"\{0,1\} *$/\1/p' "$PLAN_PATH" | head -1)
PLAN=$(sed -n 's/^plan: *"\{0,1\}\([^"]*\)"\{0,1\} *$/\1/p' "$PLAN_PATH" | head -1)

if [[ -z "$PHASE" || -z "$PLAN" ]]; then
  echo "Error: Could not parse phase/plan from frontmatter in $PLAN_PATH" >&2
  exit 1
fi

# ── Extract task XML from PLAN.md ────────────────────────────────────────────
TASK_XML=$(node -e "
  const fs = require('fs');
  const content = fs.readFileSync(process.argv[1], 'utf8');
  const re = new RegExp('<task[^>]*id=\"${TASK_ID}\"[^>]*>[\\\\s\\\\S]*?</task>');
  const m = content.match(re);
  if (m) console.log(m[0]);
  else process.exit(1);
" "$PLAN_PATH" 2>/dev/null) || { echo "Error: Task $TASK_ID not found in $PLAN_PATH" >&2; exit 1; }

# Parse task fields from XML
parse_xml_field() {
  local field="$1"
  echo "$TASK_XML" | node -e "
    const d=require('fs').readFileSync('/dev/stdin','utf8');
    const re=new RegExp('<${field}>([\\\\s\\\\S]*?)</${field}>');
    const m=d.match(re);
    console.log(m ? m[1].trim() : '');
  " 2>/dev/null || echo ""
}

TASK_ACTION=$(parse_xml_field "action")
TASK_FILES=$(parse_xml_field "files")
TASK_VERIFY=$(parse_xml_field "verify")
TASK_DONE=$(parse_xml_field "done")

# Check for TDD attribute
TASK_TDD="false"
if echo "$TASK_XML" | grep -q 'tdd="true"'; then
  TASK_TDD="true"
fi

# Count files for timeout tier
FILE_COUNT=$(echo "$TASK_FILES" | tr ',' '\n' | sed 's/^ *//;s/ *$//' | grep -c '.' || echo "0")

# ── Calculate timeout ────────────────────────────────────────────────────────
if [[ -n "${CODEX_TIMEOUT:-}" ]]; then
  TIMEOUT="$CODEX_TIMEOUT"
elif [[ "$TASK_TDD" == "true" ]]; then
  TIMEOUT=180
elif [[ "$FILE_COUNT" -lt 5 ]]; then
  TIMEOUT=300
else
  TIMEOUT=450
fi

echo "[codex-wrapper] Task $TASK_ID \"$TASK_NAME\" timeout=${TIMEOUT}s files=$FILE_COUNT tdd=$TASK_TDD" >&2

# ── Temp files ───────────────────────────────────────────────────────────────
WORK_DIR=$(mktemp -d "/tmp/gsd-codex-${PHASE}-${PLAN}-XXXXXX")
CAPSULE_FILE="$WORK_DIR/capsule.md"
JSONL_FILE="$WORK_DIR/codex-output.jsonl"
RESULT_FILE="$WORK_DIR/result.json"
WORKTREE_PATH="$WORK_DIR/worktree"
BRANCH_NAME="codex/${PHASE}-${PLAN}-task${TASK_ID}"

# Initialize token/cost vars (populated after Codex runs)
INPUT_TOKENS=0
OUTPUT_TOKENS=0
CACHED_TOKENS=0
REASONING_TOKENS=0
COST_USD="0"
ELAPSED_MS=0

cleanup() {
  # Remove worktree if it exists
  if git worktree list 2>/dev/null | grep -q "$WORKTREE_PATH"; then
    git worktree remove --force "$WORKTREE_PATH" 2>/dev/null || true
  fi
  # Remove branch if it exists
  git branch -D "$BRANCH_NAME" 2>/dev/null || true
  # Remove temp dir
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

# ── Helper: output wrapper result JSON ───────────────────────────────────────
output_result() {
  local status="$1" fallback_reason="${2:-null}"
  local result_json="${3:-null}"
  local in_tok="${4:-$INPUT_TOKENS}" out_tok="${5:-$OUTPUT_TOKENS}"
  local cache_tok="${6:-$CACHED_TOKENS}" reason_tok="${7:-$REASONING_TOKENS}"
  local cost="${8:-$COST_USD}" elapsed="${9:-$ELAPSED_MS}"

  if [[ "$fallback_reason" != "null" ]]; then
    fallback_reason="\"$fallback_reason\""
  fi

  cat <<RESULT
{
  "status": "$status",
  "task_id": "$TASK_ID",
  "result": $result_json,
  "tokens": {
    "input": $in_tok,
    "output": $out_tok,
    "cached": $cache_tok,
    "reasoning": $reason_tok
  },
  "cost_usd": $cost,
  "elapsed_ms": $elapsed,
  "fallback_reason": $fallback_reason
}
RESULT
}

# ── Helper: write to token ledger ────────────────────────────────────────────
write_ledger() {
  local exit_code="${1:-0}"
  if [[ ! -f "$DB_PATH" ]]; then
    echo "[codex-wrapper] Warning: Token ledger not found at $DB_PATH, skipping write" >&2
    return 0
  fi
  if ! command -v sqlite3 &>/dev/null; then
    echo "[codex-wrapper] Warning: sqlite3 not available, skipping ledger write" >&2
    return 0
  fi
  sqlite3 "$DB_PATH" "INSERT INTO codex_tasks (
    task_id, model, input_tokens, output_tokens, cached_tokens, reasoning_tokens,
    cost_usd, session_id, project_slug, phase, task_type, plan_file, exit_code, elapsed_ms
  ) VALUES (
    '${PHASE}-${PLAN}-T${TASK_ID}',
    '${CODEX_MODEL}',
    ${INPUT_TOKENS},
    ${OUTPUT_TOKENS},
    ${CACHED_TOKENS},
    ${REASONING_TOKENS},
    ${COST_USD},
    '${CODEX_SESSION_ID:-unknown}',
    '${CODEX_PROJECT_SLUG:-unknown}',
    '${CODEX_PHASE:-$PHASE}',
    'codex-safe',
    '$(basename "$PLAN_PATH")',
    ${exit_code},
    ${ELAPSED_MS}
  );" 2>/dev/null || echo "[codex-wrapper] Warning: Failed to write to token ledger" >&2
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
            if (parsed.status) {
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

# ── Step 1: Create git worktree ──────────────────────────────────────────────
echo "[codex-wrapper] Creating worktree at $WORKTREE_PATH" >&2
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "HEAD")

if ! git worktree add "$WORKTREE_PATH" -b "$BRANCH_NAME" 2>/dev/null; then
  echo "[codex-wrapper] ERROR: Failed to create worktree" >&2
  output_result "fallback" "worktree_create_failed"
  exit 0
fi

echo "[codex-wrapper] Worktree created on branch $BRANCH_NAME" >&2

# ── Step 2: Generate capsule ─────────────────────────────────────────────────
echo "[codex-wrapper] Generating capsule from template" >&2

TOTAL_TASKS=$(grep -c '<task ' "$PLAN_PATH" || echo "1")

# Build file context (cap at 12KB total)
FILE_CONTEXT=""
CONTEXT_SIZE=0
MAX_CONTEXT=12288

while IFS= read -r filepath; do
  filepath=$(echo "$filepath" | sed 's/^ *//;s/ *$//')
  [[ -z "$filepath" ]] && continue
  local_path="$WORKTREE_PATH/$filepath"
  [[ ! -f "$local_path" ]] && local_path="$filepath"
  [[ ! -f "$local_path" ]] && continue

  file_content=$(head -200 "$local_path" 2>/dev/null || true)
  file_size=${#file_content}

  if (( CONTEXT_SIZE + file_size > MAX_CONTEXT )); then
    break
  fi

  FILE_CONTEXT="${FILE_CONTEXT}
### ${filepath}
\`\`\`
${file_content}
\`\`\`
"
  CONTEXT_SIZE=$((CONTEXT_SIZE + file_size))
done <<< "$(echo "$TASK_FILES" | tr ',' '\n')"

# Determine commit type heuristic
COMMIT_TYPE="feat"
if echo "$TASK_ACTION" | grep -qi "test\|spec"; then
  COMMIT_TYPE="test"
elif echo "$TASK_ACTION" | grep -qi "fix\|bug\|repair"; then
  COMMIT_TYPE="fix"
elif echo "$TASK_ACTION" | grep -qi "refactor\|clean"; then
  COMMIT_TYPE="refactor"
elif echo "$TASK_ACTION" | grep -qi "config\|tool\|depend"; then
  COMMIT_TYPE="chore"
fi

# Populate template
if [[ -f "$CAPSULE_TEMPLATE" ]]; then
  sed \
    -e "s|{PHASE}|$PHASE|g" \
    -e "s|{PLAN}|$PLAN|g" \
    -e "s|{TASK_NUMBER}|$TASK_ID|g" \
    -e "s|{TOTAL_TASKS}|$TOTAL_TASKS|g" \
    -e "s|{WORKSPACE_PATH}|$WORKTREE_PATH|g" \
    -e "s|{PROJECT_SLUG}|${CODEX_PROJECT_SLUG:-unknown}|g" \
    -e "s|{BRANCH}|$BRANCH_NAME|g" \
    -e "s|{TASK_NAME}|$TASK_NAME|g" \
    -e "s|{COMMIT_TYPE}|$COMMIT_TYPE|g" \
    -e "s|{COMMIT_DESCRIPTION}|$TASK_NAME|g" \
    -e "s|{KEY_CHANGE_1}|Implement $TASK_NAME|g" \
    -e "s|{KEY_CHANGE_2}|Verify with: $TASK_VERIFY|g" \
    "$CAPSULE_TEMPLATE" > "$CAPSULE_FILE"

  # Replace multi-line fields using node
  node -e "
    const fs = require('fs');
    let c = fs.readFileSync(process.argv[1], 'utf8');
    c = c.replace('{TASK_ACTION}', process.argv[2]);
    c = c.replace('{TASK_FILES}', process.argv[3]);
    c = c.replace('{VERIFY_COMMAND}', process.argv[4]);
    c = c.replace('{DONE_CRITERIA}', process.argv[5]);
    c = c.replace('{FILE_CONTEXT}', process.argv[6]);
    fs.writeFileSync(process.argv[1], c);
  " "$CAPSULE_FILE" "$TASK_ACTION" "$TASK_FILES" "$TASK_VERIFY" "$TASK_DONE" "$FILE_CONTEXT" 2>/dev/null
else
  # Fallback: write a minimal capsule
  cat > "$CAPSULE_FILE" << CAPSULE
# Task ${TASK_ID}: ${TASK_NAME}

## Action
${TASK_ACTION}

## Files
${TASK_FILES}

## Verify
\`\`\`bash
${TASK_VERIFY}
\`\`\`

## Done Criteria
${TASK_DONE}

## Commit
After completing, commit with: ${COMMIT_TYPE}(${PHASE}-${PLAN}): ${TASK_NAME}
Stage files individually. Never use git add . or git add -A.

## Result Format
Output a single JSON block as final message:
\`\`\`json
{
  "status": "complete",
  "files_changed": [],
  "tests_passed": true,
  "test_output_summary": "",
  "deviations": [],
  "commit_hash": "",
  "error_message": null,
  "checkpoint_detail": null
}
\`\`\`
CAPSULE
fi

CAPSULE_SIZE=$(wc -c < "$CAPSULE_FILE")
echo "[codex-wrapper] Capsule generated: ${CAPSULE_SIZE} bytes" >&2

# ── Step 3: Invoke Codex ─────────────────────────────────────────────────────
START_MS=$(date +%s%3N 2>/dev/null || echo "$(date +%s)000")
CODEX_EXIT=0

if [[ "${CODEX_DRY_RUN:-}" == "1" ]]; then
  echo "[codex-wrapper] DRY RUN: would invoke codex with timeout=${TIMEOUT}s" >&2
  cat > "$JSONL_FILE" << 'MOCK'
{"type":"turn.completed","message":{"role":"assistant","content":"{\"status\":\"complete\",\"files_changed\":[],\"tests_passed\":true,\"test_output_summary\":\"dry run\",\"deviations\":[],\"commit_hash\":\"0000000\",\"error_message\":null,\"checkpoint_detail\":null}"},"usage":{"input_tokens":1000,"output_tokens":500,"cached_tokens":200,"reasoning_tokens":100}}
MOCK
else
  echo "[codex-wrapper] Invoking codex (timeout=${TIMEOUT}s)..." >&2
  set +e
  timeout "$TIMEOUT" codex exec \
    --full-auto \
    --json \
    -C "$WORKTREE_PATH" \
    - < "$CAPSULE_FILE" 2>"$WORK_DIR/stderr.log" | tee "$JSONL_FILE" > /dev/null
  CODEX_EXIT=$?
  set -e
fi

END_MS=$(date +%s%3N 2>/dev/null || echo "$(date +%s)000")
ELAPSED_MS=$(( END_MS - START_MS ))

echo "[codex-wrapper] Codex exited with code $CODEX_EXIT (${ELAPSED_MS}ms)" >&2

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

echo "[codex-wrapper] Tokens: in=$INPUT_TOKENS out=$OUTPUT_TOKENS cached=$CACHED_TOKENS reasoning=$REASONING_TOKENS cost=\$$COST_USD" >&2

# ── Step 5: Handle failure cases ─────────────────────────────────────────────

# Timeout (exit 124)
if [[ "$CODEX_EXIT" -eq 124 ]]; then
  echo "[codex-wrapper] TIMEOUT after ${TIMEOUT}s" >&2
  WORKTREE_COMMITS=$(git -C "$WORKTREE_PATH" log --oneline "$CURRENT_BRANCH..$BRANCH_NAME" 2>/dev/null | wc -l || echo 0)
  if [[ "$WORKTREE_COMMITS" -gt 0 ]]; then
    echo "[codex-wrapper] Found $WORKTREE_COMMITS commits in worktree, attempting merge" >&2
    if git merge "$BRANCH_NAME" --no-edit 2>/dev/null; then
      echo "[codex-wrapper] Partial work merged successfully" >&2
    else
      git merge --abort 2>/dev/null || true
      echo "[codex-wrapper] Merge of partial work failed, discarding" >&2
    fi
  fi
  write_ledger "$CODEX_EXIT"
  output_result "fallback" "timeout"
  exit 0
fi

# Process crash (non-zero, non-124)
if [[ "$CODEX_EXIT" -ne 0 ]]; then
  echo "[codex-wrapper] CRASH: codex exited with code $CODEX_EXIT" >&2
  if [[ -f "$WORK_DIR/stderr.log" ]]; then
    echo "[codex-wrapper] stderr:" >&2
    head -20 "$WORK_DIR/stderr.log" >&2
  fi
  write_ledger "$CODEX_EXIT"
  output_result "fallback" "crash"
  exit 0
fi

# ── Step 6: Extract result JSON from JSONL ───────────────────────────────────
if ! extract_result "$JSONL_FILE" "$RESULT_FILE"; then
  echo "[codex-wrapper] PARSE ERROR: Could not extract result JSON from JSONL" >&2
  WORKTREE_COMMITS=$(git -C "$WORKTREE_PATH" log --oneline "$CURRENT_BRANCH..$BRANCH_NAME" 2>/dev/null | wc -l || echo 0)
  if [[ "$WORKTREE_COMMITS" -gt 0 ]]; then
    echo "[codex-wrapper] Found $WORKTREE_COMMITS commits despite parse error" >&2
  fi
  write_ledger "0"
  output_result "fallback" "parse_error"
  exit 0
fi

echo "[codex-wrapper] Result JSON extracted successfully" >&2

# ── Step 7: Validate result ──────────────────────────────────────────────────
RESULT_STATUS=$(node -e "const d=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));console.log(d.status)" "$RESULT_FILE" 2>/dev/null || echo "unknown")
RESULT_TESTS=$(node -e "const d=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));console.log(d.tests_passed)" "$RESULT_FILE" 2>/dev/null || echo "false")
RESULT_CONTENT=$(cat "$RESULT_FILE")

# Checkpoint hit
if [[ "$RESULT_STATUS" == "checkpoint" ]]; then
  echo "[codex-wrapper] CHECKPOINT: Codex hit Rule 4 architectural decision" >&2
  CHECKPOINT_DETAIL=$(node -e "const d=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));console.log(d.checkpoint_detail||'unknown')" "$RESULT_FILE" 2>/dev/null || echo "unknown")
  echo "[codex-wrapper] Detail: $CHECKPOINT_DETAIL" >&2
  write_ledger "0"
  output_result "fallback" "checkpoint" "$RESULT_CONTENT"
  exit 0
fi

# Tests failed
if [[ "$RESULT_STATUS" == "failed" || "$RESULT_TESTS" == "false" ]]; then
  echo "[codex-wrapper] TEST FAILURE: tests_passed=$RESULT_TESTS status=$RESULT_STATUS" >&2
  write_ledger "1"
  output_result "fallback" "test_failure" "$RESULT_CONTENT"
  exit 0
fi

# ── Step 8: Merge worktree on success ────────────────────────────────────────
echo "[codex-wrapper] SUCCESS: Merging $BRANCH_NAME into $CURRENT_BRANCH" >&2

if ! git merge "$BRANCH_NAME" --no-edit 2>/dev/null; then
  echo "[codex-wrapper] MERGE CONFLICT: Could not merge $BRANCH_NAME" >&2
  git merge --abort 2>/dev/null || true
  write_ledger "0"
  output_result "fallback" "merge_conflict" "$RESULT_CONTENT"
  exit 0
fi

echo "[codex-wrapper] Merge successful" >&2

# ── Step 9: Write to token ledger ────────────────────────────────────────────
write_ledger "0"

# Output success result
output_result "complete" "null" "$RESULT_CONTENT"
