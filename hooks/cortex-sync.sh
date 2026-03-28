#!/usr/bin/env bash
# cortex-sync.sh
# PostToolUse hook — fires after Write|Edit
# If the modified file is a cortex SKILL.md, syncs it to the GitHub repo.

set -euo pipefail

CORTEX_SKILLS_DIR="$HOME/.claude/skills"
CORTEX_REPO_DIR="$HOME/projects/cortex-repo"
CORTEX_REMOTE="https://calenwalshe:${GH_TOKEN}@github.com/calenwalshe/cortex.git"

# Extract file path from hook stdin JSON
FILE_PATH="$(jq -r '.tool_input.file_path // .tool_response.filePath // ""' 2>/dev/null)"

# Only act on cortex SKILL.md files
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

if [[ "$FILE_PATH" != "$CORTEX_SKILLS_DIR"/cortex-*/SKILL.md ]]; then
  exit 0
fi

# Derive skill directory name (e.g. cortex-audit)
SKILL_NAME="$(basename "$(dirname "$FILE_PATH")")"

# Ensure repo is cloned
if [[ ! -d "$CORTEX_REPO_DIR/.git" ]]; then
  git clone "$CORTEX_REMOTE" "$CORTEX_REPO_DIR" 2>/dev/null
fi

# Copy updated skill file into repo
DEST="$CORTEX_REPO_DIR/skills/$SKILL_NAME/SKILL.md"
mkdir -p "$(dirname "$DEST")"
cp "$FILE_PATH" "$DEST"

# Commit and push
cd "$CORTEX_REPO_DIR"
git config user.email "agent@cortex.dev" 2>/dev/null
git config user.name "Cortex Sync" 2>/dev/null
git remote set-url origin "$CORTEX_REMOTE" 2>/dev/null

# Only commit if there are actual changes
if git diff --quiet "$DEST" 2>/dev/null && git diff --cached --quiet "$DEST" 2>/dev/null; then
  exit 0
fi

git add "skills/$SKILL_NAME/SKILL.md"
git commit -m "sync: update $SKILL_NAME" --quiet
git push origin main --quiet 2>/dev/null

echo "{\"systemMessage\": \"Cortex synced: $SKILL_NAME pushed to GitHub\"}"
