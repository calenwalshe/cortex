# Design Research: /cortex-ship and PR Workflow

**Slug:** github-platform
**Phase:** design
**Timestamp:** 2026-04-07T04:00:00Z
**Status:** complete

---

## 1. /cortex-ship Command

### What It Does

`/cortex-ship` is the bridge between "validators pass" and "code is on GitHub as a PR." It takes validated local work and produces a reviewable, CI-checked pull request. The full sequence:

1. **Guard checks** — Confirm validators passed, contract exists, no dirty uncommitted changes
2. **Create branch** — `cortex/{slug}` from current HEAD (deterministic naming)
3. **Push** — `git push -u origin cortex/{slug}`
4. **Open PR** — `gh pr create` with structured description generated from Cortex artifacts
5. **Poll CI** — `gh pr checks --watch` with timeout
6. **Mark ready** — If CI passes, remove draft status (if `--draft` was used), log PR URL
7. **Close linked issue** — If `--issue N` was provided and CI passes, comment on the issue with PR link

It does NOT merge. Merge is a human gate (per owner-intent non-negotiable: "No code without contract" + safety-first tradeoff preference).

### Arguments

```
/cortex-ship                        # Ship current active slug
/cortex-ship --slug <slug>          # Ship a specific slug (must have passing validators)
/cortex-ship --draft                # Open as draft PR (default: non-draft)
/cortex-ship --issue <N>            # Link to GitHub issue #N (adds "Closes #N" to PR body)
/cortex-ship --skip-ci              # Skip CI polling (open PR and return immediately)
/cortex-ship --base <branch>        # Target branch (default: main)
/cortex-ship --dry-run              # Show what would happen without executing
```

`--auto-merge` was considered and rejected. Owner intent says "merge requires human approval." If this changes, it can be added later as `--auto-merge` which calls `gh pr merge --auto --squash` after CI passes.

### What It Reads

| Artifact | Purpose |
|----------|---------|
| `.cortex/state.json` | Active slug, mode, gates, validator status |
| `docs/cortex/specs/{slug}/spec.md` | Objective for PR summary |
| `docs/cortex/contracts/{slug}/contract-*.md` | Deliverables for "Changes" section, validators for "Test plan" |
| `docs/cortex/reviews/{slug}/` | Latest review artifact — confirms review happened |
| `docs/cortex/evals/{slug}/eval-plan.md` | Eval dimensions for test plan section |
| Git log | Commit messages on the feature branch for changelog section |
| `docs/cortex/intent/owner-intent.md` | Non-negotiables check (validators must run) |

### What It Writes

| Artifact | Content |
|----------|---------|
| `.cortex/state.json` | Adds `pr_url`, `pr_number`, `ci_status`, sets `mode: "shipping"` |
| `docs/cortex/handoffs/decisions.md` | Ship decision entry under Autonomy Decisions |
| `docs/cortex/ship/{slug}/ship-log.md` | Full ship log: branch, PR URL, CI status, timestamps |

### When It Runs in the Spine

After **assure** (validators pass), before **close**. The spine becomes:

```
clarify → research → spec → [GSD execute] → validate → repair? → assure → SHIP → close
```

Ship is a new phase between assure and close. It is NOT part of close because:
- Close is about archiving artifacts and resetting state
- Ship is about GitHub operations that can fail (CI, network, permissions)
- Separating them means a CI failure doesn't corrupt the close flow
- Ship can be retried without re-running close logic

### Guards (must all pass before any action)

1. `state.json.mode` must be `"assure"` or `"shipping"` (re-entry after partial ship)
2. All validators in the active contract must show `pass`
3. No uncommitted changes in the working tree (`git status --porcelain` is empty)
4. `gh auth status` succeeds (authenticated)
5. Current repo is a GitHub repo (`gh repo view` succeeds)

If any guard fails, print the specific failure and stop. No partial execution.

---

## 2. PR Description Template

### Template Structure

