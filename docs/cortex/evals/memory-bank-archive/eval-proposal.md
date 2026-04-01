# Eval Proposal: memory-bank-archive

<!-- ART-06: Eval Proposal Template — produced by /cortex-research --phase evals -->

**Slug:** memory-bank-archive
**Timestamp:** 20260331T002000Z
**Status:** draft

---

## Proposed Dimensions

### Functional Correctness
**Applies because:** Always mandatory. The `/cortex-close` skill must implement a precise multi-step lifecycle: slug confirmation gate, artifact copy preserving subdirectory structure, `decisions.md` append, `state.json` reset, `current-state.md` reset. Each step is mechanically verifiable against the done criteria in the contract.
**approval_required:** false

### Regression
**Applies because:** Two existing files are being patched — `scripts/cortex/scaffold_runtime.sh` and `templates/cortex/decisions.md`. The scaffold script is used by new installs; a broken patch could corrupt the scaffold output. The decisions template seeds live files; a malformed section would break the append logic in `/cortex-close`. `docs/cortex/handoffs/decisions.md` (live file) is also patched.
**approval_required:** false

### Integration
**Applies because:** `/cortex-close` reads from `.cortex/state.json` (`artifacts[]`, `slug`, `active_contract`), writes to `docs/cortex/archive/`, appends to `docs/cortex/handoffs/decisions.md`, resets `docs/cortex/handoffs/current-state.md`, and updates `.cortex/state.json`. All five targets must interact correctly in a single operation. The post-close `/cortex-status` clean-state check is an integration checkpoint.
**approval_required:** false

### Safety/Security
**Decision:** EXCLUDE. No auth paths, secrets handling, or privilege escalation. The slug confirmation is a UX concern (data loss prevention), not a security boundary. All writes are to local markdown and JSON files within the repo. No injection vectors.

### Performance
**Decision:** EXCLUDE. No latency or throughput thresholds in the contract. Archive is a rare, human-triggered one-time operation. File copy performance on local disk is not a contract concern.

### Resilience
**Decision:** EXCLUDE. No networked dependencies. The spec's "write archive first, update state.json last" ordering is a design constraint verified under Functional Correctness (mid-run failure leaves state recoverable). No retries or external failure modes to model.

### Style
**Applies because:** The primary deliverable is `skills/cortex-close/SKILL.md` — a markdown skill file. Quality of the skill definition (clarity of instructions, correctness of argument table, completeness of output format spec) directly affects whether the skill executes correctly. Patches to `templates/cortex/decisions.md` and `scaffold_runtime.sh` also have style impact.
**approval_required:** false

### UX/Taste
**Applies because:** `/cortex-close` is a user-facing command with terminal output: slug confirmation prompt, warning when no eval-plan exists, archive progress summary, final clean-state confirmation. The quality and clarity of this output determines whether users trust the command and act on it correctly. Per eval matrix rules, UX/taste always sets `approval_required: true`.
**approval_required:** true

---

## Fixtures

### Fixtures: Functional Correctness
- A populated `.cortex/state.json` with known `artifacts[]`, `slug = "test-slug"`, `active_contract`, and all gates set
- The artifact paths in `artifacts[]` must exist on disk (create stubs: `touch` the paths)
- A pre-existing `docs/cortex/handoffs/decisions.md` with an `## Archive Index` section (or empty)
- A pre-existing `docs/cortex/handoffs/current-state.md` with non-empty state

### Fixtures: Regression
- Baseline output of `scaffold_runtime.sh` before patch (capture directory list it would create)
- Baseline content of `templates/cortex/decisions.md` before patch
- Baseline content of `docs/cortex/handoffs/decisions.md` before patch

### Fixtures: Integration
- Same as Functional Correctness fixtures, plus: verify `/cortex-status` output before and after close (before: slug present; after: slug null/"not started")

### Fixtures: Style
- `skills/cortex-close/SKILL.md` as written
- Reference skill files for comparison: `skills/cortex-clarify/SKILL.md`, `skills/cortex-spec/SKILL.md`

### Fixtures: UX/Taste
- Simulated terminal session showing the full `/cortex-close` flow: confirmation prompt, slug input, warning (no eval-plan path), archive summary output, final status line

---

## Rubrics

