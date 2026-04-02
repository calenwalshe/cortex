# GSD Handoff: adaptive-autonomy

**Slug:** adaptive-autonomy
**Timestamp:** 20260402T064000Z
**Status:** draft

---

## Objective

Build a configurable autonomy system for the Cortex-GSD pipeline so the entire flow from problem framing through verified execution can run with zero stops (full-auto), approval-only stops (gates-only), or step-by-step stops (supervised), controlled by a shared config file and bridge command that eliminates the manual Cortex-to-GSD handoff.

---

## Deliverables

- `.cortex/autonomy.json` template — autonomy config schema with 3 presets and 13 per-gate overrides
- `~/.claude/cortex-autonomy.json` — global fallback config (same schema)
- `skills/cortex-bridge/SKILL.md` — bridge command that generates GSD milestone artifacts from Cortex outputs
- Updated `skills/cortex-clarify/SKILL.md` — conditional gate wrapper on slug conflict
- Updated `skills/cortex-research/SKILL.md` — conditional gate wrapper on eval proposal approval
- Updated `skills/cortex-spec/SKILL.md` — conditional gate wrappers on contract approval, critical uncertainties, evidence backing
- Updated `skills/cortex-review/SKILL.md` — conditional gate wrappers on eval plan validation, compliance verdict
- Updated `skills/cortex-audit/SKILL.md` — conditional gate wrapper on security verdict
- Updated GSD `drive-workflow.md` — discuss action reads autonomy config, generates CONTEXT.md from Cortex artifacts
- Tests for config resolution, bridge output, gate conditional paths

---

## Requirements

- AUTON-01: Full-auto preset runs pipeline without stops except mandatory gates
- AUTON-02: Supervised preset matches current behavior (backward compatible)
- AUTON-03: Per-gate overrides take precedence over preset defaults
- AUTON-04: Mandatory gates cannot be disabled
- AUTON-05: Bridge generates valid GSD artifacts from Cortex outputs
- AUTON-06: Bridge ROADMAP success criteria match contract done_criteria
- AUTON-07: Config resolution follows 4-layer precedence
- AUTON-08: Dry-run prints resolved config without side effects
- AUTON-09: Auto-skipped gates logged to decisions.md
- AUTON-10: GSD discuss uses Cortex artifacts when available and gate disabled
- AUTON-11: Missing config defaults to supervised
- AUTON-12: /cortex-status shows autonomy level

---

## Tasks

- [ ] Create autonomy config template with schema docs and 3 preset definitions
- [ ] Write config resolution logic (invocation > project > global > preset merge + mandatory gate enforcement)
- [ ] Patch cortex-clarify: wrap slug conflict gate
- [ ] Patch cortex-research: wrap eval proposal approval gate
- [ ] Patch cortex-spec: wrap contract approval, critical uncertainties, evidence backing gates
- [ ] Patch cortex-review: wrap eval plan validation, compliance verdict gates
- [ ] Patch cortex-audit: wrap security verdict gate
- [ ] Build /cortex-bridge: generate PROJECT.md, ROADMAP.md, REQUIREMENTS.md, STATE.md, config.json, CONTEXT.md from Cortex artifacts
- [ ] Patch GSD drive-workflow.md: discuss action reads autonomy config, uses Cortex clarify brief for CONTEXT.md
- [ ] Sync autonomy flags to .planning/config.json via bridge
- [ ] Add --autonomy and --gate invocation flags to Cortex skills
- [ ] Add --dry-run mode
- [ ] Add autonomy decision logging to decisions.md
- [ ] Write tests for config resolution, bridge output, gate conditionals
- [ ] Update /cortex-status to show autonomy level

---

## Acceptance Criteria

- [ ] AUTON-01: Full-auto preset runs pipeline without stops except mandatory gates
- [ ] AUTON-02: Supervised preset matches current behavior (backward compatible)
- [ ] AUTON-03: Per-gate overrides take precedence over preset defaults
- [ ] AUTON-04: Mandatory gates cannot be disabled
- [ ] AUTON-05: Bridge generates valid GSD artifacts from Cortex outputs
- [ ] AUTON-06: Bridge ROADMAP success criteria match contract done_criteria
- [ ] AUTON-07: Config resolution follows 4-layer precedence
- [ ] AUTON-08: Dry-run prints resolved config without side effects
- [ ] AUTON-09: Auto-skipped gates logged to decisions.md
- [ ] AUTON-10: GSD discuss uses Cortex artifacts when available and gate disabled
- [ ] AUTON-11: Missing config defaults to supervised
- [ ] AUTON-12: /cortex-status shows autonomy level

---

## Contract Link

docs/cortex/contracts/adaptive-autonomy/contract-001.md
