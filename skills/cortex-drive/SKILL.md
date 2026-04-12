# Cortex Drive — Autonomous Lifecycle Controller

Drives the Cortex lifecycle spine (clarify → research → spec → bridge → execute → validate → done) autonomously, making adaptive decisions at each transition. Reads state from disk, dispatches skills, respects autonomy gates, stops when mandatory gates or safety conditions require it.

## User-invocable

When the user types `/cortex-drive`, run this skill.

Also trigger when the user says:
- "drive this to completion"
- "run autonomously"
- "auto-build"
- "keep going until done"

## Arguments

- `/cortex-drive` — drive the current active slug to completion
- `/cortex-drive <idea>` — start from scratch: clarify the idea, then drive to completion
- `--autonomy <preset>` — override autonomy preset (supervised/gates-only/full-auto)
- `--to <mode>` — stop after reaching this mode (e.g., `--to spec` stops after spec is written)
- `--dry-run` — show the decision table evaluation without executing

## Instructions

### Phase 1: Initialize

1. Read `.cortex/state.json` to get current slug, mode, gates, and active contract.
2. **Read owner intent:** If `docs/cortex/intent/owner-intent.md` exists, parse frontmatter + sections. Extract: objectives, non-negotiables, tradeoff preferences, kill criteria, current initiatives. If the file doesn't exist, proceed without intent (backward compatible).
3. **Read preferences:** If `docs/cortex/intent/preferences.json` exists, parse and apply staleness model (demote expired preferences by one strength level). If >3 preferences are stale, log warning to `decisions.md`: "N preferences stale — consider running /cortex-intent review." If the file doesn't exist, proceed without preferences.
4. If an `<idea>` argument was provided and no active slug exists, run `/cortex-clarify <idea>` first.
5. If no slug and no idea: check for backlog items in `~/.cortex/stash/` and `docs/cortex/research/autonomous-builder-ideas.md`. If items exist, rank by **alignment to owner objectives** (primary), then leverage, urgency, dependencies. Filter out items that contradict non-negotiables. Present the top 3 with alignment reasoning and ask which to start. If no items: print "Nothing to drive. Provide an idea or populate the stash." and stop.
6. Resolve autonomy config (same as /cortex-spec: 4-layer resolution).
7. Set `RETRY_COUNT = 0`, `ACTIONS_TAKEN = []`.
8. **Retrieve relevant facts:** If `.cortex/facts.jsonl` exists, query for facts matching the current slug. Prioritize `lesson` and `procedure` type facts — these represent prior failures and reusable tactics. If a lesson says "approach X failed on a similar slug," flag it before dispatching actions that might repeat the same approach.

### Phase 2: The Drive Loop

Re-read state from disk at the start of EVERY iteration. Never carry state in memory across iterations.

```
LOOP:
  1. Read .cortex/state.json (fresh)
  2. Evaluate decision table (Phase 3) → next_action
  3. If next_action == "done" → break
  4. If next_action == "stop_human" → present reason, break
  5. If next_action == "stop_safety" → present reason, break
  6. If --to flag set and current mode >= target mode → break
  7. Log decision to decisions.md
  8. Append to ACTIONS_TAKEN
  9. Dispatch action (Phase 4)
  10. RETRY_COUNT = 0 (reset on successful action)
  11. Go to LOOP
```

### Phase 3: Decision Table

Evaluate conditions in this exact order (first match wins):

