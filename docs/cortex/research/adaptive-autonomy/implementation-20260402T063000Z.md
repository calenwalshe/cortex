# Research Dossier: adaptive-autonomy — implementation

**Slug:** adaptive-autonomy
**Phase:** implementation
**Timestamp:** 20260402T063000Z
**Depth:** standard

---

## Summary

The implementation path is clear: GSD already has artifact-driven state machine + config flag system (`gsd-tools.cjs config-get`), and Cortex already has gate fields in `state.json`. Both systems use the same pattern — check a boolean, block or proceed. The autonomy config (`.cortex/autonomy.json`) adds a single resolution layer that both systems read before evaluating their gates. The bridge command generates GSD artifacts directly from Cortex outputs (no Skill() chaining). Total scope: 1 new config file, 1 new command (`/cortex-bridge`), conditional logic patches to ~8 existing skill files, and preset definitions.

---

## Findings

### GSD Automation Internals

- **Drive uses artifact-driven state machine**: next action determined by file existence (CONTEXT.md? PLAN.md count? SUMMARY.md count? UAT.md status?). State always re-read from disk after each Skill() call — never cached.
- **Config flag pattern**: all optional behaviors use `gsd-tools.cjs config-get workflow.FLAG_NAME` with fallback to `"false"`. Adding new flags is trivial — no schema validation exists.
- **Drive auto-context**: when discuss-phase is skipped, writes minimal CONTEXT.md with `"Claude's Discretion — All implementation decisions deferred to Claude's judgment"`. Commits with conventional message. Does NOT read Cortex artifacts.
- **Autonomous adds smart-discuss**: generates 3-4 grey areas with recommended answers in tables, human picks "Accept all" or "Change QN". Infrastructure phases auto-detect and skip grey areas entirely.
- **Autonomous has lifecycle management**: audit-milestone → complete-milestone → cleanup after all phases. Drive does not.
- **`workflow._auto_chain_active` flag**: set at drive start, cleared at end. Downstream skills read it to suppress user prompts. This is the existing mechanism for "skip HITL during automation."
- **Pause triggers (drive)**: only 3 conditions — `checkpoint:human-action`, 2 verification retries exhausted, Skill() call error. Everything else auto-resolves.
- **Pause triggers (autonomous)**: adds `gaps_found` user choice (run/skip/stop) and blocker handling (fix/skip/stop).

### Cortex Gate Implementation

- **All gates are in SKILL.md instructions** (not code). They're conditional text blocks: "Read X. If condition, output BLOCKED message and stop."
- **Gate A — Reclarify**: reads `.cortex/state.json` → `reclarify_required`. Hard block, early return. Human runs `/cortex-clarify` to unblock.
- **Gate B — Critical Uncertainties**: reads `docs/cortex/handoffs/open-questions.md`, filters `severity: critical AND status: open`. Hard block. Human edits file or runs research.
- **Gate C — Evidence Backing**: scans research dossiers for unsubstantiated assumptions. Hard block. Human runs more research.
- **Gate D — Contract Approval**: reads `.cortex/state.json` → `approvals.contract`. State-based mode gate. Human checks box in contract markdown + updates state.json.
- **Gate E — Eval Plan Validation**: reads contract `eval_plan:` field, checks file exists. Review block `[BLOCK]`. Fully automatable (file existence check).
- **Gate F — Compliance Verdict**: synthesizes review findings into COMPLIANT/NON-COMPLIANT. Genuine judgment.
- **Gate G — Slug Conflict**: reads `.cortex/state.json` → `slug`. Warning gate (ask confirm). Auto-skippable.

### Config Patterns in Project

- **GSD config**: `.planning/config.json` — flat keys + `workflow` object with boolean flags. Template version at `upstream/gsd/get-shit-done/templates/config.json` has `gates` object (per-gate booleans), `safety`, `parallelization`.
- **Cortex state**: `.cortex/state.json` — slug, mode, gates, artifacts, approvals.
- **Claude Code settings**: `~/.claude/settings.json` (global) + `.claude/settings.json` (project) — merged by harness. Strongest precedent for global+project layering.
- **No JSON Schema validation** exists anywhere today. All configs are raw `JSON.parse`.
- **runtime-manifest.json** has `profiles` concept (skills tagged `["core", "full"]`), proving profile-based inclusion is established.

### Cortex→GSD Artifact Mapping (for bridge command)

