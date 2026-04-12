# Contract: report-clarity-001

**ID:** report-clarity-001
**Slug:** report-clarity
**Phase:** execute
**Status:** pending approval

## Objective

Update five Cortex template and skill files to add a plain-language owner layer to research dossiers and specs, and codify the Level 1 HITL formula in cortex-drive — so every Cortex output surface leads with what the owner needs to know in plain English.

## Deliverables

- `templates/cortex/research-dossier.md` — `## Owner Summary` block added as first body section
- `templates/cortex/spec.md` — Acceptance Criteria at section 2, all sections renumbered
- `skills/cortex-research/SKILL.md` — Phase 3 Owner Summary population instructions
- `skills/cortex-spec/SKILL.md` — Phase 2 section order updated
- `skills/cortex-drive/SKILL.md` — Phase 6 Level 1 HITL formula

## Scope

### In Scope
- Five markdown files: 2 templates, 3 skill instruction files
- Additive edits only — no existing content removed

### Out of Scope
- No changes to contract.md, clarify-brief.md, state.json, or eval files
- No new commands, scripts, or infrastructure
- No retroactive reformatting of existing dossiers or specs on disk

## Write Roots

- `templates/cortex/research-dossier.md`
- `templates/cortex/spec.md`
- `skills/cortex-research/SKILL.md`
- `skills/cortex-spec/SKILL.md`
- `skills/cortex-drive/SKILL.md`

## Done Criteria

- [ ] `templates/cortex/research-dossier.md` contains `## Owner Summary` as the first body section, before `## Summary`, with a documented 3-bullet formula (what we found / what it changes / what's still open) and an explicit necessity filter comment
- [ ] `templates/cortex/spec.md` lists Acceptance Criteria as section 2, immediately after Problem, with all other sections renumbered accordingly
- [ ] `skills/cortex-drive/SKILL.md` Phase 6 specifies the Level 1 HITL formula verbatim: (a) 1-sentence status line naming what was built in plain language, (b) ≤3 delta bullets in past tense with no file paths, (c) 1 risk line, (d) explicit owner ask
- [ ] `skills/cortex-spec/SKILL.md` Phase 2 section list matches the new template order (1=Problem, 2=Acceptance Criteria, 3=Scope, 4=Architecture Decision, 5=Interfaces, 6=Dependencies, 7=Risks, 8=Sequencing, 9=Tasks)
- [ ] `skills/cortex-research/SKILL.md` Phase 3 includes Owner Summary population instructions with the necessity filter rule ("cut any sentence that doesn't help the owner decide or act right now")

## Validators

```bash
# DC1: Owner Summary block exists in dossier template
grep -q "## Owner Summary" templates/cortex/research-dossier.md && echo "DC1 PASS" || echo "DC1 FAIL"

# DC2: Acceptance Criteria is section 2 in spec template
grep -n "## 2\." templates/cortex/spec.md | grep -q "Acceptance Criteria" && echo "DC2 PASS" || echo "DC2 FAIL"

# DC3: Level 1 HITL formula in cortex-drive Phase 6
grep -q "status line" skills/cortex-drive/SKILL.md && grep -q "delta bullet" skills/cortex-drive/SKILL.md && echo "DC3 PASS" || echo "DC3 FAIL"

# DC4: Acceptance Criteria in cortex-spec Phase 2 section list
grep -A 15 "Phase 2: Synthesize Spec" skills/cortex-spec/SKILL.md | grep -q "Acceptance Criteria" && echo "DC4 PASS" || echo "DC4 FAIL"

# DC5: Necessity filter in cortex-research Phase 3
grep -q "necessity filter\|decide or act" skills/cortex-research/SKILL.md && echo "DC5 PASS" || echo "DC5 FAIL"
```

## Eval Plan

`docs/cortex/evals/report-clarity/eval-plan.md` (pending)

## Repair Budget

`max_repair_contracts: 3`
`cooldown_between_repairs: 1`

## Failed Approaches

(none — initial contract)

## Why Previous Approach Failed

N/A — initial contract

## Approvals

- [ ] Contract approved for execution
- [ ] Eval plan approved

## Rollback Hints

All changes are to text files tracked in git. Rollback via:
```bash
git checkout HEAD -- templates/cortex/research-dossier.md templates/cortex/spec.md skills/cortex-research/SKILL.md skills/cortex-spec/SKILL.md skills/cortex-drive/SKILL.md
```
