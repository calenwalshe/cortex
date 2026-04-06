# Research Dossier: github-platform — synthesis

**Slug:** github-platform
**Phase:** concept (synthesis)
**Timestamp:** 20260407T040000Z
**Depth:** standard (3 parallel research agents)

---

## Executive Summary

GSD already has `/gsd:ship` (full PR pipeline with rich descriptions) and `/gsd:pr-branch` (cherry-pick filtering of .planning/ commits). The `gh` CLI is installed and authenticated. The gap is not "build GitHub integration" — it's "wire existing GSD shipping into the cortex-drive autonomous loop."

The implementation is: a thin `/cortex-ship` skill (guards + branch + delegates to /gsd:ship + writes state), 5 new rows in cortex-drive's decision table (rows 10-10e), branch creation at bridge time, and state.json schema additions for PR tracking.

---

## Finding 1: GSD Already Handles PR Creation

| Component | Status | What it does |
|-----------|--------|-------------|
| `/gsd:ship` | **Exists** | Preflight checks → push → generate PR body from SUMMARY/VERIFICATION/ROADMAP → `gh pr create` → update STATE.md |
| `/gsd:pr-branch` | **Exists** | Creates clean PR branch, cherry-picks only code commits, filters .planning/ |
| `gh` CLI v2.67 | **Installed + authenticated** | Full GitHub operations via GH_TOKEN |

The `/gsd:ship` PR body is already high-quality — includes summary, changes per plan, requirements addressed, verification status, key decisions. No need to design a PR template from scratch.

### What cortex-ship adds on top

`/cortex-ship` is a thin wrapper that:
1. Verifies guards (validators pass, clean tree, gh auth, GitHub remote exists)
2. Creates `cortex/{slug}` branch if not already on one
3. Calls `/gsd:pr-branch` if needed (filters .planning/ commits)
4. Delegates to `/gsd:ship` for actual PR creation
5. Writes `pr_number`, `pr_url`, `branch` back to `.cortex/state.json`
6. Logs the ship decision to `decisions.md`

---

## Finding 2: Drive Decision Table Changes

### Current rows 9-13
```
9:  GSD complete + validators → run validators
10: validators pass → /cortex-close
11: validators fail + budget → repair
11b: convergence stall → stop
12: budget exhausted → stop
13: mode=done + null slug → done
```

### New rows 10-10e (insert between validators pass and close)

| Row | Condition | Action |
|-----|-----------|--------|
| 10 | All validators pass AND `gates.pr_opened == false` AND repo has GitHub remote | `/cortex-ship` (create branch, push, open PR) |
| 10b | `gates.pr_opened == true` AND CI checks pending | Poll CI via `gh pr checks {N} --required` (exit 0=pass, 1=fail, 8=pending) |
| 10c | `gates.pr_opened == true` AND CI passes | Stop: "PR #{N} ready — awaiting human merge at {url}" |
| 10d | `gates.pr_opened == true` AND CI fails | Stop: "CI failed on PR #{N}. Run /cortex-investigate." |
| 10e | `gates.pr_merged == true` | Close linked issue (if any), run `/cortex-close` |
| 10f | All validators pass AND repo has NO GitHub remote | `/cortex-close` (skip ship — backward compatible) |

### Key design decisions

- **Row 10c is a mandatory HITL gate.** Cortex never auto-merges. Human merges the PR.
- **Row 10d does NOT auto-loop into repair.** CI failure after local validators pass indicates environment mismatch or incomplete validators — not something auto-repair handles well. Human investigates.
- **Row 10f preserves backward compatibility.** Non-GitHub repos skip ship entirely.
- **Row 10e detects merge** by polling `gh pr view {N} --json state` and checking `state: "MERGED"`.

---

## Finding 3: Branch Strategy

**Create branch at bridge time, push at ship time.**

| Phase | Action |
|-------|--------|
| `/cortex-bridge` | Create `cortex/{slug}` branch, switch to it before generating .planning/ |
| GSD execution | All commits land on `cortex/{slug}` branch |
| `/cortex-ship` | `/gsd:pr-branch` filters .planning/ commits → push → `gh pr create` against main |

**Naming convention:** `cortex/{slug}` — clearly identifies Cortex-managed branches.