```markdown
## Summary

{spec.objective — 1-2 sentence description of what this change does and why}

## Changes

{For each contract deliverable:}
- **{deliverable.name}** — {deliverable.description}

### Commits

{Formatted list of commits on the feature branch, excluding merge commits}

## Test Plan

### Validators (automated)
{For each validator in the contract:}
- [x] `{validator.command}` — {validator.description} ({pass/fail})

### Eval Dimensions
{For each dimension in eval-plan.md:}
- {dimension.name}: {dimension.rubric_summary} — **{score}/{max}**

### Manual Verification
- [ ] Code review by human reviewer

## Linked Issues

{If --issue N: "Closes #{N}"}
{If no issue: "No linked issue"}

## Cortex Metadata

| Field | Value |
|-------|-------|
| Slug | `{slug}` |
| Contract | `{contract_id}` (e.g., `contract-001`) |
| Spec | `{spec_path}` |
| Validators | {pass_count}/{total_count} passing |
| Eval status | {pass/fail/not-run} |
| Review | {review_path or "not run"} |
| Ship log | `docs/cortex/ship/{slug}/ship-log.md` |
```

### Complete Example (Hypothetical Slug: `add-retry-logic`)

```markdown
## Summary

Add exponential backoff retry logic to the webhook delivery system. Webhooks currently fail permanently on transient errors (timeouts, 502/503 responses), causing data loss for ~3% of deliveries.

## Changes

- **RetryPolicy class** — Configurable retry policy with exponential backoff, jitter, and max-attempts. Supports per-endpoint override.
- **DeliveryQueue integration** — DeliveryQueue now checks retry policy before marking a delivery as permanently failed. Failed deliveries re-enter the queue with incremented attempt count.
- **Dead letter queue** — Deliveries that exhaust all retries move to a dead letter queue instead of being silently dropped. Includes alerting hook.
- **Dashboard metrics** — New retry/DLQ counters exposed via /metrics endpoint.

### Commits

- `a1b2c3d` feat: add RetryPolicy class with exponential backoff
- `e4f5g6h` feat: integrate RetryPolicy into DeliveryQueue
- `i7j8k9l` feat: add dead letter queue for exhausted retries
- `m0n1o2p` feat: expose retry and DLQ metrics on /metrics
- `q3r4s5t` test: add retry policy unit and integration tests
- `u6v7w8x` docs: update webhook configuration guide

## Test Plan

### Validators (automated)
- [x] `pytest test/test_retry_policy.py` — Unit tests for RetryPolicy (pass)
- [x] `pytest test/test_delivery_queue.py` — Integration tests for queue retry flow (pass)
- [x] `bash scripts/validate-metrics.sh` — Verify /metrics endpoint includes new counters (pass)

### Eval Dimensions
- Correctness: Retry behavior matches spec (backoff formula, jitter bounds, max attempts) — **4/5**
- Reliability: No data loss path exists between initial failure and DLQ — **5/5**
- Observability: All retry states are visible in metrics and logs — **4/5**

### Manual Verification
- [ ] Code review by human reviewer

## Linked Issues

Closes #42

## Cortex Metadata

| Field | Value |
|-------|-------|
| Slug | `add-retry-logic` |
| Contract | `contract-001` |
| Spec | `docs/cortex/specs/add-retry-logic/spec.md` |
| Validators | 3/3 passing |
| Eval status | pass (13/15, threshold 12) |
| Review | `docs/cortex/reviews/add-retry-logic/review-20260407.md` |
| Ship log | `docs/cortex/ship/add-retry-logic/ship-log.md` |
```

---

## 3. CI Integration

### Polling Mechanism

```
gh pr checks {pr_number} --watch --interval 30 --fail-fast
```

If `--watch` is not available in the installed `gh` version, fall back to a manual poll loop:

```bash
while true; do
  status=$(gh pr checks $PR_NUMBER --json state --jq '.[].state')
  # All PASS → done
  # Any FAIL → done (failed)
  # Any PENDING → sleep and retry
  sleep 30
done
```

### Timeout

