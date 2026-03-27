#!/usr/bin/env bash
set -euo pipefail

# Cortex Upstream Sync
# Updates submodules and flags what changed vs what Cortex extracted.

CORTEX_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$CORTEX_ROOT"

echo "========================================="
echo "  Cortex Upstream Sync"
echo "========================================="
echo ""

# --- Superpowers ---
echo "--- Superpowers ---"
OLD_SP=$(cd upstream/superpowers && git rev-parse --short HEAD)
git submodule update --remote upstream/superpowers 2>/dev/null || echo "  (no remote changes)"
NEW_SP=$(cd upstream/superpowers && git rev-parse --short HEAD)

if [ "$OLD_SP" != "$NEW_SP" ]; then
    echo "  UPDATED: $OLD_SP → $NEW_SP"
    echo "  Changed files affecting Cortex extracts:"
    cd upstream/superpowers
    git diff --name-only "$OLD_SP" "$NEW_SP" -- \
        skills/test-driven-development/ \
        skills/systematic-debugging/ \
        skills/receiving-code-review/ \
        skills/brainstorming/ \
        agents/ \
        2>/dev/null | sed 's/^/    /'
    cd "$CORTEX_ROOT"
    echo ""
    echo "  Review: Compare upstream changes against:"
    echo "    layers/discipline/tdd.md"
    echo "    layers/discipline/debugging.md"
    echo "    layers/discipline/code-review.md"
else
    echo "  No changes ($OLD_SP)"
fi
echo ""

# --- GStack ---
echo "--- GStack ---"
OLD_GS=$(cd upstream/gstack && git rev-parse --short HEAD)
git submodule update --remote upstream/gstack 2>/dev/null || echo "  (no remote changes)"
NEW_GS=$(cd upstream/gstack && git rev-parse --short HEAD)

if [ "$OLD_GS" != "$NEW_GS" ]; then
    echo "  UPDATED: $OLD_GS → $NEW_GS"
    echo "  Changed files affecting Cortex extracts:"
    cd upstream/gstack
    git diff --name-only "$OLD_GS" "$NEW_GS" -- \
        office-hours/ \
        investigate/ \
        cso/ \
        2>/dev/null | sed 's/^/    /'
    cd "$CORTEX_ROOT"
    echo ""
    echo "  Review: Compare upstream changes against:"
    echo "    layers/thinking/anti-sycophancy.md"
    echo "    layers/thinking/forcing-questions.md"
    echo "    layers/thinking/investigate.md"
    echo "    layers/thinking/security-audit.md"
else
    echo "  No changes ($OLD_GS)"
fi
echo ""

# --- GSD ---
echo "--- GSD ---"
if [ -d "$HOME/projects/get-shit-done" ]; then
    echo "  Local GSD found at ~/projects/get-shit-done"
    echo "  To sync: cp -r ~/projects/get-shit-done/* upstream/gsd/"
    echo "  (Manual — GSD is a local copy, not a submodule)"
else
    echo "  GSD not found locally. Skipping."
fi
echo ""

# --- Summary ---
echo "========================================="
echo "  Sync Complete"
echo "========================================="
echo ""
echo "  Superpowers: $NEW_SP"
echo "  GStack:      $NEW_GS"
echo "  GSD:         local copy (manual sync)"
echo ""
echo "  If upstream changes affect extracts, re-read the"
echo "  source files and update the corresponding layer files."
echo "  See upstream/UPSTREAM.md for the extraction mapping."
