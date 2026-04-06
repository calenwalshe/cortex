#!/usr/bin/env bash
# check-doc-drift.sh — 5-way consistency check for Cortex documentation
#
# Compares: skill dirs ↔ manifest ↔ registry ↔ COMMANDS.md ↔ hardcoded counts
# Exit 0 = clean, Exit 1 = drift detected
#
# Usage: scripts/cortex/check-doc-drift.sh

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
REGISTRY="$REPO_ROOT/command-registry.json"
MANIFEST="$REPO_ROOT/runtime-manifest.json"
COMMANDS_MD="$REPO_ROOT/docs/COMMANDS.md"
CORTEX_MD="$REPO_ROOT/CORTEX.md"
README_MD="$REPO_ROOT/README.md"

errors=()
warnings=()

# ── Check 0: Required files exist ────────────────────────────────────────────

for f in "$REGISTRY" "$MANIFEST" "$COMMANDS_MD" "$CORTEX_MD" "$README_MD"; do
  if [[ ! -f "$f" ]]; then
    echo "MISSING: $(basename "$f")"
    exit 1
  fi
done

# ── Check 1: Skill dirs vs manifest ─────────────────────────────────────────

disk_skills=$(ls -d "$REPO_ROOT/skills/cortex-"* 2>/dev/null | xargs -n1 basename | sort)
manifest_skills=$(node -e "
  const d=JSON.parse(require('fs').readFileSync('$MANIFEST','utf8'));
  d.skills.filter(s=>s.name.startsWith('cortex-')).map(s=>s.name).sort().forEach(n=>console.log(n));
" 2>/dev/null)

disk_only=$(comm -23 <(echo "$disk_skills") <(echo "$manifest_skills") 2>/dev/null || true)
manifest_only=$(comm -13 <(echo "$disk_skills") <(echo "$manifest_skills") 2>/dev/null || true)

for s in $disk_only; do
  [[ -n "$s" ]] && errors+=("skill dir '$s' exists on disk but not in manifest")
done
for s in $manifest_only; do
  [[ -n "$s" ]] && errors+=("skill '$s' in manifest but no skills/$s/ directory")
done

# ── Check 2: Manifest vs registry ───────────────────────────────────────────

registry_names=$(node -e "
  const d=JSON.parse(require('fs').readFileSync('$REGISTRY','utf8'));
  d.commands.map(c=>c.name).sort().forEach(n=>console.log(n));
" 2>/dev/null)

manifest_not_registry=$(comm -23 <(echo "$manifest_skills") <(echo "$registry_names") 2>/dev/null || true)
registry_not_manifest=$(comm -13 <(echo "$manifest_skills") <(echo "$registry_names") 2>/dev/null || true)

for s in $manifest_not_registry; do
  [[ -n "$s" ]] && errors+=("skill '$s' in manifest but not in command-registry.json")
done
for s in $registry_not_manifest; do
  [[ -n "$s" ]] && errors+=("command '$s' in registry but not in manifest")
done

# ── Check 3: Registry vs COMMANDS.md sections ───────────────────────────────

docs_commands=$(grep -E '^## /cortex-' "$COMMANDS_MD" 2>/dev/null | sed 's/^## \///' | sort)

for cmd in $registry_names; do
  if ! echo "$docs_commands" | grep -qx "$cmd" 2>/dev/null; then
    errors+=("command '$cmd' in registry but missing from COMMANDS.md")
  fi
done
for cmd in $docs_commands; do
  if ! echo "$registry_names" | grep -qx "$cmd" 2>/dev/null; then
    errors+=("section '/$cmd' in COMMANDS.md but not in registry")
  fi
done

# ── Check 4: Count consistency ───────────────────────────────────────────────

registry_count=$(node -e "
  const d=JSON.parse(require('fs').readFileSync('$REGISTRY','utf8'));
  console.log(d.commands.length);
" 2>/dev/null)

cortex_count=$(grep -oP '\d+(?=-Command Surface)' "$CORTEX_MD" 2>/dev/null | head -1)
if [[ -n "$cortex_count" && "$registry_count" != "$cortex_count" ]]; then
  errors+=("registry has $registry_count commands but CORTEX.md says ${cortex_count}-Command Surface")
fi

readme_count=$(grep -oP 'adds \K\d+(?= commands)' "$README_MD" 2>/dev/null | head -1)
if [[ -n "$readme_count" && "$registry_count" != "$readme_count" ]]; then
  errors+=("registry has $registry_count commands but README.md says $readme_count commands")
fi

# ── Check 5: Registry skill_dir vs SKILL.md existence ───────────────────────

node -e "
  const d=JSON.parse(require('fs').readFileSync('$REGISTRY','utf8'));
  d.commands.forEach(c => {
    if (c.skill_dir) console.log(c.skill_dir);
  });
" 2>/dev/null | while read -r entry; do
  if [[ ! -f "$REPO_ROOT/$entry/SKILL.md" ]]; then
    errors+=("registry entry '$entry/SKILL.md' does not exist on disk")
  fi
done

# ── Report ───────────────────────────────────────────────────────────────────

if [[ ${#warnings[@]} -gt 0 ]]; then
  echo "WARNINGS:"
  for w in "${warnings[@]}"; do echo "  ⚠ $w"; done
fi

if [[ ${#errors[@]} -gt 0 ]]; then
  echo "DOC DRIFT DETECTED (${#errors[@]} issues):"
  for e in "${errors[@]}"; do echo "  ✗ $e"; done
  exit 1
else
  echo "DOC DRIFT CHECK: CLEAN ($registry_count commands verified across 5 checks)"
  exit 0
fi
