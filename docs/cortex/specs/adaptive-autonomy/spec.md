# Spec: adaptive-autonomy

**Slug:** adaptive-autonomy
**Timestamp:** 20260402T064000Z
**Status:** approved

---

## 1. Problem

The Cortex intelligence pipeline (clarify → research → spec → contract → evals) and GSD execution pipeline (discuss → plan → execute → verify) are sequential systems with a manual handoff gap and redundant human gates. Cortex produces ~80% of the context GSD needs, but GSD's discuss-phase re-asks questions already answered by the clarify brief and research dossiers. The 18 combined HITL gates across both systems include 6 rubber-stamps that add friction without adding safety. Users need a configurable autonomy dial — not a binary switch — so the full pipeline can run fully autonomous, approval-only, or step-by-step depending on the risk profile of the work.

---

## 2. Scope

### In Scope

- Shared autonomy config file (`.cortex/autonomy.json`) with global fallback (`~/.claude/cortex-autonomy.json`)
- Three presets: `supervised` (current behavior), `gates-only` (stop at approvals only), `full-auto` (stop at mandatory gates only)
- Per-gate boolean overrides within presets
- Mandatory gate list that survives all presets (UX/taste eval, human-action checkpoints, reclarify)
- Bridge command (`/cortex-bridge`) that generates GSD milestone artifacts from Cortex outputs
- Conditional gate wrappers in Cortex skill files (~8 skills patched)
- GSD drive-workflow integration: read autonomy config to decide discuss-phase behavior
- Per-invocation override flags (`--autonomy <preset>`, `--gate <name>=<bool>`)
- Dry-run mode showing gate sequence without executing
- Autonomy decision logging to `docs/cortex/handoffs/decisions.md`

### Out of Scope

- Merging Cortex and GSD into a single system — they remain distinct layers
- Removing GSD file-level planning — that granularity is load-bearing
- Web UI or dashboard for autonomy control — CLI/config-file only
- Changing artifact formats (specs, contracts, plans, CONTEXT.md)
- Per-slug autonomy overrides (deferred — presets + per-gate is sufficient for v1)
- Autonomy "budget" concept (deferred — no evidence of need yet)
- JSON Schema validation of config (no validation exists anywhere in project today)

---

## 3. Architecture Decision

**Chosen approach:** Single config file (`.cortex/autonomy.json`) with preset + per-gate overrides, read by both Cortex skills and GSD drive. Bridge command generates GSD artifacts directly from Cortex outputs (no Skill() chaining).