- Default: **15 minutes** (covers most CI pipelines)
- Maximum: **30 minutes** (configurable via `.cortex/config.json` key `ship.ci_timeout_minutes`)
- If timeout is reached: mark CI as `timeout` in ship log, print warning, leave PR open as draft

### CI Failure Handling

| CI Result | Action |
|-----------|--------|
| All checks pass | Log success, mark PR ready for review |
| Flaky failure (test name matches known-flaky list) | Retry once via `gh pr close` + `gh pr reopen` to retrigger CI. If fails again, treat as real failure. |
| Real failure | Log failure details to ship log. Set `state.json.ci_status = "failed"`. Print: "CI failed. Run `/cortex-investigate` to diagnose, then `/cortex-ship` to retry." Do NOT auto-loop into repair. |
| No CI configured | Skip CI polling entirely. Log "No CI checks detected — proceeding without CI gate." Mark PR ready. |
| Timeout | Log timeout. Leave PR as draft. Print: "CI timed out after {N} minutes. Check manually: {pr_url}" |

### Why No Auto-Repair on CI Failure

CI failure after validators pass means either: (a) the validators are incomplete (eval problem), or (b) the CI environment differs from local (environment problem). Neither is a simple code fix. Auto-looping into repair would likely compound errors. The correct action is investigation, which may reveal the fix is trivial or may reveal a deeper issue.

If the owner later wants auto-repair on CI failure, it can be added as a cortex-drive row. But the default is: stop and escalate.

### CI Pass Actions

1. If PR was opened as draft: `gh pr ready {pr_number}` to mark ready for review
2. Update ship log with CI pass timestamp
3. Update `state.json.ci_status = "passed"`
4. Print PR URL and summary
5. Do NOT auto-request reviewers (the owner decides who reviews)
6. Do NOT auto-merge (human gate)

---

## 4. cortex-drive Integration

### Modified Decision Table

The current table goes: row 10 (validators pass → close), rows 11-12 (validator failure → repair/escalate), row 13 (done). Ship inserts between validators-pass and close.

New rows (replacing current row 10, shifting close to row 14):

| # | Condition | Action | Needs LLM? |
|---|-----------|--------|------------|
| 10 | All validators pass AND repo is a GitHub repo AND `ci_status != "passed"` | `/cortex-ship` | No |
| 11 | `mode == "shipping"` AND `ci_status == "passed"` | `/cortex-close` | No |
| 12 | `mode == "shipping"` AND `ci_status == "failed"` AND repair budget > 0 | `/cortex-investigate` → repair contract → re-execute → `/cortex-ship` (retry) | Yes (investigation) |
| 12b | `mode == "shipping"` AND `ci_status == "failed"` AND repair budget exhausted | Stop: "CI failure, repair budget exhausted. Manual intervention needed. PR: {url}" | No |
| 12c | `mode == "shipping"` AND `ci_status == "timeout"` | Stop: "CI timed out. Check manually: {pr_url}" | No |
| 13 | Validators fail AND repair budget > 0 AND no convergence stall | Create repair contract → re-execute | No |
| 13b | Validators fail AND convergence stall detected | Stop: "Convergence stall — escalating to human." Set `reclarify_required: true`. | No |
| 14 | Validators fail AND repair budget exhausted | Stop: "Repair budget exhausted, escalating to human" | No |
| 15 | `mode == "done"` AND `slug == null` | Done | No |

### Key Design Decisions

**Should drive auto-ship on validators pass?** Yes, if the repo is a GitHub repo. The condition `repo is a GitHub repo` is checked via `gh repo view --json name 2>/dev/null`. If it fails (not a GitHub repo, no auth), skip ship and go straight to close. This preserves backward compatibility for non-GitHub workflows.

**Should drive auto-ship require human trigger?** No. The human gate is at merge, not at PR creation. Opening a PR is a safe, reversible action. The owner can close or edit the PR. The point of cortex-drive is autonomous operation through to the last safe step.

