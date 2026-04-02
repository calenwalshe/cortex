# Contract: adaptive-autonomy — execute

**ID:** adaptive-autonomy-001
**Slug:** adaptive-autonomy
**Phase:** execute
**Created:** 20260402T064000Z
**Status:** approved

---

## Objective

Build a shared autonomy config and bridge command so the Cortex-GSD pipeline can run fully autonomous, approval-only, or step-by-step depending on a configurable preset, eliminating the manual handoff gap between Cortex intelligence output and GSD execution input.

---

## Deliverables

- `.cortex/autonomy.json` — autonomy config template with preset + per-gate schema
- `skills/cortex-bridge/SKILL.md` — bridge command generating GSD artifacts from Cortex outputs
- Updated Cortex skill files (~8) with conditional gate wrappers
- Updated GSD `drive-workflow.md` with Cortex-aware discuss action
- Test suite for config resolution, bridge output, gate conditionals
- Updated `/cortex-status` with autonomy display

---

## Scope

### In Scope

- Autonomy config schema, presets, per-gate overrides, mandatory gate list
- Config resolution: invocation > project > global > preset merge
- /cortex-bridge command: Cortex artifacts → GSD milestone scaffolding
- Conditional gate wrappers in 8 Cortex skill files
- GSD drive discuss action: read autonomy config, consume Cortex artifacts
- --autonomy, --gate, --dry-run invocation flags
- Autonomy decision logging

### Out of Scope

- Merging Cortex and GSD into one system
- Removing GSD file-level planning
- Per-slug autonomy overrides
- Autonomy budget concept
- JSON Schema validation
- Web UI

---

## Write Roots

- `.cortex/autonomy.json`
- `~/.claude/cortex-autonomy.json`
- `skills/cortex-bridge/`
- `skills/cortex-clarify/SKILL.md`
- `skills/cortex-research/SKILL.md`
- `skills/cortex-spec/SKILL.md`
- `skills/cortex-review/SKILL.md`
- `skills/cortex-audit/SKILL.md`
- `skills/cortex-status/SKILL.md`
- GSD `drive-workflow.md`
- `.planning/config.json` (bridge writes workflow flags)
- `docs/cortex/handoffs/decisions.md`
- `templates/cortex/autonomy.json`
- Test files

---

## Done Criteria

- [ ] AUTON-01: `.cortex/autonomy.json` with `preset: "full-auto"` causes the full Cortex pipeline to run without human stops except mandatory gates (ux_taste_eval, human_action, reclarify)
- [ ] AUTON-02: `.cortex/autonomy.json` with `preset: "supervised"` produces identical behavior to current system — backward compatible
- [ ] AUTON-03: Per-gate overrides take precedence over preset defaults
- [ ] AUTON-04: Mandatory gates (`ux_taste_eval`, `human_action`, `reclarify`) cannot be disabled by any preset or per-gate override
- [ ] AUTON-05: `/cortex-bridge` generates valid GSD artifacts (PROJECT.md, ROADMAP.md, REQUIREMENTS.md, STATE.md, config.json, CONTEXT.md) from Cortex outputs without human intervention
- [ ] AUTON-06: Bridge-generated ROADMAP.md success criteria match contract done_criteria exactly
- [ ] AUTON-07: Config resolution follows precedence: invocation flag > project > global > preset defaults
- [ ] AUTON-08: `--dry-run` prints resolved gate values and bridge preview without writing any files
- [ ] AUTON-09: Every auto-skipped gate logged to `docs/cortex/handoffs/decisions.md` with timestamp, gate name, preset
- [ ] AUTON-10: GSD drive discuss action generates CONTEXT.md from Cortex clarify brief when artifacts exist and discuss_phase gate disabled
- [ ] AUTON-11: No config file present defaults to supervised preset
- [ ] AUTON-12: `/cortex-status` displays current autonomy level and active/skipped gates

---

## Validators

- [ ] Config resolution test: verify 4-layer merge produces correct gate values for all 3 presets
- [ ] Config resolution test: verify mandatory gates forced true regardless of config
- [ ] Bridge output test: generated PROJECT.md has all required sections populated
- [ ] Bridge output test: generated ROADMAP.md success_criteria match input contract done_criteria
- [ ] Bridge output test: generated REQUIREMENTS.md requirement IDs match input contract
- [ ] Gate conditional test: each patched skill respects autonomy config gate value
- [ ] Gate conditional test: mandatory gates fire even when full-auto preset active
- [ ] Dry-run test: no files written, no state changed, output shows resolved gates
- [ ] Backward compat test: no autonomy.json present → all gates active (supervised behavior)
- [ ] Decision log test: auto-skipped gate appends entry to decisions.md
- [ ] Drive integration test: discuss action reads Cortex artifacts when available
- [ ] Status display test: /cortex-status shows autonomy level and gate table

---

## Eval Plan

docs/cortex/evals/adaptive-autonomy/eval-plan.md (pending)

---

## Approvals

- [x] Contract approval
- [ ] Evals approval

---

## Rollback Hints

- Delete `.cortex/autonomy.json` and `~/.claude/cortex-autonomy.json`
- Delete `skills/cortex-bridge/` directory
- Revert SKILL.md patches in cortex-clarify, cortex-research, cortex-spec, cortex-review, cortex-audit, cortex-status (git checkout the files)
- Revert GSD drive-workflow.md patch
- Remove `templates/cortex/autonomy.json`
- Delete test files
- System reverts to supervised-only behavior (current state)