**Rationale:** Both systems already use boolean flag patterns for feature toggles. GSD has `gsd-tools.cjs config-get workflow.FLAG_NAME`; Cortex has `state.json` gates. The autonomy config adds one resolution layer on top. Direct artifact generation for the bridge avoids Skill() nesting issues (GSD issue #686) and context window pressure.

### Alternatives Considered

- **Embed autonomy in `.planning/config.json`:** Rejected — wrong dependency direction. Cortex should not read GSD file paths.
- **Embed autonomy in `.cortex/state.json`:** Rejected — state.json is per-slug ephemeral state; autonomy is persistent config. Different lifecycles.
- **Per-invocation flags only (no config file):** Rejected as sole mechanism — can't set project-wide defaults.
- **Bridge via Skill() chaining:** Rejected — skills designed for human invocation, error handling is ad-hoc, nesting risk per issue #686.
- **Gate categories instead of individual names:** Rejected — 13 gates is small enough that categories add abstraction without reducing complexity.

---

## 4. Interfaces

- **`.cortex/autonomy.json`** (new, this spec writes) — project-level autonomy config. Read by all Cortex skills and GSD drive-workflow.
- **`~/.claude/cortex-autonomy.json`** (new, this spec writes) — global fallback config. Same schema as project-level.
- **`.cortex/state.json`** (existing, this spec reads) — Cortex pipeline state. Read to determine active slug and gate status.
- **`.planning/config.json`** (existing, bridge writes `workflow` flags) — GSD config. Bridge syncs relevant autonomy flags here so GSD doesn't need to read `.cortex/`.
- **`docs/cortex/handoffs/decisions.md`** (existing, this spec appends) — autonomy decision log.
- **Cortex SKILL.md files** (~8 files, this spec patches) — gate conditional wrappers inserted at each HITL decision point.
- **GSD drive-workflow.md** (existing, this spec patches) — discuss action reads autonomy config to decide whether to skip or pre-populate from Cortex artifacts.
- **`gsd-tools.cjs config-get/config-set`** (existing, bridge uses) — GSD config accessor CLI.

---

## 5. Dependencies

- **Cortex skill files** (cortex-clarify, cortex-research, cortex-spec, cortex-review, cortex-audit) — gate logic lives in SKILL.md instruction text
- **GSD drive-workflow.md** — state machine and discuss action dispatch
- **GSD gsd-tools.cjs** — config read/write CLI tool
- **Cortex gsd-handoff.md template** — source mapping for bridge artifact generation
- **Node.js** (existing) — for JSON config resolution logic in bridge command

---

## 6. Risks

- **GSD artifact format drift** — Bridge generates PROJECT.md, ROADMAP.md, etc. directly. If GSD changes its format, bridge output breaks. Mitigation: bridge reads GSD templates as source of truth for structure, not hardcoded strings.
- **Gate skip leads to bad execution** — Full-auto skipping contract approval could allow flawed specs to execute. Mitigation: mandatory gate list (UX/taste, human-action, reclarify) cannot be overridden; full-auto still runs all validators post-execution.
- **Config resolution complexity** — Four-layer resolution (invocation > project > global > preset) could confuse users about which config is active. Mitigation: dry-run mode shows resolved config before execution; `/cortex-status` displays current autonomy level.
- **Cortex-GSD coupling increases** — Bridge creates a dependency between Cortex artifact structure and GSD artifact structure. Mitigation: coupling is intentional and bounded (gsd-handoff.md is the explicit interface contract).

---

## 7. Sequencing

1. Define autonomy config schema and preset defaults → produces `.cortex/autonomy.json` template and resolution logic
2. Implement config resolution function (invocation > project > global > preset merge) → produces reusable resolver
3. Patch Cortex skill files with conditional gate wrappers → produces updated SKILL.md files for ~8 skills
4. Build `/cortex-bridge` command (SKILL.md) → produces bridge skill that generates GSD artifacts from Cortex outputs
5. Patch GSD drive-workflow.md discuss action → reads autonomy config, consumes Cortex artifacts when available
6. Add dry-run mode → `--dry-run` flag prints resolved gates and bridge preview without writing
7. Add autonomy decision logging → appends to `docs/cortex/handoffs/decisions.md`
8. Write tests for config resolution, bridge output, and gate conditional behavior

---

## 8. Tasks

- [ ] Create `.cortex/autonomy.json` template with schema documentation
- [ ] Define 3 preset gate tables (supervised, gates-only, full-auto) as constants
- [ ] Write config resolution function: merge invocation > project > global > preset, then force mandatory gates
- [ ] Patch cortex-clarify SKILL.md: wrap slug conflict gate with autonomy check
- [ ] Patch cortex-research SKILL.md: wrap eval proposal approval gate with autonomy check
- [ ] Patch cortex-spec SKILL.md: wrap contract approval, critical uncertainties, and evidence backing gates with autonomy checks
- [ ] Patch cortex-review SKILL.md: wrap eval plan validation and compliance verdict gates with autonomy checks
- [ ] Patch cortex-audit SKILL.md: wrap security verdict gate with autonomy check
- [ ] Create `/cortex-bridge` SKILL.md: read gsd-handoff.md + spec + contract, generate PROJECT.md, ROADMAP.md, REQUIREMENTS.md, STATE.md, config.json, phase CONTEXT.md
- [ ] Patch GSD drive-workflow.md: discuss action checks autonomy config, generates CONTEXT.md from Cortex clarify brief when artifacts exist and gate disabled
- [ ] Sync relevant autonomy flags to `.planning/config.json` via bridge (so GSD reads config.json, not autonomy.json)
- [ ] Add `--autonomy <preset>` and `--gate <name>=<bool>` invocation flags to Cortex skills
- [ ] Add `--dry-run` mode: print resolved config, gate sequence, bridge preview without writing
- [ ] Add autonomy decision logging: append gate-skip and auto-decision entries to decisions.md
- [ ] Write tests: config resolution edge cases, bridge output validation, gate conditional paths
- [ ] Update `/cortex-status` to display current autonomy level and resolved gate values

---

## 9. Acceptance Criteria

- [ ] AUTON-01: `.cortex/autonomy.json` with `preset: "full-auto"` causes the full Cortex pipeline (clarify → research → spec → contract) to run without human stops except mandatory gates (ux_taste_eval, human_action, reclarify)
- [ ] AUTON-02: `.cortex/autonomy.json` with `preset: "supervised"` produces identical behavior to current system (all gates active) — backward compatible
- [ ] AUTON-03: Per-gate overrides take precedence over preset defaults (e.g., `preset: "full-auto"` + `gates.contract_approval: true` stops at contract approval)
- [ ] AUTON-04: Mandatory gates (`ux_taste_eval`, `human_action`, `reclarify`) cannot be disabled by any preset or per-gate override
- [ ] AUTON-05: `/cortex-bridge` generates valid GSD artifacts (PROJECT.md, ROADMAP.md, REQUIREMENTS.md, STATE.md, config.json, CONTEXT.md) from Cortex outputs without human intervention
- [ ] AUTON-06: Bridge-generated ROADMAP.md success criteria match contract done_criteria exactly
- [ ] AUTON-07: Config resolution follows precedence: invocation flag > project `.cortex/autonomy.json` > global `~/.claude/cortex-autonomy.json` > preset defaults
- [ ] AUTON-08: `--dry-run` prints resolved gate values and bridge preview without writing any files or changing state
- [ ] AUTON-09: Every auto-skipped gate is logged to `docs/cortex/handoffs/decisions.md` with timestamp, gate name, and autonomy preset
- [ ] AUTON-10: GSD drive-workflow.md discuss action generates CONTEXT.md from Cortex clarify brief (not minimal "Claude's Discretion" template) when Cortex artifacts exist and `discuss_phase` gate is disabled
- [ ] AUTON-11: No config file present defaults to `supervised` preset (full backward compatibility)
- [ ] AUTON-12: `/cortex-status` displays current autonomy level and which gates are active/skipped
