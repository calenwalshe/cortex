# Cortex Status — Continuity Reconstruction

Reconstruct the current working context from repo-local artifacts and update the continuity handoff files. The primary recovery command after `/clear`, `/compact`, or context exhaustion.

## User-invocable

When the user types `/cortex-status`, run this skill.

Also trigger when the user says:
- "what's the current state"
- "reconstruct context"
- "where were we"
- "resume from cortex"
- "status check"

## Arguments

`/cortex-status` — no flags or arguments.

## Instructions

### Phase 1: Read Machine-Readable State

1. Read `.cortex/state.json`.
2. Extract: `slug`, `mode`, `approval_status`, `active_contract` path, `artifacts` array, `approvals` object, `gates` object.
3. If `state.json` does not exist or is empty: note "No runtime state found — fresh project or state.json not initialized. Run /cortex-clarify to begin." Continue to Phase 2 with all state fields blank.

### Phase 2: Read Human-Readable Continuity State

1. Read `docs/cortex/handoffs/current-state.md`.
2. Extract all fields: `slug`, `mode`, `approval_status`, `active_contract_path`, `recent_artifacts`, `open_questions`, `blockers`, `next_action`.
3. If `current-state.md` does not exist: note "No current-state.md found. Will reconstruct from artifact scan." Continue to Phase 3.

### Phase 3: Scan docs/cortex/ for Artifact History

1. Scan the following subdirectories and list all files found:
   - `docs/cortex/clarify/` — clarify briefs
   - `docs/cortex/research/` — research dossiers
   - `docs/cortex/specs/` — specs and handoffs
   - `docs/cortex/contracts/` — contracts
   - `docs/cortex/evals/` — eval proposals and plans
   - `docs/cortex/investigations/` — investigation artifacts
   - `docs/cortex/reviews/` — review artifacts
   - `docs/cortex/audits/` — audit artifacts

2. Cross-reference the artifact list with what `state.json` reports. Note any artifacts on disk not reflected in state (stale state), and any artifacts in state not on disk (missing files).

3. If `active_contract_path` is set in state, read the active contract and note its approval status and done criteria.

3a. **Eval plan check:** If `active_contract_path` is set, read the active contract's `eval_plan:` field.
    - If `eval_plan` value is `pending`, `TBD`, empty, or a file path that does not exist on disk:
      Record as a blocker: `eval_plan is pending — run /cortex-research --phase evals and /cortex-research --write-plan to produce the eval plan`
    - If `eval_plan` points to a file that exists: no blocker for this check.

4. Reconcile the slug, mode, and gate states from Phases 1, 2, and 3. The artifact scan takes precedence over `current-state.md` for factual artifact existence; `state.json` takes precedence for gate values.

### Phase 4: Refresh Continuity Files

**Update `docs/cortex/handoffs/current-state.md`** with reconciled state from Phases 1–3:
- Correct any stale or missing fields
- Ensure `recent_artifacts` reflects the full artifact scan (all files found in Phase 3)
- Set `next_action` based on current `mode` and gate state:
  - mode `clarify`, `clarify_complete: false` → "Run /cortex-clarify to begin"
  - mode `research`, `research_complete: false` → "Run /cortex-research --phase concept"
  - mode `spec`, `spec_complete: false` → "Run /cortex-spec"
  - mode `spec`, approval pending → "Human must review and approve spec.md and contract-001.md"
  - mode `execute` → "Human must import gsd-handoff.md into GSD explicitly"
  - mode `validate` → "Run /cortex-review or /cortex-audit as appropriate"
  - Otherwise → derive from contract state

**Write `docs/cortex/handoffs/next-prompt.md`** using `templates/cortex/next-prompt.md`:
- Fill all template fields from the reconciled state
- This prompt must be paste-ready for a human to use after `/clear`
- The paste-ready prompt must include: current slug, mode, active contract path, and the next action

### Phase 5: Resolve Autonomy Config

1. Check if `.cortex/autonomy.json` exists (project config).
2. Check if `~/.claude/cortex-autonomy.json` exists (global config).
3. Resolve autonomy config using the 4-layer resolver logic from `scripts/cortex/resolve-autonomy.js`:
   - If project config exists, read it as `projectConfig`
   - If global config exists, read it as `globalConfig`
   - If neither exists, use defaults (supervised preset)
4. Record: resolved `preset` name, the full `gates` object (13 gate booleans), and which config layers are active.
5. Categorize gates into:
   - **Active gates** (value = true, will prompt human)
   - **Skipped gates** (value = false, will auto-proceed)
   - **Mandatory gates** (ux_taste_eval, human_action, reclarify — always active regardless of preset)

### Phase 6: Output Terminal Summary

Output the continuity summary to the terminal (stdout only — this phase produces no additional files):

```
CORTEX STATUS
════════════════════════════════════════
Slug:     {slug | (none)}
Mode:     {mode | (not started)}
Approval: {approval_status}
Contract: {active_contract_path | (none)}

Gates:
  clarify_complete:  {true|false}
  research_complete: {true|false}
  spec_complete:     {true|false}
  contract_approved: {true|false}

Autonomy:
  Preset:   {preset_name}
  Config:   {layers in effect, e.g., "project (.cortex/autonomy.json)" or "defaults only"}
  Active:   {comma-separated list of gates with value=true}
  Skipped:  {comma-separated list of gates with value=false}
  Mandatory: ux_taste_eval, human_action, reclarify (always active)

Artifacts ({N} total):
  {artifact 1}
  {artifact 2}
  ...

Open questions ({N}):
  - {question}
  ...

Blockers:
  {blocker | (none)}

Next action:
  {next_action}

Continuity files refreshed:
  docs/cortex/handoffs/current-state.md
  docs/cortex/handoffs/next-prompt.md
════════════════════════════════════════
```

If no autonomy config exists (defaulting to supervised), display:
```
Autonomy:
  Preset:   supervised (default — no config file found)
  Config:   defaults only
  Active:   all 13 gates
  Skipped:  (none)
  Mandatory: ux_taste_eval, human_action, reclarify (always active)
```

## Rules

- **Safe to run at any time**, including mid-session. It is non-destructive.
- **Does not require chat history.** Reads only from repo-local artifacts: `docs/cortex/handoffs/current-state.md` and `.cortex/state.json`.
- **Reads from exactly two state sources:** `docs/cortex/handoffs/current-state.md` and `.cortex/state.json`. No other state sources are consulted.
- **Does NOT read `.planning/STATE.md` or any GSD planning state.** Cortex state and GSD state are independent.
- **Does not modify product code or GSD state.** The only writes are to `docs/cortex/handoffs/current-state.md` and `docs/cortex/handoffs/next-prompt.md`.
- **Designed specifically for use after `/clear` or compaction** when chat context is lost. Running it after context loss is the correct and expected usage pattern.
- If no state files exist at all, output a clean "not started" summary and instruct the user to run `/cortex-clarify` to begin.
- **Autonomy display is informational.** It reads the autonomy config but does not modify it. If config files are missing, it displays "supervised (default)" — no error.