- **PROJECT.md**: 80-90% derivable from spec + clarify brief. Gaps: business context, timeline constraints.
- **ROADMAP.md**: gsd-handoff.md has phases + success criteria. Fully automatable for single-phase. Multi-phase needs human sequencing.
- **REQUIREMENTS.md**: 85% derivable from contract done_criteria + spec tasks. Gap: category taxonomy.
- **CONTEXT.md**: 70% derivable. Gap: "vision framing" (how user imagines it working) vs. technical problem frame.
- **STATE.md**: fully automatable — initial state from contract phase + approval status.

---

## Trade-offs

### Option: Autonomy config in `.cortex/autonomy.json` (new file)

**Pros:** Clean separation from state (state.json) and GSD config (config.json). Single-purpose file. Both systems read it independently.
**Cons:** Third config file in `.cortex/`. Users must know it exists.
**Verdict:** selected — separation of concerns is worth the extra file. Discovery solved by `/cortex-status` showing current autonomy level.

### Option: Embed autonomy in existing `.planning/config.json`

**Pros:** One fewer file. GSD already reads this.
**Cons:** Mixes Cortex concerns into GSD config. Cortex skills would need to read `.planning/config.json` — coupling direction is wrong (Cortex should not depend on GSD file paths).
**Verdict:** rejected — wrong dependency direction

### Option: Embed autonomy in `.cortex/state.json`

**Pros:** Already read by all Cortex skills.
**Cons:** state.json is per-slug ephemeral state; autonomy is persistent config. Different lifecycles.
**Verdict:** rejected — lifecycle mismatch

### Option: Bridge generates artifacts via Skill() calls to GSD commands

