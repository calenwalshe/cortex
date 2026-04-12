# Contract: clarify-research-loop — execute

**ID:** clarify-research-loop-001
**Slug:** clarify-research-loop
**Phase:** execute
**Created:** 20260412T013145Z
**Status:** approved
**Repair Budget:** max_repair_contracts: 3, cooldown_between_repairs: 1

---

## Objective

Pilot the seven-terminal-state model as a refinement of the existing `/cortex-spec` necessity gate, shipping a `--terminal` flag on `/cortex-close`, an auto-generated `current-understanding.md` artifact, and a documented terminal taxonomy in `DISCOVERY_LOOP.md` — gated by a pre-pilot retroactive audit and dogfood-closed on this slug itself.

---

## Deliverables

- `docs/cortex/research/clarify-research-loop/audit-results-{timestamp}.md` — pre-pilot retroactive audit of historical necessity verdicts
- `templates/cortex/clarify-brief.md` — updated with `initial_terminal_set:` and `ruled_out:` frontmatter documentation
- `templates/cortex/current-understanding.md` — net-new template
- `~/.claude/skills/cortex-clarify/SKILL.md` — Phase 4b added
- `skills/cortex-clarify/SKILL.md` — Phase 4b added (project-local mirror)
- `~/.claude/skills/cortex-close/SKILL.md` — `--terminal` flag added
- `skills/cortex-close/SKILL.md` — `--terminal` flag added (project-local mirror)
- `docs/cortex/handoffs/decisions.md` — Archive Index format comment updated
- `docs/DISCOVERY_LOOP.md` — new §7 Terminal States section
- `docs/cortex/research/clarify-research-loop/current-understanding.md` — working example for this slug

---

## Scope

### In Scope

- All deliverables listed above
- Pre-pilot retroactive audit as a hard gate before any code changes
- Smoke tests on a fresh test slug to verify auto-write, terminal-recording close, and ruled-out rejection
- Dogfood close of this slug (`/cortex-close --terminal commit-to-build`) after acceptance

### Out of Scope

- New skills `/cortex-decompose`, `/cortex-hold`, `/cortex-kill` (deferred)
- Per-terminal artifact templates (`kill-rationale.md`, `decomposition.md`, etc.) (deferred)
- Modifying `/cortex-spec` necessity gate to produce 7 verdicts directly (deferred)
- Cross-artifact frontmatter sync mechanism (deferred)
- Fact extraction pipeline from dossiers to `facts.jsonl` (deferred)
- Specialized subcommand promotion of `--terminal` flag values (deferred)
- Any changes to autonomy presets, hooks, or scripts not listed above

---

## Write Roots

- `templates/cortex/clarify-brief.md`
- `templates/cortex/current-understanding.md`
- `~/.claude/skills/cortex-clarify/SKILL.md`
- `skills/cortex-clarify/SKILL.md`
- `~/.claude/skills/cortex-close/SKILL.md`
- `skills/cortex-close/SKILL.md`
- `docs/cortex/handoffs/decisions.md`
- `docs/DISCOVERY_LOOP.md`
- `docs/cortex/research/clarify-research-loop/`
- `docs/cortex/clarify/clarify-research-loop/` (only for final dogfood close)
- `docs/cortex/specs/clarify-research-loop/`
- `docs/cortex/contracts/clarify-research-loop/`
- `.cortex/state.json`
- `docs/cortex/handoffs/current-state.md`

---

## Done Criteria

- [ ] Retroactive audit results file exists with complete table of historical non-BUILD necessity verdicts and their proposed terminal mapping
- [ ] Audit pass criterion met: ≥60% of historical non-BUILD verdicts map cleanly with confidence ≥0.7
- [ ] `templates/cortex/clarify-brief.md` documents `initial_terminal_set:` and `ruled_out:` fields with worked example
- [ ] `templates/cortex/current-understanding.md` exists with all five sections (Possible Terminals, Durable Findings, Provisional Thoughts, Open Questions, Iteration History)
- [ ] Both copies of `cortex-clarify` SKILL.md contain Phase 4b auto-writing current-understanding.md from brief frontmatter
- [ ] Both copies of `cortex-close` SKILL.md require `--terminal {name}` flag with validation against the seven values and against brief's `ruled_out:` list
- [ ] `decisions.md` Archive Index format includes `terminal:` field with updated format comment
- [ ] `docs/DISCOVERY_LOOP.md` §7 Terminal States section exists with 4→7 refinement mapping; cross-referenced from §1 and §4
- [ ] `docs/cortex/research/clarify-research-loop/current-understanding.md` populated from this slug's briefs/dossiers, includes the six deferrals as future-slug candidates
- [ ] Smoke test passes: fresh slug `/cortex-clarify` auto-writes a `current-understanding.md` with default Possible Terminals
- [ ] Smoke test passes: `/cortex-close --terminal commit-to-build` records `terminal:` field in decisions.md
- [ ] Smoke test passes: `/cortex-close --terminal kill-with-learning` is rejected for a brief with `ruled_out: [kill-with-learning]`
- [ ] All seven terminal slugs documented in at least one of: brief template, DISCOVERY_LOOP.md §7, current-understanding.md template
- [ ] Dogfood: this slug closed via `/cortex-close --terminal commit-to-build` after all above complete

