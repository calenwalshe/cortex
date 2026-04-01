#!/usr/bin/env bash
# auto-doc-sync.sh — git pre-commit hook
# Detects changes to Cortex source files and generates documentation updates
# via the Anthropic API. Writes updates to working tree for human review.

set -uo pipefail

# ── Escape hatches ──────────────────────────────────────────────────────────

if [[ "${SKIP_LLM_GITHOOK:-}" == "1" ]]; then
  exit 0
fi

if [[ "${SKIP:-}" == *"auto-doc-sync"* ]]; then
  exit 0
fi

# ── Configuration ───────────────────────────────────────────────────────────

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
CONFIG_FILE="${REPO_ROOT}/.auto-doc-sync.json"
API_URL="https://api.anthropic.com/v1/messages"
MODEL="claude-haiku-4-5-20241022"
API_TIMEOUT=30

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "[auto-doc-sync] Config file not found: $CONFIG_FILE — skipping"
  exit 0
fi

if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
  echo "[auto-doc-sync] WARNING: ANTHROPIC_API_KEY is not set — skipping doc sync"
  exit 0
fi

# ── Source file filtering ───────────────────────────────────────────────────

STAGED_FILES=$(git diff --cached --name-only 2>/dev/null) || exit 0

if [[ -z "$STAGED_FILES" ]]; then
  exit 0
fi

# Build list of triggered mappings
TRIGGERED_MAPPINGS="[]"
TRIGGERED_COUNT=0

