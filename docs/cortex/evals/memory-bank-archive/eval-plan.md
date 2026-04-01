# Eval Plan: memory-bank-archive

<!-- ART-07: Eval Plan Template — written after human approval of the eval proposal -->

**Slug:** memory-bank-archive
**Timestamp:** 20260331T002500Z
**Approved By:** project lead
**Approved At:** 20260331T002500Z

---

## Approved Dimensions

- Functional Correctness
- Regression
- Integration
- Style
- UX/Taste

---

## Fixtures Per Dimension

### Fixtures: Functional Correctness
- `.cortex/state.json` with: `slug = "test-slug"`, `artifacts[]` pointing to stub paths, `active_contract = "docs/cortex/contracts/test-slug/contract-001.md"`, all gates set, `mode = "spec"`
- Stub artifact files at all paths in `artifacts[]` (create with `touch`)
- `docs/cortex/handoffs/decisions.md` with `## Archive Index` section present (or empty body)
- `docs/cortex/handoffs/current-state.md` with non-empty slug state

### Fixtures: Regression
- Snapshot of `scripts/cortex/scaffold_runtime.sh` `DOCS_SUBDIRS` content before patch
- Snapshot of `templates/cortex/decisions.md` full content before patch
- Snapshot of `docs/cortex/handoffs/decisions.md` full content before patch

### Fixtures: Integration
- Same as Functional Correctness fixtures
- `/cortex-status` output captured before `/cortex-close` run (baseline: slug present, gates set)
- `/cortex-status` output captured after `/cortex-close` run (expected: not started, no slug)

### Fixtures: Style
- `skills/cortex-close/SKILL.md` as delivered
- Reference skill files for structural comparison: `skills/cortex-clarify/SKILL.md`, `skills/cortex-spec/SKILL.md`

### Fixtures: UX/Taste
- Simulated terminal session showing full `/cortex-close` flow:
  - Confirmation prompt displayed before any writes
  - User types slug name (correct input path)
  - Warning line shown when eval-plan path does not exist
  - Archive summary showing paths copied
  - Final status line confirming `/cortex-status` will return clean

---

## Thresholds Per Dimension

### Threshold: Functional Correctness
**Pass:** All 11 done criteria from the contract are satisfied with no exceptions — every checkbox in contract-001.md `Done Criteria` can be marked
**Fail:** Any single done criterion fails — no partial pass

### Threshold: Regression
**Pass:** `DOCS_SUBDIRS` in `scaffold_runtime.sh` is a strict superset of baseline (new `archive` entry added, nothing removed); `templates/cortex/decisions.md` and `docs/cortex/handoffs/decisions.md` retain all pre-existing content with `## Archive Index` section appended
**Fail:** Any pre-existing entry removed from `DOCS_SUBDIRS`; any pre-existing content in patched files missing or corrupted

### Threshold: Integration
**Pass:** After a single `/cortex-close` invocation on the test fixture, all five write targets are in correct state simultaneously; `/cortex-status` returns clean (slug = none, mode = not started, all gates false)
**Fail:** Any single write target in incorrect state; `/cortex-status` returns non-clean state after close

### Threshold: Style
**Pass:** `skills/cortex-close/SKILL.md` contains all required structural sections (User-invocable, Arguments, Instructions, Rules, Output Format); instructions are step-numbered; output format block specifies exact terminal output
**Fail:** Any required section absent; instructions require guessing to execute; output format absent

### Threshold: UX/Taste
**Pass:** Human reviewer confirms all four: (1) confirmation prompt is unambiguous about irreversibility, (2) warning for missing eval-plan is visually distinct from an error, (3) archive summary lists what was copied, (4) final output gives clear signal that `/cortex-status` will return clean
**Fail:** Human reviewer finds any of the four points confusing, alarming without cause, or missing

---

## Run Instructions

1. **Functional Correctness**
   - Set up the test fixture: create `.cortex/state.json` with test data, stub all `artifacts[]` paths with `touch`, ensure `decisions.md` and `current-state.md` are in known state
   - Invoke `/cortex-close` following the SKILL.md instructions with `test-slug` as the target slug
   - After completion, check each of the 11 done criteria in contract-001.md:
     - `skills/cortex-close/SKILL.md` exists
     - `DOCS_SUBDIRS` includes `archive`
     - `templates/cortex/decisions.md` has `## Archive Index` section
     - `docs/cortex/archive/` exists on disk
     - Slug confirmation gate is present in SKILL.md
     - All stub artifact paths appear under `docs/cortex/archive/test-slug/` with structure preserved
     - `decisions.md` has new entry with all required fields
     - `state.json` shows `mode=done`, `slug=null`, `active_contract=null`, gates reset
     - `current-state.md` matches "not started" template
     - SKILL.md documents non-blocking warning for missing eval-plan
   - Run `/cortex-status` and verify output is clean

2. **Regression**
   - Capture baseline of `DOCS_SUBDIRS` from `scaffold_runtime.sh` (list the array entries)
   - Apply the patch; diff against baseline — confirm only `archive` is added, nothing removed
   - Capture baseline of `templates/cortex/decisions.md` and `docs/cortex/handoffs/decisions.md`
   - Apply patches; diff against baselines — confirm only `## Archive Index` section is added, all prior content intact

3. **Integration**
   - With test fixture in place (from step 1), run `/cortex-status` and capture output as pre-close baseline
   - Run `/cortex-close` to completion
   - Run `/cortex-status` again; compare output — confirm slug is absent, mode shows "not started", all gates false
   - Verify all five write targets simultaneously: archive dir populated, decisions.md has entry, current-state.md reset, state.json reset, and archive/.gitkeep exists

4. **Style**
   - Read `skills/cortex-close/SKILL.md` and verify structural sections present: User-invocable trigger text, Arguments table (if any args), numbered Instructions, Rules list, Output Format block with example terminal output
   - Compare structure against `skills/cortex-clarify/SKILL.md` as reference
   - Confirm instructions are numbered steps, not prose

5. **UX/Taste** (human review required)
   - Read the Output Format section of `skills/cortex-close/SKILL.md`
   - Review the simulated terminal session fixture
   - Evaluate against the four UX/Taste threshold criteria
   - Record approval or failure with specific notes

---

## Results

- [ ] Functional Correctness
- [ ] Regression
- [ ] Integration
- [ ] Style
- [ ] UX/Taste