**Fallback:** If work happened on main by mistake (bridge didn't create branch), `/gsd:pr-branch` handles it via cherry-pick filtering.

---

## Finding 4: gh CLI Capabilities

| Operation | Command | Exit codes |
|-----------|---------|-----------|
| Create PR | `gh pr create --title T --body B --base main --head cortex/{slug}` | 0=created |
| Poll CI | `gh pr checks {N} --required` | 0=pass, 1=fail, 8=pending |
| View PR | `gh pr view {N} --json state,url,mergeable` | state: OPEN/CLOSED/MERGED |
| Close issue | `gh issue close {N} --comment "Closed by cortex/{slug}"` | 0=closed |
| Check remote | `gh repo view --json name 2>/dev/null` | 0=GitHub repo |

CI polling: 15-minute default timeout (configurable). Check every 30 seconds. `gh pr checks --required` returns exit 8 while pending — the loop sleeps and retries.

---

## Finding 5: State Schema Additions

```json
{
  "github": {
    "pr_number": null,
    "pr_url": null,
    "issue_number": null,
    "branch": "cortex/{slug}"
  },
  "gates": {
    "pr_opened": false,
    "pr_merged": false
  }
}
```

---

## Revised Task Map

### Must-Do

| # | Task | Files | Effort |
|---|------|-------|--------|
| 1 | Create `/cortex-ship` SKILL.md (thin wrapper: guards → branch → /gsd:pr-branch → /gsd:ship → state update) | `skills/cortex-ship/SKILL.md` | Medium |
| 2 | Add drive rows 10-10f (ship → CI poll → merge gate → close) | `skills/cortex-drive/SKILL.md` | Small |
| 3 | Add branch creation to cortex-bridge | `skills/cortex-bridge/SKILL.md` | Small |
| 4 | Add `github` object + `pr_opened`/`pr_merged` gates to state.json handling | `skills/cortex-clarify/SKILL.md` (init), all state-writing skills | Small |
| 5 | Add issue close to cortex-close | `skills/cortex-close/SKILL.md` | Tiny |
| 6 | Register cortex-ship in manifest + COMMANDS.md | `runtime-manifest.json`, `docs/COMMANDS.md` | Small |

### Should-Do

| # | Task | Effort |
|---|------|--------|
| 7 | Add `/cortex-ship` to CORTEX.md command surface docs | Small |
| 8 | Add ship-log.md for idempotent re-entry (track which steps completed) | Small |
| 9 | Support `--issue N` flag on cortex-ship to link PR to issue | Tiny |

### Defer

| # | Task | Reason |
|---|------|--------|
| 10 | Auto-merge on CI pass | Owner intent says merge is human-gated |
| 11 | CI failure → auto-repair loop | CI failure after local validators pass indicates environment mismatch, not code bug |
| 12 | GitHub issue ingestion into backlog ranking (drive row 1) | Nice-to-have, stash as separate slug |
| 13 | PR review comment ingestion | Complex — separate slug |

---

## Open Questions Resolved

> "Where in cortex-drive does GitHub integration go?"
**Answer:** New rows 10-10f between validators pass and close. Ship is a new phase between assure and close.

> "Should Cortex create the branch at execution start or PR time?"
**Answer:** At bridge time. `/cortex-bridge` creates `cortex/{slug}`, all GSD execution happens on that branch.

> "How does PR description get generated?"
**Answer:** Delegated to `/gsd:ship` which already generates rich PR bodies from GSD artifacts (SUMMARY.md, VERIFICATION.md, ROADMAP.md).

> "Should cortex-drive read GitHub issues at row 1?"
**Answer:** Defer. Stash as a separate slug. Stash + ideas doc is sufficient for now.

> "Should CI failure trigger a repair loop?"
**Answer:** No. CI failure after local validators pass indicates environment mismatch. Human investigates.

> "What's the right timeout for CI polling?"
**Answer:** 15 minutes default, configurable to 30 max. Poll every 30 seconds.

> "Should PR review comments be ingested?"
**Answer:** Defer. Complex integration, separate slug.

---

## Sources

### Internal
- `skills/cortex-drive/SKILL.md` — decision table rows 9-13
- `skills/cortex-bridge/SKILL.md` — scaffold generation, branch creation point
- `skills/cortex-close/SKILL.md` — archive + reset
- `~/.claude/get-shit-done/workflows/ship.md` — /gsd:ship (PR creation with rich body)
- `~/.claude/get-shit-done/workflows/pr-branch.md` — /gsd:pr-branch (commit filtering)
- `gh` CLI v2.67 — installed, authenticated (calenwalshe, GH_TOKEN)

### Design
- `docs/cortex/research/github-platform/design-research-20260407.md` — full /cortex-ship command design, PR template, CI integration