while IFS= read -r staged_file; do
  # Match staged file against source_glob entries in config
  MATCHES=$(jq -r --arg file "$staged_file" '
    .[] | (.source_glob | gsub("\\*"; ".*") | gsub("\\?"; ".")) as $pat |
    select($file | test($pat)) | .id
  ' "$CONFIG_FILE" 2>/dev/null) || continue

  if [[ -n "$MATCHES" ]]; then
    while IFS= read -r match_id; do
      ENTRY=$(jq --arg id "$match_id" '.[] | select(.id == $id)' "$CONFIG_FILE")
      TRIGGERED_MAPPINGS=$(echo "$TRIGGERED_MAPPINGS" | jq --argjson entry "$ENTRY" '. + [$entry]')
      TRIGGERED_COUNT=$((TRIGGERED_COUNT + 1))
    done <<< "$MATCHES"
  fi
done <<< "$STAGED_FILES"

if [[ "$TRIGGERED_COUNT" -eq 0 ]]; then
  exit 0
fi

# Deduplicate by id
TRIGGERED_MAPPINGS=$(echo "$TRIGGERED_MAPPINGS" | jq 'unique_by(.id)')
TRIGGERED_COUNT=$(echo "$TRIGGERED_MAPPINGS" | jq 'length')

# ── Heuristic classifier ───────────────────────────────────────────────────
# Skip LLM call if ALL diffs are comment-only or whitespace-only

ALL_TRIVIAL=true
while IFS= read -r staged_file; do
  HAS_MATCH=$(echo "$TRIGGERED_MAPPINGS" | jq -r --arg file "$staged_file" '
    .[] | (.source_glob | gsub("\\*"; ".*") | gsub("\\?"; ".")) as $pat |
    select($file | test($pat)) | .id' 2>/dev/null)

  if [[ -z "$HAS_MATCH" ]]; then
    continue
  fi

  DIFF_CONTENT=$(git diff --cached -- "$staged_file" 2>/dev/null) || continue

  # Extract only added/removed lines (not headers)
  CHANGED_LINES=$(echo "$DIFF_CONTENT" | grep -E '^[+-]' | grep -vE '^(\+\+\+|---)' || true)

  if [[ -z "$CHANGED_LINES" ]]; then
    continue
  fi

  # Check if all changed lines are comments or whitespace
  # For .md files, # is a heading (content), not a comment — only treat <!-- --> as comments
  if [[ "$staged_file" == *.md ]]; then
    NON_TRIVIAL=$(echo "$CHANGED_LINES" | grep -vE '^[+-]\s*$' | grep -vE '^[+-]\s*(<!--|-->)' || true)
  else
    NON_TRIVIAL=$(echo "$CHANGED_LINES" | grep -vE '^[+-]\s*$' | grep -vE '^[+-]\s*(#|<!--|-->|//|/\*|\*/)' || true)
  fi

  if [[ -n "$NON_TRIVIAL" ]]; then
    ALL_TRIVIAL=false
    break
  fi
done <<< "$STAGED_FILES"

if [[ "$ALL_TRIVIAL" == "true" ]]; then
  echo "[auto-doc-sync] All changes are comment-only or whitespace-only — skipping LLM call"
  exit 0
fi

# ── Conflict detection ──────────────────────────────────────────────────────

STAGED_DOCS=$(git diff --cached --name-only 2>/dev/null) || true
FINAL_MAPPINGS="[]"

while IFS= read -r mapping; do
  TARGET_DOC=$(echo "$mapping" | jq -r '.target_doc')
  TARGET_SECTION=$(echo "$mapping" | jq -r '.target_section')

  # Check if target doc is already staged
  if echo "$STAGED_DOCS" | grep -qF "$TARGET_DOC"; then
    if [[ "${FORCE_DOC_SYNC:-}" != "1" ]]; then
      echo "[auto-doc-sync] Skipping $TARGET_DOC ($TARGET_SECTION) — already staged. Set FORCE_DOC_SYNC=1 to override."
      continue
    fi
  fi

  # Check for skip marker in first 50 lines
  TARGET_PATH="${REPO_ROOT}/${TARGET_DOC}"
  if [[ -f "$TARGET_PATH" ]]; then
    if head -50 "$TARGET_PATH" | grep -qF '<!-- auto-doc-sync:skip -->'; then
      echo "[auto-doc-sync] Skipping $TARGET_DOC ($TARGET_SECTION) — skip marker found"
      continue
    fi
  fi

  FINAL_MAPPINGS=$(echo "$FINAL_MAPPINGS" | jq --argjson m "$mapping" '. + [$m]')
done < <(echo "$TRIGGERED_MAPPINGS" | jq -c '.[]')

FINAL_COUNT=$(echo "$FINAL_MAPPINGS" | jq 'length')
if [[ "$FINAL_COUNT" -eq 0 ]]; then
  exit 0
fi

# ── Extract current sections ────────────────────────────────────────────────

extract_section() {
  local file="$1"
  local heading="$2"
  local heading_level

  # Determine heading level from the heading string
  heading_level=$(echo "$heading" | grep -oE '^#+' | wc -c)
  heading_level=$((heading_level - 1))

  if [[ ! -f "$file" ]]; then
    echo ""
    return
  fi

  awk -v heading="$heading" -v level="$heading_level" '
    BEGIN { found=0; collecting=0 }
    $0 == heading { found=1; collecting=1; print; next }
    collecting && /^#{1,}[[:space:]]/ {
      match($0, /^#+/)
      curr_level = RLENGTH
      if (curr_level <= level) { collecting=0; next }
    }
    collecting { print }
  ' "$file"
}

CURRENT_SECTIONS=""
while IFS= read -r mapping; do
  TARGET_DOC=$(echo "$mapping" | jq -r '.target_doc')
  TARGET_SECTION=$(echo "$mapping" | jq -r '.target_section')
  TARGET_PATH="${REPO_ROOT}/${TARGET_DOC}"

  SECTION_CONTENT=$(extract_section "$TARGET_PATH" "$TARGET_SECTION")

  CURRENT_SECTIONS="${CURRENT_SECTIONS}
--- ${TARGET_DOC} § ${TARGET_SECTION} ---
${SECTION_CONTENT}
"
done < <(echo "$FINAL_MAPPINGS" | jq -c '.[]')

# ── Build diff content ──────────────────────────────────────────────────────

AGGREGATE_DIFF=""
while IFS= read -r staged_file; do
  HAS_MATCH=$(echo "$FINAL_MAPPINGS" | jq -r --arg file "$staged_file" '
    .[] | (.source_glob | gsub("\\*"; ".*") | gsub("\\?"; ".")) as $pat |
    select($file | test($pat)) | .id' 2>/dev/null)

  if [[ -n "$HAS_MATCH" ]]; then
    FILE_DIFF=$(git diff --cached -- "$staged_file" 2>/dev/null) || continue
    AGGREGATE_DIFF="${AGGREGATE_DIFF}
${FILE_DIFF}
"
  fi
done <<< "$STAGED_FILES"

# ── Batched LLM call ───────────────────────────────────────────────────────

MAPPING_JSON=$(echo "$FINAL_MAPPINGS" | jq -c '.')

# Build the prompt
PROMPT=$(cat << INNER_PROMPT
You are a documentation synchronization assistant. Your job is to update specific sections of documentation files to reflect changes in source files.

## Context

The following source files have been modified in a git commit:

${AGGREGATE_DIFF}

## Mapping Context

These mappings describe which documentation sections need updating:

${MAPPING_JSON}

## Current Documentation Sections

For each mapping above, here is the current content of the target section:

${CURRENT_SECTIONS}

## Instructions

1. For each mapping, compare the diff against the current documentation section.
2. If the diff introduces changes that affect the documented behavior, produce an updated version of that section.
3. Preserve the existing markdown structure and heading level.
4. Do not invent behavior that is not present in the diff.
5. If a diff does not require any documentation change for a given mapping, omit that mapping from the response.

## Response Format

Return a JSON array. Each element is an object with these fields:
[{"target_doc": "...", "target_section": "...", "updated_content": "..."}]

If no updates are needed, return: []

Do not include any text outside the JSON array.
INNER_PROMPT
)

# Build API request body
REQUEST_BODY=$(jq -n \
  --arg model "$MODEL" \
  --arg prompt "$PROMPT" \
  '{
    model: $model,
    max_tokens: 4096,
    messages: [{ role: "user", content: $prompt }]
  }')

# Make the API call
RESPONSE=$(curl -s --max-time "$API_TIMEOUT" \
  -H "Content-Type: application/json" \
  -H "x-api-key: ${ANTHROPIC_API_KEY}" \
  -H "anthropic-version: 2023-06-01" \
  -d "$REQUEST_BODY" \
  "$API_URL" 2>/dev/null) || {
  echo "[auto-doc-sync] WARNING: API call failed — skipping doc sync"
  exit 0
}

# Check for API errors
API_ERROR=$(echo "$RESPONSE" | jq -r '.error.message // empty' 2>/dev/null) || true
if [[ -n "$API_ERROR" ]]; then
  echo "[auto-doc-sync] WARNING: API error: $API_ERROR — skipping doc sync"
  exit 0
fi

# ── Response parsing ────────────────────────────────────────────────────────

# Extract the text content from the API response
RAW_CONTENT=$(echo "$RESPONSE" | jq -r '.content[0].text // empty' 2>/dev/null) || {
  echo "[auto-doc-sync] WARNING: Could not parse API response — skipping"
  exit 0
}

if [[ -z "$RAW_CONTENT" ]]; then
  echo "[auto-doc-sync] WARNING: Empty API response — skipping"
  exit 0
fi

# Strip markdown fences if present
CLEAN_JSON=$(echo "$RAW_CONTENT" | sed -E '/^```(json)?$/d')

# Validate JSON
if ! echo "$CLEAN_JSON" | jq empty 2>/dev/null; then
  echo "[auto-doc-sync] WARNING: Invalid JSON in API response — skipping"
  exit 0
fi

UPDATE_COUNT=$(echo "$CLEAN_JSON" | jq 'length' 2>/dev/null) || {
  echo "[auto-doc-sync] WARNING: Could not parse update count — skipping"
  exit 0
}

if [[ "$UPDATE_COUNT" -eq 0 ]]; then
  echo "[auto-doc-sync] No documentation updates needed"
  exit 0
fi

# ── File write + diff output ───────────────────────────────────────────────

replace_section() {
  local file="$1"
  local heading="$2"
  local new_content="$3"
  local heading_level

  heading_level=$(echo "$heading" | grep -oE '^#+' | wc -c)
  heading_level=$((heading_level - 1))

  if [[ ! -f "$file" ]]; then
    echo "[auto-doc-sync] WARNING: Target file not found: $file — skipping"
    return 1
  fi

  local tmpfile
  tmpfile=$(mktemp)

  awk -v heading="$heading" -v level="$heading_level" -v newcontent="$new_content" '
    BEGIN { found=0; skipping=0; printed_new=0 }
    $0 == heading {
      found=1; skipping=1; printed_new=0
      printf "%s\n", newcontent
      printed_new=1
      next
    }
    skipping && /^#{1,}[[:space:]]/ {
      match($0, /^#+/)
      curr_level = RLENGTH
      if (curr_level <= level) { skipping=0; print; next }
    }
    skipping { next }
    { print }
  ' "$file" > "$tmpfile"

  mv "$tmpfile" "$file"
  return 0
}

echo "[auto-doc-sync] Applying $UPDATE_COUNT documentation update(s):"
echo ""

UPDATES_APPLIED=0
for i in $(seq 0 $((UPDATE_COUNT - 1))); do
  TARGET_DOC=$(echo "$CLEAN_JSON" | jq -r ".[$i].target_doc")
  TARGET_SECTION=$(echo "$CLEAN_JSON" | jq -r ".[$i].target_section")
  UPDATED_CONTENT=$(echo "$CLEAN_JSON" | jq -r ".[$i].updated_content")

  TARGET_PATH="${REPO_ROOT}/${TARGET_DOC}"

  if [[ -z "$TARGET_DOC" || -z "$TARGET_SECTION" || -z "$UPDATED_CONTENT" ]]; then
    echo "[auto-doc-sync] WARNING: Incomplete update entry at index $i — skipping"
    continue
  fi

  # Save current content for diff
  BEFORE=$(mktemp)
  cp "$TARGET_PATH" "$BEFORE" 2>/dev/null || continue

  if replace_section "$TARGET_PATH" "$TARGET_SECTION" "$UPDATED_CONTENT"; then
    echo "  → ${TARGET_DOC} § ${TARGET_SECTION}"
    diff -u "$BEFORE" "$TARGET_PATH" --label "a/${TARGET_DOC}" --label "b/${TARGET_DOC}" || true
    echo ""
    UPDATES_APPLIED=$((UPDATES_APPLIED + 1))
  fi

  rm -f "$BEFORE"
done

if [[ "$UPDATES_APPLIED" -gt 0 ]]; then
  echo "[auto-doc-sync] $UPDATES_APPLIED file(s) updated in working tree. Review and stage manually."
fi

exit 0
