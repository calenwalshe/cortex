#!/usr/bin/env bash
# cortex-critique-guard.sh
# PreToolUse on Write|Edit — LLM-as-judge gate that blocks setting
# research_complete=true in .cortex/state.json unless adversarial
# critique (cortex-critique via Codex) has verifiably run.
#
# Judge is Codex with claude -p fallback. Not a file-existence check —
# the LLM reads the actual critique artifact content and receipts.
# Cannot be bypassed by writing a dummy receipt.

set -uo pipefail

CORTEX_STATE="${CLAUDE_PROJECT_DIR}/.cortex/state.json"
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)

# Only care about writes to .cortex/state.json
[[ "$FILE_PATH" != "$CORTEX_STATE" ]] && exit 0
[[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" ]] && exit 0

# Extract the new content based on tool type
if [[ "$TOOL_NAME" == "Write" ]]; then
    NEW_CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // ""' 2>/dev/null)
else
    NEW_CONTENT=$(echo "$INPUT" | jq -r '.tool_input.new_string // ""' 2>/dev/null)
fi

# Only trigger when research_complete is being set to true
echo "$NEW_CONTENT" | grep -qE '"research_complete"\s*:\s*true' || exit 0

# Soft-fail if state unreadable
[[ ! -f "$CORTEX_STATE" ]] && exit 0

SLUG=$(jq -r '.slug // ""' "$CORTEX_STATE" 2>/dev/null || echo "")
[[ -z "$SLUG" ]] && exit 0

# Read critique receipts already on disk (written by cortex-critique before this gate)
# Pre-filter to current slug only — prevents a prior slug's dossier receipt from satisfying this guard
RECEIPTS=$(jq -c "[.critique_receipts // [] | .[] | select(.slug == \"${SLUG}\")]" "$CORTEX_STATE" 2>/dev/null || echo "[]")

# Find most recent dossier critique artifact for this slug
REVIEWS_DIR="${CLAUDE_PROJECT_DIR}/docs/cortex/reviews/${SLUG}"
CRITIQUE_FILE=$(ls -t "${REVIEWS_DIR}"/critique-dossier-*.md 2>/dev/null | head -1 || echo "")

CRITIQUE_EXISTS="no"
CRITIQUE_CONTENT="(no artifact found)"
if [[ -n "$CRITIQUE_FILE" && -f "$CRITIQUE_FILE" ]]; then
    CRITIQUE_EXISTS="yes"
    CRITIQUE_CONTENT=$(head -80 "$CRITIQUE_FILE")
fi

# Build judge prompt — lean, PASS/FAIL verdict only
JUDGE_PROMPT="You are a compliance judge for the Cortex research pipeline.
The system wants to set research_complete=true for slug: ${SLUG}
Your job: verify whether adversarial critique (cortex-critique) actually ran on the research dossier.

Evidence:
1. critique_receipts in state.json: ${RECEIPTS}
2. Critique artifact exists on disk: ${CRITIQUE_EXISTS}
3. Critique artifact content (first 80 lines):
${CRITIQUE_CONTENT}

PASS criteria (ALL must hold):
- critique_receipts contains an entry with gate=dossier and slug=${SLUG}
- The artifact exists
- The artifact has a non-empty findings section (not CRITIQUE_FAILED, not empty)
- The artifact shows engine=codex or engine=claude-p-fallback

FAIL if any criterion is missing.

Respond with valid JSON only, no prose:
{\"verdict\": \"PASS\" or \"FAIL\", \"reason\": \"one sentence explaining the verdict\"}"

# Resolve Codex and Claude CLI paths
NVM_BIN="${HOME}/.nvm/versions/node/v20.20.0/bin"
NODE_BIN=$(command -v node 2>/dev/null || echo "${NVM_BIN}/node")
CODEX_SYM=$(command -v codex 2>/dev/null || echo "${NVM_BIN}/codex")
CODEX_CLI=$(readlink -f "$CODEX_SYM" 2>/dev/null || echo "$CODEX_SYM")
CLAUDE_SYM=$(command -v claude 2>/dev/null || echo "${NVM_BIN}/claude")
CLAUDE_CLI=$(readlink -f "$CLAUDE_SYM" 2>/dev/null || echo "$CLAUDE_SYM")

# Invoke judge — Codex first, claude -p fallback
JUDGE_OUTPUT=""
JUDGE_ENGINE="none"

if [[ -x "$CODEX_CLI" ]]; then
    JUDGE_OUTPUT=$("$NODE_BIN" "$CODEX_CLI" exec --full-auto --profile llm \
        --skip-git-repo-check --cd /tmp "$JUDGE_PROMPT" 2>/dev/null || echo "")
    JUDGE_ENGINE="codex"
fi

if [[ -z "$JUDGE_OUTPUT" ]] && [[ -x "$CLAUDE_CLI" ]]; then
    JUDGE_OUTPUT=$("$NODE_BIN" "$CLAUDE_CLI" -p "$JUDGE_PROMPT" 2>/dev/null || echo "")
    JUDGE_ENGINE="claude-p-fallback"
fi

# Parse verdict — fail-safe to FAIL on any parse error
VERDICT=$(echo "$JUDGE_OUTPUT" | python3 -c "
import json, sys, re
try:
    text = sys.stdin.read()
    m = re.search(r'\{[^{}]*\}', text, re.DOTALL)
    if m:
        data = json.loads(m.group())
        v = data.get('verdict', 'FAIL').strip().upper()
        print('PASS' if v == 'PASS' else 'FAIL')
    else:
        print('FAIL')
except:
    print('FAIL')
" 2>/dev/null || echo "FAIL")

REASON=$(echo "$JUDGE_OUTPUT" | python3 -c "
import json, sys, re
try:
    text = sys.stdin.read()
    m = re.search(r'\{[^{}]*\}', text, re.DOTALL)
    if m:
        data = json.loads(m.group())
        print(data.get('reason', 'no reason returned'))
    else:
        print('judge output was not valid JSON')
except:
    print('judge invocation failed')
" 2>/dev/null || echo "judge invocation failed")

# PASS — allow write
[[ "$VERDICT" == "PASS" ]] && exit 0

# FAIL — deny write with actionable reason
python3 -c "
import json, sys
slug, reason, engine = sys.argv[1], sys.argv[2], sys.argv[3]
msg = (
    f'Critique guard [{engine}]: research_complete=true blocked — '
    f'adversarial critique not verified for slug \"{slug}\". '
    f'Judge: {reason}. '
    f'Fix: run /cortex-critique --artifact <dossier_path> --gate dossier --slug {slug}'
)
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'permissionDecision': 'deny',
        'permissionDecisionReason': msg
    }
}))
" "$SLUG" "$REASON" "$JUDGE_ENGINE"

exit 0