| # | Condition | Action | Needs LLM? |
|---|-----------|--------|------------|
| 1 | `slug == null` AND backlog has items | Rank backlog, pick top → `/cortex-clarify` | Yes (ranking) |
| 2 | `mode == "clarify"` AND `gates.clarify_complete == true` | `/cortex-research --phase concept` | No |
| 3 | `mode == "research"` AND research dossier exists AND open questions remain that are implementation-specific | `/cortex-research --phase implementation` | Yes (judgment) |
| 4 | `mode == "research"` AND `gates.research_complete == true` | `/cortex-spec` (includes necessity gate) | No |
| 5 | `mode == "spec"` AND `gates.spec_complete == true` AND `approval_status == "approved"` | `/cortex-bridge` | No |
| 6 | `mode == "spec"` AND `approval_status == "pending"` AND `gates.contract_approval == false` | Auto-approve, then `/cortex-bridge` | No |
| 7 | `mode == "spec"` AND `approval_status == "pending"` AND `gates.contract_approval == true` | Stop: "Contract needs human approval" | No |
| 8 | `.planning/STATE.md` exists AND GSD phases incomplete | GSD phase loop: read STATE.md → find first incomplete phase N → `/gsd:plan-phase N` (if no PLAN.md files exist for phase N) → `/gsd:execute-phase N` → re-read STATE.md → repeat until all phases complete | No |
| 9 | GSD execution complete AND active contract has validators | Run validators (external: bash, judgment: cortex-judge) | No |
| 10 | All validators pass AND `gates.pr_opened == false` AND repo has GitHub remote (`gh repo view` succeeds) | `/cortex-ship` (create branch, push, open PR) | No |
| 10b | `gates.pr_opened == true` AND CI checks pending | Poll CI: `gh pr checks {pr_number} --required`. Exit 0=pass, 1=fail, 8=pending. If pending, wait 30s and re-poll (max 15 minutes). | No |
| 10c | `gates.pr_opened == true` AND CI passes | Stop: "PR #{N} ready at {url} — awaiting human merge." | No |
| 10d | `gates.pr_opened == true` AND CI fails | Stop: "CI failed on PR #{N}. Run /cortex-investigate to diagnose." | No |
| 10e | `gates.pr_merged == true` (check via `gh pr view {N} --json state`, state=="MERGED") | Close linked issue (if `github.issue_number` set: `gh issue close {N}`), then `/cortex-close` | No |
| 10f | All validators pass AND repo has NO GitHub remote | `/cortex-close` (skip ship — backward compatible for non-GitHub repos) | No |
| 11 | Validators fail AND repair budget > 0 AND no convergence stall | Create repair contract → re-execute | No |
| 11b | Validators fail AND convergence stall detected | Stop: "Convergence stall — repair loop not converging. Escalating to human." Set `reclarify_required: true`. | No |
| 12 | Validators fail AND repair budget exhausted | Stop: "Repair budget exhausted, escalating to human" | No |
| 13 | `mode == "done"` AND `slug == null` | Done | No |

**For row 8 (GSD phase loop):** Read `.planning/STATE.md` to find the first incomplete phase N (check ROADMAP.md progress table or phase directory for missing VERIFICATION.md). For each incomplete phase: check if `*-PLAN.md` files exist in `.planning/phases/{N}-*/` — if none exist, dispatch Skill(`gsd:plan-phase`, N) first. Then dispatch Skill(`gsd:execute-phase`, N). After execute-phase returns, re-read STATE.md. If gaps found (VERIFICATION.md shows `gaps_found`), dispatch Skill(`gsd:plan-phase`, "{N} --gaps") then re-execute. Stop for human checkpoints (plans with `autonomous: false`). Continue loop until STATE.md shows all phases complete.

**For row 3 (research escalation):** Read the concept research dossier. Check if any open question in the dossier or clarify brief is specifically about implementation details (APIs, data formats, integration points, performance requirements). If yes and no implementation dossier exists, run implementation research. If all questions are resolved, skip to row 4.

**For row 1 (backlog ranking):** Read stash files and ideas doc. Rank by: leverage (compounding value), urgency (is something broken?), dependencies (unblocks other work). Present top pick with reasoning.

**For rows 10-10f (ship + CI + merge):** After validators pass, check if the repo has a GitHub remote (`gh repo view --json name 2>/dev/null`). If yes, dispatch `/cortex-ship` to push and open PR. Then poll CI via `gh pr checks {N} --required` — exit 0=pass, 1=fail, 8=pending. Poll every 30 seconds, timeout after 15 minutes. On CI pass, stop and tell the human to merge. On CI fail, stop and suggest `/cortex-investigate`. After human merges (detected by `gh pr view {N} --json state` returning `"MERGED"`), close any linked issue and run `/cortex-close`. For non-GitHub repos (row 10f), skip ship entirely and close directly.

