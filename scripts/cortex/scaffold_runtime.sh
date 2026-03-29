#!/usr/bin/env bash
# scaffold_runtime.sh — idempotent Cortex runtime scaffold
#
# Usage: scaffold_runtime.sh <target-project-root>
#
# Creates the full docs/cortex/ and .cortex/ directory structure in a target
# project. Safe to re-run — existing files are never overwritten (cp -n).

set -euo pipefail

# ── argument check ────────────────────────────────────────────────────────────
if [[ $# -lt 1 ]]; then
  echo "Usage: $(basename "$0") <target-project-root>" >&2
  exit 1
fi

mkdir -p "$1"
TARGET="$(cd "$1" && pwd)"

# ── resolve templates dir relative to script location (CWD-independent) ──────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/../../templates/cortex"

if [[ ! -d "$TEMPLATES_DIR" ]]; then
  echo "Error: templates directory not found at $TEMPLATES_DIR" >&2
  exit 1
fi

echo "Scaffolding Cortex runtime at: $TARGET"
echo ""

# ── docs/cortex/ subdirectories ───────────────────────────────────────────────
DOCS_SUBDIRS=(clarify research specs contracts evals investigations reviews audits handoffs)

for subdir in "${DOCS_SUBDIRS[@]}"; do
  mkdir -p "$TARGET/docs/cortex/$subdir"
done
echo "Created: docs/cortex/ subdirs (${DOCS_SUBDIRS[*]})"

# ── .cortex/ runtime directories ─────────────────────────────────────────────
mkdir -p "$TARGET/.cortex"
mkdir -p "$TARGET/.cortex/runs"
mkdir -p "$TARGET/.cortex/tmp"
mkdir -p "$TARGET/.cortex/compaction"
echo "Created: .cortex/ and runtime subdirs (runs, tmp, compaction)"

# ── continuity seed files → docs/cortex/handoffs/ ────────────────────────────
HANDOFFS_DIR="$TARGET/docs/cortex/handoffs"
SEED_FILES=(
  current-state.md
  open-questions.md
  next-prompt.md
  decisions.md
  eval-status.md
  last-compact-summary.md
)

echo ""
echo "Seeding continuity files:"
for seed_file in "${SEED_FILES[@]}"; do
  src="$TEMPLATES_DIR/$seed_file"
  dst="$HANDOFFS_DIR/$seed_file"
  if [[ -f "$src" ]]; then
    if [[ -f "$dst" ]]; then
      echo "  skipped:  docs/cortex/handoffs/$seed_file (already exists)"
    else
      cp "$src" "$dst"
      echo "  created:  docs/cortex/handoffs/$seed_file"
    fi
  else
    echo "  warning:  template not found: $src" >&2
  fi
done

# ── .cortex/state.json ────────────────────────────────────────────────────────
STATE_JSON="$TARGET/.cortex/state.json"
if [[ ! -f "$STATE_JSON" ]]; then
  cat > "$STATE_JSON" << 'EOF'
{
  "slug": null,
  "mode": "clarify",
  "approval_status": "pending",
  "active_contract": null,
  "artifacts": [],
  "approvals": { "contract": false, "evals": false },
  "gates": {
    "clarify_complete": false,
    "research_complete": false,
    "spec_complete": false,
    "contract_approved": false
  }
}
EOF
  echo ""
  echo "Created:  .cortex/state.json"
else
  echo ""
  echo "Skipped:  .cortex/state.json (already exists)"
fi

# ── .cortex/dirty-files.json ──────────────────────────────────────────────────
DIRTY_FILES="$TARGET/.cortex/dirty-files.json"
if [[ ! -f "$DIRTY_FILES" ]]; then
  echo "[]" > "$DIRTY_FILES"
  echo "Created:  .cortex/dirty-files.json"
else
  echo "Skipped:  .cortex/dirty-files.json (already exists)"
fi

# ── .cortex/validator-results.json ───────────────────────────────────────────
VALIDATOR_RESULTS="$TARGET/.cortex/validator-results.json"
if [[ ! -f "$VALIDATOR_RESULTS" ]]; then
  echo "{}" > "$VALIDATOR_RESULTS"
  echo "Created:  .cortex/validator-results.json"
else
  echo "Skipped:  .cortex/validator-results.json (already exists)"
fi

# ── .gitkeep files for empty runtime dirs ─────────────────────────────────────
for runtime_dir in runs tmp compaction; do
  gitkeep="$TARGET/.cortex/$runtime_dir/.gitkeep"
  if [[ ! -f "$gitkeep" ]]; then
    touch "$gitkeep"
    echo "Created:  .cortex/$runtime_dir/.gitkeep"
  else
    echo "Skipped:  .cortex/$runtime_dir/.gitkeep (already exists)"
  fi
done

# ── .cortex/.gitignore ────────────────────────────────────────────────────────
GITIGNORE="$TARGET/.cortex/.gitignore"
if [[ ! -f "$GITIGNORE" ]]; then
  cat > "$GITIGNORE" << 'EOF'
# Scratch runtime directories — ephemeral, not tracked
runs/
tmp/

# Ephemeral state files — regenerated each session
dirty-files.json
validator-results.json

# Keep durable state and compaction history
!state.json
!compaction/
EOF
  echo "Created:  .cortex/.gitignore"
else
  echo "Skipped:  .cortex/.gitignore (already exists)"
fi

# ── summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Cortex runtime scaffold complete at $TARGET"