**How does drive handle CI failure?** It treats CI failure as a new signal, not a validator failure. CI failure goes through investigation (row 12), which may produce a repair contract. The repair contract re-executes, re-validates, and re-ships. This is a separate loop from the validator repair loop (rows 13-14). CI repair gets its own budget counter (`ci_repair_count` in state.json, max 1 by default). One retry is enough — if CI fails twice after investigation, it's a deeper problem.

**What about repos with no CI?** Row 10 fires `/cortex-ship`. Ship detects no CI checks, skips polling, marks PR ready. Row 11 fires (`ci_status` gets set to `"passed"` when no CI exists — there's nothing to fail). Close proceeds normally.

### New state.json Fields

```json
{
  "pr_url": "https://github.com/owner/repo/pull/42",
  "pr_number": 42,
  "ci_status": "pending|passed|failed|timeout|skipped",
  "ci_repair_count": 0,
  "ship_branch": "cortex/add-retry-logic"
}
```

These fields are set by `/cortex-ship` and read by cortex-drive rows 10-12c.

---

## 5. The Ship Lifecycle

### Complete Flow

```
validators pass
  │
  ▼
[Guard checks] ─── fail ──→ STOP: print specific guard failure
  │ pass
  ▼
[Create branch: cortex/{slug}]
  │
  ▼
[git push -u origin cortex/{slug}] ─── fail ──→ STOP: "Push failed: {error}"
  │                                              (likely: no push access, branch exists)
  ▼
[gh pr create --base main --head cortex/{slug}] ─── fail ──→ STOP: "PR creation failed: {error}"
  │                                                          (likely: branch already has PR)
  ▼
[Poll CI: gh pr checks] ─── timeout ──→ STOP: "CI timeout. Check: {url}"
  │                      ─── fail ────→ STOP: "CI failed. Run /cortex-investigate"
  │ pass (or no CI)
  ▼
[Mark PR ready (if was draft)]
  │
  ▼
[Log: ship-log.md, state.json, decisions.md]
  │
  ▼
[Print summary: PR URL, CI status, next action]
  │
  ▼
[Human reviews and merges PR]
  │
  ▼
[/cortex-close: archive slug, reset state]
```

### Failure Modes and Fallbacks

| Step | What Can Go Wrong | Detection | Fallback |
|------|-------------------|-----------|----------|
| Guard checks | Validators didn't pass | `state.json` gates check | Print which validators failed, stop |
| Guard checks | Uncommitted changes | `git status --porcelain` | Print dirty files, stop. User must commit or stash. |
| Guard checks | Not authenticated | `gh auth status` exit code | Print "Run `gh auth login`", stop |
| Create branch | Branch already exists | `git checkout -b` exit code | Check if branch has the right commits. If yes, skip (re-entry). If no, stop: "Branch `cortex/{slug}` exists with different content." |
| Push | No push access | `git push` exit code | Print error, suggest checking repo permissions |
| Push | Remote branch exists with divergent history | `git push` rejection | `git push --force-with-lease` if and only if the branch was created by a previous cortex-ship run for the same slug (check via ship-log.md). Otherwise stop. |
| Open PR | PR already exists for this branch | `gh pr create` exit code | Detect existing PR via `gh pr list --head cortex/{slug}`. If found, reuse it: update description via `gh pr edit`. Log "Reusing existing PR #{N}." |
| Poll CI | Network timeout during polling | HTTP error from gh | Retry poll (not the whole flow). 3 consecutive poll failures = stop with timeout. |
| Poll CI | CI check is stuck (pending for >timeout) | Timeout | Stop, log, leave PR open |
| Mark ready | PR was already ready | `gh pr ready` on non-draft | No-op, harmless |
| Human merge | Human rejects PR with comments | Not detected by cortex-ship | Future: cortex-drive could poll `gh pr view` for review status and ingest comments. Out of scope for v1. |

### Re-Entry (Idempotency)

`/cortex-ship` must be safely re-runnable. If called again after a partial run:

1. If branch exists and has the right commits → skip branch creation
2. If branch is pushed → skip push
3. If PR exists for this branch → reuse PR, update description
4. If CI already passed → skip polling
5. If everything is done → print "Already shipped: {pr_url}" and stop

The ship-log.md tracks which steps completed. On re-entry, cortex-ship reads the log and skips completed steps.

### Ship Log Format

Written to `docs/cortex/ship/{slug}/ship-log.md`:

```markdown
# Ship Log: {slug}

| Step | Status | Timestamp | Detail |
|------|--------|-----------|--------|
| guard | pass | 2026-04-07T04:15:00Z | All guards passed |
| branch | created | 2026-04-07T04:15:01Z | cortex/{slug} |
| push | done | 2026-04-07T04:15:05Z | origin/cortex/{slug} |
| pr | opened | 2026-04-07T04:15:08Z | #42 — https://github.com/owner/repo/pull/42 |
| ci | passed | 2026-04-07T04:20:30Z | 3/3 checks passed (5m 22s) |
| ready | done | 2026-04-07T04:20:31Z | Draft → Ready for review |
```

---

## 6. Open Design Questions (Resolved)

### Q: Branch at execution start or at ship time?

**Answer: At ship time.** Creating the branch at execution start would require GSD to know about feature branches, violating the ownership boundary (GSD owns execution, Cortex owns intelligence). Shipping from whatever branch GSD left the repo on keeps the boundary clean. Cortex-ship creates the branch, cherry-picks or rebases if needed.

In practice, most slugs execute on main (or whatever the default branch is). Cortex-ship creates `cortex/{slug}` from HEAD, which contains all the committed work.

**Edge case:** If the repo's main branch is protected (no direct pushes), GSD execution must already be happening on a feature branch. Cortex-ship detects this: if the current branch is not `main` and is not `cortex/{slug}`, it uses the current branch as-is rather than creating a new one.

### Q: What if the slug spans multiple commits across sessions?

Ship collects all commits that differ from the base branch: `git log main..HEAD --oneline`. The PR description includes all of them. This works regardless of how many sessions the execution took.

### Q: Should cortex-close know about GitHub?

**Answer: No.** Close stays pure (archive + reset). If an issue needs closing on GitHub, cortex-ship handles it by adding "Closes #N" to the PR body — GitHub closes the issue automatically when the PR merges. This keeps close independent of GitHub.

### Q: Where does review-comment ingestion go?

**Answer: v2.** For v1, cortex-ship opens the PR and stops. The human reviews and merges. In v2, cortex-drive could add a row: `mode == "shipping" AND PR has review comments → /cortex-investigate with comments as input → repair → re-push → re-check`. This is powerful but complex — defer it.

---

## 7. Implementation Sequence

If this design moves to spec:

1. **Ship log infrastructure** — `docs/cortex/ship/{slug}/ship-log.md` write/read utilities
2. **PR description generator** — Reads spec, contract, review, eval-plan, git log. Outputs markdown.
3. **Guard checks** — Validators pass, clean tree, gh auth, GitHub repo detection
4. **Branch + push** — Create `cortex/{slug}`, push with idempotent re-entry
5. **PR creation** — `gh pr create` with generated description, idempotent (reuse existing)
6. **CI polling** — `gh pr checks` with timeout, failure classification
7. **State updates** — Write pr_url, ci_status to state.json
8. **cortex-drive rows** — Insert rows 10-12c, shift existing rows
9. **Tests** — Validator guards, PR description generation, idempotent re-entry, CI timeout handling

---

## 8. Evidence That Would Change This Design

- If `gh pr checks --watch` is unreliable or unavailable in gh v2.67, the polling mechanism needs to be a manual loop from the start.
- If owner decides merge should be automated for low-risk slugs, add `--auto-merge` flag and a new cortex-drive condition checking slug complexity.
- If CI repair loops prove effective (>50% auto-fix rate), increase the default `ci_repair_count` max from 1 to 2.
- If branch naming collisions occur frequently (multiple slugs with same name across repos), add repo-scoped prefix to branch names.
