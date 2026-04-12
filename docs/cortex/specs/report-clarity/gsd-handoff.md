# GSD Handoff: report-clarity

## Objective

Add a plain-language owner layer to the two highest-pain Cortex output surfaces (research dossiers and specs) and enforce Level 1 HITL report generation in cortex-drive — so a returning owner understands what happened and what's needed in under 30 seconds, without parsing jargon or structured text.

## Deliverables

- `templates/cortex/research-dossier.md` — updated with `## Owner Summary` as first body section
- `templates/cortex/spec.md` — Acceptance Criteria moved to section 2
- `skills/cortex-research/SKILL.md` — Phase 3 Owner Summary instructions added
- `skills/cortex-spec/SKILL.md` — Phase 2 section order updated
- `skills/cortex-drive/SKILL.md` — Phase 6 Level 1 HITL formula codified

## Requirements

None formalized.

## Tasks

- [ ] Edit `templates/cortex/research-dossier.md`: insert `## Owner Summary` before `## Summary` with 3-bullet BLUF formula and necessity filter comment
- [ ] Edit `templates/cortex/spec.md`: move Acceptance Criteria to section 2, renumber remaining sections
- [ ] Edit `skills/cortex-research/SKILL.md`: add Owner Summary population instructions with necessity filter to Phase 3
- [ ] Edit `skills/cortex-spec/SKILL.md`: update Phase 2 section list to new order (1=Problem, 2=Acceptance Criteria, 3=Scope, 4=Architecture, 5=Interfaces, 6=Dependencies, 7=Risks, 8=Sequencing, 9=Tasks)
- [ ] Edit `skills/cortex-drive/SKILL.md`: replace Phase 6 with explicit Level 1 HITL formula
- [ ] Verify all 5 files updated correctly

## Acceptance Criteria

- [ ] `templates/cortex/research-dossier.md` has `## Owner Summary` as first body section with 3-bullet formula and necessity filter comment
- [ ] `templates/cortex/spec.md` lists Acceptance Criteria as section 2, immediately after Problem
- [ ] `skills/cortex-drive/SKILL.md` Phase 6 specifies Level 1 HITL formula: 1-sentence status line + ≤3 delta bullets (no file paths) + 1 risk line + explicit owner ask
- [ ] `skills/cortex-spec/SKILL.md` Phase 2 section list matches new order
- [ ] `skills/cortex-research/SKILL.md` Phase 3 includes Owner Summary instructions with necessity filter rule

## Contract Link

`docs/cortex/contracts/report-clarity/contract-001.md`
