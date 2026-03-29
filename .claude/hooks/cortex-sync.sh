#!/usr/bin/env bash
# cortex-sync.sh
# PostToolUse hook — fires after Write|Edit on cortex SKILL.md files
# Syncs updated SKILL.md to local cortex repo (no remote credential URL).
#
# Bug fixes applied:
# 1. Removed credential-bearing CORTEX_REMOTE URL — uses local canonical path
# 2. Store stdin before piping to jq (INPUT=$(cat) pattern)
# 3. Removed set -e — uses per-command soft-fail with || exit 0

set -uo pipefail
# NOTE: Not using -e — individual commands soft-fail to prevent hook crashes

CORTEX_SKILLS_DIR="$HOME/.claude/skills"
CORTEX_REPO_DIR="$HOME/projects/cortex"  # Canonical local path — no credential URL

# Store stdin before any pipe operations
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_response.filePath // ""' 2>/dev/null)

# Only act on cortex SKILL.md files
[[ -z "$FILE_PATH" ]] && exit 0
[[ "$FILE_PATH" != "$CORTEX_SKILLS_DIR"/cortex-*/SKILL.md ]] && exit 0

# Derive skill directory name
SKILL_NAME="$(basename "$(dirname "$FILE_PATH")")"

# Soft-fail if local repo not available
[[ ! -d "$CORTEX_REPO_DIR/.git" ]] && exit 0

# Copy updated skill file into local repo
DEST="$CORTEX_REPO_DIR/skills/$SKILL_NAME/SKILL.md"
mkdir -p "$(dirname "$DEST")" 2>/dev/null || exit 0
cp "$FILE_PATH" "$DEST" 2>/dev/null || exit 0

cd "$CORTEX_REPO_DIR" || exit 0

# Only commit if there are actual changes
git diff --quiet "$DEST" 2>/dev/null && exit 0

git add "skills/$SKILL_NAME/SKILL.md" 2>/dev/null || exit 0
git commit -m "sync: update $SKILL_NAME" --quiet 2>/dev/null || exit 0

# Push only if remote is configured without embedded credentials
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "$REMOTE_URL" != *"@"* ]] && [[ -n "$REMOTE_URL" ]]; then
  git push origin main --quiet 2>/dev/null || true  # Soft-fail push
fi

echo "{\"systemMessage\": \"Cortex synced: $SKILL_NAME updated in local repo\"}"
exit 0