**Pros:** Uses existing GSD skill machinery. Format always correct.
**Cons:** Skills designed for human invocation — error handling between skills is ad-hoc. Drive-workflow.md explicitly warns against Agent() nesting (issue #686). Skill() chaining has context window pressure.
**Verdict:** rejected — direct artifact generation is more reliable

### Option: Bridge generates artifacts directly (template-based)

**Pros:** Fast, deterministic, no Skill() chaining overhead. Can validate output before writing. No context window pressure.
**Cons:** Must track GSD artifact format changes. Tight coupling to GSD template structure.
**Verdict:** selected — coupling is acceptable because gsd-handoff.md already encodes the mapping. Format changes are caught by GSD validation.

### Option: Individual gate names in config (13 gates)

**Pros:** 1:1 mapping to code. Grep-friendly. No abstraction layer to document.
**Cons:** Slightly verbose config for users who want "turn off all approval gates."
**Verdict:** selected — 13 gates is small enough that categories add more complexity than they remove

### Option: Gate categories (approval, validation, checkpoint)

**Pros:** Concise for bulk overrides ("all approvals off").
**Cons:** Categories need documentation. Edge cases (is slug_conflict an "approval" or "validation"?). Abstraction layer that hides what's actually happening.
**Verdict:** rejected — individual gates are clearer

---

## Recommendations

### Config Schema

File: `.cortex/autonomy.json` (project) with fallback `~/.claude/cortex-autonomy.json` (global), overridable per-invocation with `--autonomy <preset>` or `--gate <name>=<bool>`.

```json
{
  "preset": "supervised | gates-only | full-auto",
  "gates": {
    "contract_approval": true,
    "ux_taste_eval": true,
    "reclarify": true,
    "critical_uncertainties": true,
    "eval_proposal": true,
    "slug_conflict": true,
    "sparse_idea": true,
    "security_verdict": true,
    "human_action": true,
    "human_verify": true,
    "decision_checkpoint": true,
    "discuss_phase": true,
    "uat_review": true
  },
  "mandatory": ["ux_taste_eval", "human_action", "reclarify"],
  "bridge": {
    "skip_discuss": false,
    "auto_roadmap": false
  },
  "logging": {
    "log_autonomy_in_commits": true,
    "decisions_log": true
  }
}
```

### Preset Defaults

| Gate | supervised | gates-only | full-auto |
|------|-----------|-----------|----------|
| contract_approval | true | true | false |
| ux_taste_eval | true | true | **true** (mandatory) |
| reclarify | true | true | **true** (mandatory) |
| critical_uncertainties | true | true | false |
| eval_proposal | true | false | false |
| slug_conflict | true | false | false |
| sparse_idea | true | false | false |
| security_verdict | true | true | false |
| human_action | true | true | **true** (mandatory) |
| human_verify | true | true | false |
| decision_checkpoint | true | false | false |
| discuss_phase | true | false | false |
| uat_review | true | true | false |

### Resolution Order

```
invocation flag > project .cortex/autonomy.json > global ~/.claude/cortex-autonomy.json > preset defaults
```

Merge: objects deep-merged recursively, scalars replaced. After merge, mandatory gates forced to `true`.

### Bridge Command (`/cortex-bridge`)

Reads: `docs/cortex/specs/{slug}/gsd-handoff.md` + `docs/cortex/specs/{slug}/spec.md` + `docs/cortex/contracts/{slug}/contract-001.md`

Generates:
1. `.planning/PROJECT.md` — from spec objective, clarify brief goal/constraints, contract done_criteria
2. `.planning/ROADMAP.md` — from gsd-handoff phases, contract done_criteria as success criteria
3. `.planning/REQUIREMENTS.md` — from contract done_criteria + spec tasks, auto-categorized
4. `.planning/STATE.md` — initial state with milestone name, phase 1 position
5. `.planning/config.json` — standard GSD config with `workflow.research` derived from autonomy preset
6. Phase `{N}-CONTEXT.md` — pre-populated from clarify brief + spec architecture. If `bridge.skip_discuss` is true, marks all decisions as "Claude's Discretion". If false, marks human-required sections with `[EDIT ME]`.

### Skill File Patches

Each gate in Cortex skills needs a 3-line conditional wrapper:

```
Before evaluating gate condition:
  1. Read autonomy config (resolve project > global > preset)
  2. Check if gate is enabled: resolved_config.gates.{gate_name}
  3. If gate disabled AND gate not in mandatory list: skip check, log "gate skipped (autonomy: {preset})"
  4. If gate enabled: evaluate as current behavior
```

GSD integration point: drive-workflow.md Section 1 "discuss" action checks `autonomy.gates.discuss_phase` before generating auto-context. If Cortex artifacts exist AND gate disabled, generates CONTEXT.md from Cortex clarify brief instead of minimal "Claude's Discretion" template.

### Autonomy Logging

- When a gate is auto-skipped, append to `docs/cortex/handoffs/decisions.md`: `{timestamp} | {gate_name} | auto-skipped | autonomy: {preset}`
- When full-auto makes a genuine decision (at a `decision_checkpoint`), log the choice + rationale to same file
- If `logging.log_autonomy_in_commits` is true, commit messages include `[autonomy: {preset}]` tag

### Dry-Run Mode

`--dry-run` flag (or `bridge.dry_run: true`) prints:
1. Current autonomy level and resolved gate values
2. Which gates would fire vs. skip for the current slug's state
3. For bridge: what artifacts would be generated and their approximate content
4. Does NOT write any files or change state

---

## Open Questions

- Should `/cortex-bridge` be a standalone skill or a subcommand of `/cortex-spec` (e.g., `/cortex-spec --bridge`)?
- How should autonomy config versioning work — if a slug starts at `supervised` and switches to `full-auto` mid-pipeline, should state track the original level?
- Should drive-workflow.md read `.cortex/autonomy.json` directly, or should the bridge command sync relevant flags into `.planning/config.json` at import time?
- Is there a meaningful difference between "gate disabled" (auto-proceed) and "gate disabled with logging" (auto-proceed but flag for post-hoc review)? Or is logging always-on sufficient?

---

## Sources

- `/home/agent/.claude/skills/gsd-drive/SKILL.md` — drive entry point
- `/home/agent/.claude/skills/gsd-drive/drive-workflow.md` — full state machine, decision table, dispatch logic, pause triggers
- `/home/agent/.claude/get-shit-done/workflows/autonomous.md` — smart discuss, lifecycle, blocker handling
- `/home/agent/.claude/get-shit-done/workflows/discuss-phase.md` — CONTEXT.md generation, grey area capture
- `/home/agent/.claude/get-shit-done/workflows/quick.md` — lightweight task execution
- `/home/agent/.claude/get-shit-done/workflows/fast.md` — inline trivial fixes
- `/home/agent/.claude/skills/cortex-spec/SKILL.md` — reclarify, critical uncertainties, evidence backing, contract approval gates
- `/home/agent/.claude/skills/cortex-review/SKILL.md` — eval plan validation, compliance verdict gates
- `/home/agent/.claude/skills/cortex-clarify/SKILL.md` — slug conflict gate
- `/home/agent/projects/cortex/.cortex/state.json` — current gate field structure
- `/home/agent/projects/cortex/.planning/config.json` — GSD config (project)
- `upstream/gsd/get-shit-done/templates/config.json` — GSD config template (full schema)
- `/home/agent/projects/cortex/.auto-doc-sync.json` — doc sync config pattern
- `/home/agent/projects/cortex/runtime-manifest.json` — profile-based inclusion pattern
- `~/.claude/settings.json` — Claude Code global+project layering precedent
- ESLint flat config, TSConfig extends, Cosmiconfig — external config layering patterns