---

## Validators

- [ ] [external] `test -f docs/cortex/research/clarify-research-loop/audit-results-*.md`
- [ ] [external] `test -f templates/cortex/current-understanding.md`
- [ ] [external] `test -f docs/cortex/research/clarify-research-loop/current-understanding.md`
- [ ] [external] `grep -n "initial_terminal_set" templates/cortex/clarify-brief.md`
- [ ] [external] `grep -n "ruled_out" templates/cortex/clarify-brief.md`
- [ ] [external] `grep -n "Possible Terminals" templates/cortex/current-understanding.md`
- [ ] [external] `grep -n "Phase 4b" .claude/skills/cortex-clarify/SKILL.md`
- [ ] [external] `grep -n "Phase 4b" skills/cortex-clarify/SKILL.md`
- [ ] [external] `grep -n -- "--terminal" .claude/skills/cortex-close/SKILL.md`
- [ ] [external] `grep -n -- "--terminal" skills/cortex-close/SKILL.md`
- [ ] [external] `grep -n "terminal:" docs/cortex/handoffs/decisions.md` returns ≥1 match (the dogfood close)
- [ ] [external] `grep -nE "^## .*Terminal States" docs/DISCOVERY_LOOP.md` returns a match
- [ ] [external] All seven terminal slugs (`commit-to-build`, `kill-with-learning`, `decompose`, `experiment-required`, `already-exists`, `hold-on-dependency`, `reframe-and-continue`) appear in `docs/DISCOVERY_LOOP.md`
- [ ] [judgment] The current-understanding.md for this slug is readable and useful — a future reader can understand "what we currently know about this slug" without reading every brief and dossier
- [ ] [judgment] The DISCOVERY_LOOP.md §7 explains the seven terminals clearly enough for a new contributor without prior context
- [ ] [judgment] Audit results table reasoning is convincing — the 4→7 refinement is empirically grounded, not speculative

---

## Eval Plan

docs/cortex/evals/clarify-research-loop/eval-plan.md

---

## Approvals

- [x] Contract approval
- [x] Evals approval

---

## Completion Promise

The executing agent MUST emit this signal when all done criteria are satisfied:
CORTEX_PROMISE: clarify-research-loop-001 COMPLETE

The cortex-task-completed.sh hook checks for this signal.
If the signal is not emitted, the contract is not considered complete even if all validators pass.

---

## Failed Approaches

(none — initial contract)

---

## Why Previous Approach Failed

N/A — initial contract

---

## Rollback Hints

- Revert `templates/cortex/clarify-brief.md` to the version prior to this commit (`git checkout HEAD~1 -- templates/cortex/clarify-brief.md`)
- Delete `templates/cortex/current-understanding.md`
- Revert both copies of `cortex-clarify/SKILL.md` (remove Phase 4b)
- Revert both copies of `cortex-close/SKILL.md` (remove `--terminal` flag handling)
- Revert `docs/cortex/handoffs/decisions.md` format-comment change (the data lines should remain — only the comment is reverted)
- Revert `docs/DISCOVERY_LOOP.md` (remove §7 section and cross-references)
- Delete `docs/cortex/research/clarify-research-loop/current-understanding.md`
- Delete `docs/cortex/research/clarify-research-loop/audit-results-*.md`
- The pre-existing artifacts under `docs/cortex/clarify/clarify-research-loop/` and `docs/cortex/research/clarify-research-loop/concept-*.md` should NOT be touched by rollback — they are part of the slug's history regardless of contract outcome

---

## Repair Budget

**max_repair_contracts:** 3
**cooldown_between_repairs:** 1