### Rubric: Functional Correctness
Each done criterion from the contract is checked independently:
- Slug confirmation: SKILL.md explicitly requires user to type slug before proceeding; instructions are unambiguous
- Artifact copy: all paths in `artifacts[]` appear under `docs/cortex/archive/{slug}/` after close, preserving subdirectory structure (e.g., `clarify/{slug}/foo.md` → `archive/{slug}/clarify/{slug}/foo.md`)
- `decisions.md` append: new entry appears with all required fields (timestamp, slug, contract path, eval-plan path) in correct format
- `state.json` reset: `mode = done`, `slug = null`, `active_contract = null`, all gates `false`
- `current-state.md` reset: file matches "not started" template state exactly
- Warning (no eval-plan): SKILL.md instructions specify a non-blocking warning when eval-plan path is absent or does not exist
- Post-close `/cortex-status`: returns "not started" with no active slug

### Rubric: Regression
- `scaffold_runtime.sh` after patch: `DOCS_SUBDIRS` contains `archive` plus all previously present entries; no entries removed
- `templates/cortex/decisions.md` after patch: `## Archive Index` section present; all pre-existing content unchanged
- `docs/cortex/handoffs/decisions.md` after patch: `## Archive Index` section present; all pre-existing content unchanged

### Rubric: Integration
- After `/cortex-close` runs on a prepared test state, all five targets are in correct state simultaneously (not just individually)
- `/cortex-status` output after close shows: `slug = (none)`, `mode = (not started)`, gates all false, no active contract

### Rubric: Style
- SKILL.md follows the structure of existing skills (User-invocable, Arguments, Instructions, Rules, Output Format sections present)
- Instructions are step-numbered and unambiguous — a stateless agent could follow them without guessing
- Argument table present if arguments exist
- Output Format section shows exact terminal output including the confirmation block

### Rubric: UX/Taste
- Confirmation prompt is clear about what will happen and is not reversible
- Warning for missing eval-plan does not look like an error (distinct phrasing)
- Archive summary shows what was copied (count or list of paths)
- Final output gives clear signal that `/cortex-status` will now return clean

---

## Thresholds

### Threshold: Functional Correctness
**Pass:** All 11 done criteria from the contract are satisfied with no exceptions
**Fail:** Any done criterion fails — no partial pass

### Threshold: Regression
**Pass:** Scaffold output is a superset of baseline (new `archive` entry added, nothing removed); decisions.md and decisions template retain all pre-existing content
**Fail:** Any pre-existing content in patched files is missing or corrupted

### Threshold: Integration
**Pass:** All five write targets are in correct state after a single `/cortex-close` invocation; `/cortex-status` returns clean
**Fail:** Any target is in incorrect state; `/cortex-status` returns non-clean after close

### Threshold: Style
**Pass:** SKILL.md has all required structural sections; instructions are step-numbered; output format is specified
**Fail:** Any required section absent; instructions require guessing; output format unspecified

### Threshold: UX/Taste
**Pass:** Human reviewer confirms: confirmation prompt is unambiguous, warning is non-alarming, archive summary is informative, final output is clear
**Fail:** Human reviewer finds the output confusing, alarming without cause, or lacking key information about what happened

---

## Failure Taxonomy

| Failure Category | Severity | Description | Repair Path |
|-----------------|----------|-------------|-------------|
| Artifact not copied | P0 | One or more `artifacts[]` paths absent from archive | Fix copy logic in SKILL.md; re-run `/cortex-close` (idempotent if archive dir exists) |
| state.json not reset | P0 | `slug`, `mode`, or `active_contract` not cleared after close | Fix state reset step in SKILL.md |
| current-state.md not cleared | P0 | `/cortex-status` returns non-clean state after close | Fix current-state reset step in SKILL.md |
| Subdirectory structure not preserved | P1 | Archive copy is flat rather than mirrored | Fix cp command/logic in SKILL.md instructions |
| decisions.md entry missing fields | P1 | Archive index entry lacks timestamp, slug, contract, or eval-plan fields | Fix append format in SKILL.md |
| Scaffold regression | P1 | `archive` missing from `DOCS_SUBDIRS` or existing entries removed | Revert and re-apply patch to scaffold_runtime.sh |
| No slug confirmation gate | P1 | SKILL.md does not document slug confirmation requirement | Add confirmation gate to SKILL.md instructions |
| Missing eval-plan warning | P2 | SKILL.md does not specify warning behavior when eval-plan absent | Add warning step to SKILL.md |
| Style violations | P2 | SKILL.md missing structural sections or has unordered steps | Revise SKILL.md structure |
| UX output unclear | P2 | Confirmation/summary output confusing to human reviewer | Revise Output Format section in SKILL.md |
| decisions template malformed | P3 | Archive Index section in template has formatting issues | Fix template; re-copy to live decisions.md |

---

## Document-Level Approval Flag

**approval_required:** true

**Reviewer:** project lead

**Approval Status:** approved
