# Contract: claude-code-status-line — execute

**ID:** claude-code-status-line-001
**Slug:** claude-code-status-line
**Phase:** execute
**Created:** 20260410T012000Z
**Status:** draft
**Repair Budget:** max_repair_contracts: 3, cooldown_between_repairs: 1

---

## Objective

Fix the broken `/home/agent/bin/ccstatusline` script by using correct Claude Code schema field access and adding Cortex state surfacing (slug, mode, approval status) so the status line displays usable information instead of `? | ? | ctx: 0%`.

---

## Deliverables

- `/home/agent/bin/ccstatusline` — rewritten with correct schema, cost field, and Cortex integration
- Inline test: piped sample JSON verification before committing the rewrite

---

## Scope

### In Scope
- Correct schema for model, cwd, context, cost
- Cortex state reading with existence guard
- Warning marker for execute-mode-without-contract-approval anomaly
- Graceful degradation on missing fields
- Test with sample JSON before saving

### Out of Scope
- Replacing ccstatusline with a community tool
- Multi-line layouts
- Colors/theming/ANSI
- Modifying settings.json
- Git branch display
- Rate limits, worktrees

---

## Write Roots

- `/home/agent/bin/ccstatusline`
- `docs/cortex/specs/claude-code-status-line/`
- `docs/cortex/contracts/claude-code-status-line/`
- `docs/cortex/research/claude-code-status-line/`

---

## Done Criteria

- [ ] `/home/agent/bin/ccstatusline` reads `model.display_name` correctly and shows model name
- [ ] Script reads `workspace.current_dir` and shows truncated path with `~/` prefix
- [ ] Script reads `context_window.total_input_tokens` + `total_output_tokens` and shows `ctx:N%` correctly
- [ ] Script reads `cost.total_cost_usd` and shows `$X.XX` session cost
- [ ] Script reads `$CLAUDE_PROJECT_DIR/.cortex/state.json` when present and shows `[slug:mode]`
- [ ] Script omits the Cortex section entirely when `.cortex/state.json` does not exist
- [ ] Script shows `⚠` warning when mode is "execute" and `approvals.contract` is false
- [ ] Script does not crash on missing or malformed input — bad fields render as `?`
- [ ] Piped sample JSON test produces expected output without stderr errors

---

## Validators

- [ ] [external] `test -f /home/agent/bin/ccstatusline && test -x /home/agent/bin/ccstatusline` — script exists and is executable
- [ ] [external] `grep -q "display_name" /home/agent/bin/ccstatusline` — uses correct model field
- [ ] [external] `grep -q "workspace" /home/agent/bin/ccstatusline` — uses workspace.current_dir
- [ ] [external] `grep -q "context_window" /home/agent/bin/ccstatusline` — uses correct context field
- [ ] [external] `grep -q "total_cost_usd" /home/agent/bin/ccstatusline` — reads cost field
- [ ] [external] `grep -q "\.cortex/state.json" /home/agent/bin/ccstatusline` — reads Cortex state
- [ ] [external] `grep -q 'approvals' /home/agent/bin/ccstatusline` — checks contract approval
- [ ] [external] Piped sample JSON test succeeds: `echo '{...schema...}' | ccstatusline` produces output with no stderr errors and contains expected fields
- [ ] [external] Piped minimal JSON test: `echo '{}' | ccstatusline` does not crash (graceful degradation)
- [ ] [judgment] Visual output format is readable and fits on a single line

---

## Eval Plan

docs/cortex/evals/claude-code-status-line/eval-plan.md (pending)

---

## Approvals

- [x] Contract approval (auto-approved per user "no HITL" directive)
- [ ] Evals approval

---

## Completion Promise

<!-- CORTEX_PROMISE: claude-code-status-line-001 COMPLETE -->

---

## Failed Approaches

<!-- N/A — initial contract -->

---

## Why Previous Approach Failed

N/A — initial contract

---

## Rollback Hints

- Restore original `/home/agent/bin/ccstatusline` from git: `git -C /home/agent/bin checkout ccstatusline` (if it's in a repo) OR from a backup if taken
- The current broken script output is `agent@agent-stack-dev | ? | ? | ctx: 0%` — if the new version produces something worse, revert to the backup
- settings.json unchanged — no rollback needed there

---

## Repair Budget

**max_repair_contracts:** 3
**cooldown_between_repairs:** 1
