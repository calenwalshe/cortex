# Cortex Parallel — Worktree-Isolated Parallel Builds

Creates an isolated worktree for a slug so multiple /cortex-drive loops can run concurrently on different slugs without conflict. Each worktree gets its own .cortex/state.json, its own .planning/, and its own git branch.

## User-invocable

When the user types `/cortex-parallel`, run this skill.

Also trigger when the user says:
- "run this in parallel"
- "start a parallel build"
- "build this concurrently"
- "new worktree for"

## Arguments

- `/cortex-parallel <slug> <idea>` — create worktree and initialize for a new slug
- `/cortex-parallel list` — list active parallel worktrees
- `/cortex-parallel merge <slug>` — guide merge-back from worktree to main
- `/cortex-parallel clean <slug>` — remove a completed worktree

## Instructions

### Command: create (default)

`/cortex-parallel <slug> <idea>`

**Step 1: Validate**

1. Check that `<slug>` is provided. If not, error: "Usage: /cortex-parallel <slug> <idea>"
2. Check that the current directory is a git repo: `git rev-parse --is-inside-work-tree`
3. Check that no worktree already exists for this slug:
   ```bash
   git worktree list | grep "workspace/${slug}"
   ```
   If found, error: "Worktree already exists for slug '{slug}'. Use /cortex-parallel clean {slug} to remove it first."

**Step 2: Create worktree**

```bash
WORKTREE_DIR=".claude/worktrees/${slug}"
BRANCH="workspace/${slug}"
mkdir -p .claude/worktrees
git worktree add "${WORKTREE_DIR}" -b "${BRANCH}" 2>&1
```

If branch already exists (e.g., from a prior attempt), use timestamped branch:
```bash
BRANCH="workspace/${slug}-$(date +%Y%m%d%H%M%S)"
git worktree add "${WORKTREE_DIR}" -b "${BRANCH}" 2>&1
```

**Step 3: Initialize Cortex state in worktree**

```bash
# Create .cortex directory
mkdir -p "${WORKTREE_DIR}/.cortex"

# Initialize state.json for this slug
cat > "${WORKTREE_DIR}/.cortex/state.json" << EOF
{
  "slug": "${slug}",
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

# Copy handoff templates if they exist
mkdir -p "${WORKTREE_DIR}/docs/cortex/handoffs"
cat > "${WORKTREE_DIR}/docs/cortex/handoffs/current-state.md" << EOF
# Current State

**slug:** ${slug}

**mode:** (not started)

**approval_status:** (not started)

**active_contract_path:** (none)

**recent_artifacts:**
- (none)

**open_questions:**
- (none)

**blockers:**
- (none)

**next_action:** Run /cortex-drive "${idea}" to begin
EOF
```

**Step 4: Verify hooks will work**

Check that `.claude/hooks/` exists in the worktree (it should, since it's part of the tracked repo). If hooks are symlinked to global `~/.claude/hooks/`, they work automatically.

```bash
ls "${WORKTREE_DIR}/.claude/hooks/" >/dev/null 2>&1 && echo "Hooks: OK" || echo "Hooks: will use global ~/.claude/hooks/"
```

**Step 5: Output instructions**

```
═══════════════════════════════════════
CORTEX PARALLEL — WORKTREE CREATED
═══════════════════════════════════════
Slug:      {slug}
Worktree:  {WORKTREE_DIR}
Branch:    {BRANCH}
State:     {WORKTREE_DIR}/.cortex/state.json

To start the parallel build:
  1. Open a new terminal
  2. cd {absolute_path_to_worktree}
  3. claude
  4. /cortex-drive "{idea}"

The build runs independently. When done:
  /cortex-parallel merge {slug}
═══════════════════════════════════════
```

### Command: list

`/cortex-parallel list`

```bash
echo "Active parallel worktrees:"
git worktree list | grep "workspace/" | while read path hash branch; do
    slug=$(echo "$branch" | sed 's/.*workspace\///' | sed 's/].*//')
    state_file="${path}/.cortex/state.json"
    if [ -f "$state_file" ]; then
        mode=$(jq -r '.mode // "unknown"' "$state_file" 2>/dev/null)
        echo "  ${slug}: ${mode} (${path})"
    else
        echo "  ${slug}: no state (${path})"
    fi
done
```

If no worktrees found with workspace/ branches, print: "No active parallel worktrees."

### Command: merge

`/cortex-parallel merge <slug>`

**Step 1:** Find the worktree and its branch:
```bash
WORKTREE_DIR=".claude/worktrees/${slug}"
BRANCH=$(cd "${WORKTREE_DIR}" && git branch --show-current)
```

**Step 2:** Check if the build is complete:
```bash
STATE=$(jq -r '.mode' "${WORKTREE_DIR}/.cortex/state.json" 2>/dev/null)
```
If mode is not "done": warn "Build is still in progress (mode: ${STATE}). Merge anyway?"

**Step 3:** Guide the merge:
```
Merge steps for slug '{slug}':

  1. Commit any remaining changes in the worktree:
     cd {WORKTREE_DIR} && git add -A && git commit -m "feat({slug}): final state"

  2. Create PR from {BRANCH} to main:
     gh pr create --base main --head {BRANCH} --title "feat({slug}): {title}"

  3. After PR is merged, clean up:
     /cortex-parallel clean {slug}
```

### Command: clean

`/cortex-parallel clean <slug>`

```bash
WORKTREE_DIR=".claude/worktrees/${slug}"

# Check if worktree exists
if [ ! -d "${WORKTREE_DIR}" ]; then
    echo "No worktree found for slug '${slug}'."
    exit 0
fi

# Check for uncommitted changes
DIRTY=$(cd "${WORKTREE_DIR}" && git status --porcelain 2>/dev/null)
if [ -n "$DIRTY" ]; then
    echo "WARNING: Worktree has uncommitted changes:"
    echo "$DIRTY"
    # Ask for confirmation before deleting
fi

# Remove worktree
git worktree remove "${WORKTREE_DIR}" --force 2>&1

# Delete branch if merged
BRANCH="workspace/${slug}"
MERGED=$(git branch --merged main | grep "${BRANCH}")
if [ -n "$MERGED" ]; then
    git branch -d "${BRANCH}" 2>&1
    echo "Branch ${BRANCH} deleted (already merged to main)."
else
    echo "Branch ${BRANCH} kept (not yet merged to main)."
fi

echo "Worktree cleaned: ${slug}"
```

## Rules

- **One worktree per slug.** Never create two worktrees for the same slug.
- **No coordination between worktrees.** Each parallel build is fully independent. Don't try to share state.
- **Human merges.** When a parallel build completes, the human reviews and merges the PR. No auto-merge.
- **Hooks are shared.** Global hooks (~/.claude/hooks/) fire in all worktrees. Per-project hooks (.claude/hooks/) are part of the tracked repo and exist in worktrees.
- **.cortex/ is per-worktree.** Since .cortex/ is gitignored, each worktree has its own state. This is automatic — no special handling needed.
- **Clean up after merge.** Use `/cortex-parallel clean <slug>` to remove worktrees after PRs are merged.