**For row 11/11b (repair with convergence check):** Before creating a repair contract, check for convergence stall files at `docs/cortex/reviews/{slug}/convergence-stall-*.md`. If any exist, take row 11b (stop + set `reclarify_required: true`). Also read `repair_budget` from `.cortex/state.json` — if 0 or missing, take row 12. To compute budget from contracts: count `docs/cortex/contracts/{slug}/contract-*.md` files, read `max_repair_contracts` from the active contract (default 3), remaining = max - (count - 1).

### Phase 4: Dispatch

Dispatch actions via Skill() call. After each dispatch:
- Re-read `.cortex/state.json` from disk
- Verify the expected state change occurred
- If state didn't change as expected: increment RETRY_COUNT
- If RETRY_COUNT >= 2: stop with "Circuit breaker: same action failed twice consecutively. Escalating."

### Phase 5: Safety Checks (evaluated every iteration)

Before dispatching, check these conditions. If any are true, stop immediately:

| Check | Condition | Action |
|-------|-----------|--------|
| Mandatory gate | Any mandatory gate fires during dispatch | Stop, present gate brief |
| Error compounding | RETRY_COUNT >= 2 | Stop: "Circuit breaker triggered" |
| Context capacity | Context usage > 85% (if detectable) | Stop: "Context checkpoint — save and continue in new session" |
| Budget | If cost tracking available and exceeds threshold | Stop: "Budget threshold reached" |
| Non-negotiable violation | Proposed action would violate an owner non-negotiable from `docs/cortex/intent/owner-intent.md` | Stop: "Action violates non-negotiable: {which one}. Aborting." |
| Kill criteria | Current slug or project matches a kill criterion from owner-intent.md | Stop: "Kill criterion triggered: {which one}. Escalating to human." |
| Review cadence | owner-intent.md review_cadence exceeded by 2x | Warning in decisions.md (non-blocking): "Owner intent review overdue — consider running /cortex-intent review" |

### Phase 6: Completion Summary

**Follow the HITL report template** at `templates/cortex/hitl-report.md`. Read `docs/cortex/display.json` for `report_level` (default: 1).

**Level 1 (owner) example:**

```
## {slug} — {COMPLETE|STOPPED|ERROR}

**What was built:** {One sentence: what the user can do now that they couldn't before.}

**What happened:**
- {2-4 bullets: key outcomes, not step-by-step process}
- {Focus on results: "retrieval works in under 1 second" not "wrote cortex-retrieve.py"}

**Risks:**
- {What's not covered, known limitations}

{If stopped: **Why it stopped:** {plain language reason}}
{If complete: **Status:** Done. Slug archived.}
{If error: **Needs your attention:** {what to do}}
```

**Level 2+ adds:**
```
Actions: {count}
Duration: {elapsed}
Actions taken:
  1. {action} — {outcome}
  2. ...
```

## Decision Logging

Every action logged to `docs/cortex/handoffs/decisions.md` under `## Autonomy Decisions`:

```
- {ISO8601} | drive: {action} | row: {N} | slug: {slug} | mode: {mode} | reasoning: {brief}
```

## Rules

- **Always re-read state from disk.** Never carry state in memory across loop iterations. This is the #1 lesson from gsd:drive and production agent systems.
- **Checkpoint every transition.** Log to decisions.md BEFORE dispatching, not after. If the dispatch crashes, the log shows what was attempted.
- **Circuit breaker on consecutive failures.** Same action failing twice = stop. Don't compound errors.
- **Cortex orchestrates GSD directly.** For row 8, cortex-drive calls `/gsd:plan-phase` and `/gsd:execute-phase` directly — it is the loop controller. No intermediate `/gsd:drive` command needed.
- **The loop is the controller, skills are the workers.** The loop never does work itself — it only reads state and dispatches skills.
- **Respect mandatory gates.** ux_taste_eval, human_action, and reclarify are always HITL stops regardless of autonomy preset.
- **The necessity gate is the "should this exist?" check.** The loop trusts it. If necessity returns REJECT, the loop stops — it doesn't override or retry.
