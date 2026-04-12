# Cortex Close — Slug Archive and State Reset

Archive a completed Cortex slug: copy its artifacts to the cold path, record the close in `decisions.md`, and reset the active surface to "not started".

## User-invocable

When the user types `/cortex-close`, run this skill.

Also trigger when the user says:
- "archive this slug"
- "close the current slug"
- "mark this work item done"
- "archive cortex work"

## Arguments

`/cortex-close --terminal <name>` — **`--terminal` is required.** Name must be one of the seven valid terminals:
`commit-to-build`, `kill-with-learning`, `decompose`, `experiment-required`, `already-exists`, `hold-on-dependency`, `reframe-and-continue`.

## Instructions

### Phase 1: Read State

1. Read `.cortex/state.json`.
2. Extract: `slug`, `mode`, `active_contract`, `artifacts[]`.
3. **Guard — `--terminal` required:** Validate the `--terminal` argument:
   - If `--terminal` is missing: ERROR: "`--terminal` is required. Valid values: commit-to-build, kill-with-learning, decompose, experiment-required, already-exists, hold-on-dependency, reframe-and-continue"
   - If `--terminal` value is not in that list: ERROR: "Unknown terminal '{name}'. Valid values: commit-to-build, kill-with-learning, decompose, experiment-required, already-exists, hold-on-dependency, reframe-and-continue"
   - Find the most recent clarify brief for this slug in `docs/cortex/clarify/{slug}/`. Read its YAML frontmatter `ruled_out:` field. If the field exists and contains the requested terminal value: ERROR: "Terminal '{name}' was ruled out in the brief at {brief_path}. Choose a terminal that was not ruled out."
   - Cases where validation passes without ruling-out check: (a) brief has no YAML frontmatter, (b) frontmatter has no `ruled_out:` field, (c) `ruled_out:` is an empty list.
   Stop. Do not proceed.

4. **Guard — no active slug:** If `slug` is `null` or `state.json` is missing, output:
   ```
   ERROR: No active slug. Nothing to close.
   Run /cortex-clarify to start a new work item.
   ```
   Stop. Do not proceed.

### Phase 2: Slug Confirmation Gate

1. Output the following prompt to the user — do NOT proceed until the user responds:
   ```
   You are about to archive slug: {slug}

   This will:
     - Copy all artifacts to docs/cortex/archive/{slug}/
     - Append a close entry to docs/cortex/handoffs/decisions.md
     - Reset .cortex/state.json (mode=done, slug=null, gates cleared)
     - Reset docs/cortex/handoffs/current-state.md to "not started"

   Type the slug name to confirm:
   ```
2. Wait for user input.
3. If the input does not exactly match `{slug}`, output:
   ```
   Confirmation failed. Input "{user_input}" does not match slug "{slug}". Aborting.
   ```
   Stop. Do not proceed.

### Phase 2b: Close Linked GitHub Issue (if any)

1. Read `state.json` for `github.issue_number`.
2. If `issue_number` is set and not null:
   - Run: `gh issue close {issue_number} --comment "Closed by cortex/{slug}" 2>/dev/null`
   - If successful: report "Closed GitHub issue #{issue_number}"
   - If failed (no gh, no remote, already closed): report warning but do not block
3. If `github.pr_url` is set: report "PR: {pr_url}"

### Phase 3: Eval-Plan Check

1. From `state.json`, look for the eval-plan path. Check `artifacts[]` for any entry matching `docs/cortex/evals/{slug}/eval-plan.md`.
2. If no eval-plan artifact exists for this slug:
   ```
   WARNING: No eval-plan found for slug "{slug}". Proceeding without eval-plan reference.
   ```
   Continue — do not block.
3. Record the eval-plan path (or `(none)`) for use in the decisions.md entry.

### Phase 4: Copy Artifacts to Archive

1. For each path in `artifacts[]` from `state.json`:
   - Strip the leading `docs/cortex/` prefix from the artifact path.
   - Destination: `docs/cortex/archive/{slug}/{stripped-path}`
   - Example: `docs/cortex/clarify/{slug}/brief.md` → `docs/cortex/archive/{slug}/clarify/{slug}/brief.md`
2. Create parent directories as needed before writing each file.
3. Copy each artifact file to its destination. Do not delete or modify source files.
4. After copying all artifacts, report the count:
   ```
   Archived {N} artifacts to docs/cortex/archive/{slug}/
   ```

### Phase 5: Append to decisions.md

1. Read `docs/cortex/handoffs/decisions.md`.
2. Get the current ISO 8601 timestamp (UTC).
3. Find the `## Archive Index` section.
4. Replace the placeholder line `(No archived slugs yet)` — or append after the last existing entry — with a new line in this exact format:
   ```
   - {ISO8601} | {slug} | closed | terminal: {terminal_name} | contract: {active_contract} | eval-plan: {eval_plan_path}
   ```
   Where `{terminal_name}` is the validated `--terminal` argument value, and `{eval_plan_path}` is the eval-plan path found in Phase 3, or `(none)` if not present.
5. Write the updated file.

### Phase 6: Reset current-state.md

Write `docs/cortex/handoffs/current-state.md` with this exact content:

```markdown
# Current State

**slug:** (none)

**mode:** (not started)

**approval_status:** (not started)

**active_contract_path:** (none)

**recent_artifacts:**
- (none)

**open_questions:**
- (none)

**blockers:**
- (none)

**next_action:** Run /cortex-clarify to begin a new work item
```

### Phase 7: Reset state.json

Write `.cortex/state.json` with this exact content:

```json
{
  "slug": null,
  "mode": "done",
  "approval_status": "pending",
  "active_contract": null,
  "artifacts": [],
  "approvals": { "contract": false, "evals": false },
  "gates": {
    "clarify_complete": false,
    "research_complete": false,
    "spec_complete": false,
    "contract_approved": false
  }
}
```

### Phase 8: Output Summary

```
CORTEX CLOSE — COMPLETE
════════════════════════════════════════
Slug:     {slug}
Closed:   {ISO8601}
Contract: {active_contract}
Eval:     {eval_plan_path}

Artifacts archived: {N}
  docs/cortex/archive/{slug}/

State reset: .cortex/state.json → mode=done, slug=null
Surface reset: docs/cortex/handoffs/current-state.md → not started

Run /cortex-status to confirm clean state.
════════════════════════════════════════
```

## Rules

- **Slug confirmation gate is mandatory.** Never skip it, even if the user says "skip confirmation" or "just do it".
- **Archive is copy-only.** Never delete, move, or modify source artifact files.
- **Order matters for safety:** Copy artifacts first (Phase 4), append decisions.md second (Phase 5), reset state last (Phases 6–7). A partial run leaves artifacts safely copied and state still pointing at the slug — re-running is safe.
- **Does not run validators or gate checks.** Close is always explicit; checking done_criteria is the user's responsibility before invoking `/cortex-close`.
- **Does not modify `.planning/STATE.md` or any GSD state.** Cortex state and GSD state are independent.
- **Does not trigger hooks directly.** Hook infrastructure (session-end, precompact, postcompact) is mode-agnostic and requires no interaction.
