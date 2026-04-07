# Contract 001: Adjacent Discovery Pipeline

**Slug:** research-adjacent-discovery
**Spec:** docs/cortex/specs/research-adjacent-discovery/spec.md
**Status:** complete

---

## Scope

Implement the full adjacent discovery pipeline by modifying two existing files: the research dossier template and the cortex-research SKILL.md. This contract covers all 7 tasks from the spec -- template modification, 4 new SKILL.md sub-phases, filter pipeline documentation, and depth-scaling guidance.

---

## Tasks

- [x] T1: Add `## Adjacent Findings` section to `templates/cortex/research-dossier.md`
  - Position: between Recommendations and Open Questions
  - Include: BLUF format instructions (finding + why-it-matters + source), 2-3 sentence max per finding, 0-3 hard cap
  - Include: omit-if-empty instruction (do not render section if zero findings qualify)

- [x] T2: Add Phase 2b (Outside-In query reformulation) to `skills/cortex-research/SKILL.md`
  - Position: after Phase 2 Step 2 (analyze and identify gaps)
  - Content: IC Outside-In domain checklist (political, economic, technological, legal, social, environmental)
  - Instructions: select 3-5 most relevant domains for the slug, run one reformulated query per domain via `search(query, intent=Intent.SEARCH, provider="tavily", max_results=3)`
  - Include depth scaling: quick = 1-2 angles, standard = 3-5, deep = 5

- [x] T3: Add Phase 2c (assumption-indicator generation) to `skills/cortex-research/SKILL.md`
  - Position: after Phase 2b
  - Content: read clarify brief Assumptions section, generate one falsifiable indicator per assumption
  - Format: "If you observe [X], then assumption [Y] is wrong"
  - Guard: skip cleanly if clarify brief has no Assumptions section
  - Hold indicators for filter pipeline (do not surface directly)

- [x] T4: Add Phase 2d ("Wait" self-check) to `skills/cortex-research/SKILL.md`
  - Position: after all research gathered, before synthesis
  - Content: explicit instruction for the agent to ask itself "what did I not consider?" and evaluate any new candidates against the filter pipeline
  - One step, self-contained

- [x] T5: Add 6-stage filter pipeline to `skills/cortex-research/SKILL.md`
  - Position: in the synthesis section, before dossier writing
  - Stages: (1) VOI/decision-relevance gate (binary, mandatory), (2) specificity/80% test, (3) novelty check, (4) timeliness check (stash-if-later to Open Questions), (5) BLUF formatting, (6) cap at 3 ranked by Impact x Novelty
  - Explicit: zero findings is valid, never pad
  - Explicit: information scent -- every finding must include a "why it matters" sentence specific to the current slug

- [x] T6: Modify Phase 3 dossier output to include Adjacent Findings
  - Add Adjacent Findings to the dossier field population list
  - Implement omit-if-empty: if zero findings passed filter, do not include the section
  - If findings exist, populate using BLUF format from the template

- [x] T7: Add depth-scaling table for adjacent discovery
  - Document in SKILL.md near the existing depth table or within Phase 2b
  - Quick: 1-2 Outside-In angles, skip assumption indicators
  - Standard: 3-5 Outside-In angles, full assumption indicators
  - Deep: 5 Outside-In angles, full assumption indicators, extended "Wait" self-check

---

## Deliverables

| Artifact | Path |
|----------|------|
| Modified research dossier template | `templates/cortex/research-dossier.md` |
| Modified research skill | `skills/cortex-research/SKILL.md` |

---

## Acceptance Criteria

- [ ] Research dossier template contains `## Adjacent Findings` section between Recommendations and Open Questions
- [ ] Template documents BLUF format, 2-3 sentence max, 0-3 cap, and omit-if-empty rule
- [ ] SKILL.md contains Phase 2b with Outside-In domain checklist and query reformulation instructions
- [ ] SKILL.md contains Phase 2c with assumption-indicator generation and skip guard
- [ ] SKILL.md contains Phase 2d with "Wait" self-check
- [ ] SKILL.md contains 6-stage filter pipeline with all stages documented and VOI as mandatory binary gate
- [ ] Filter pipeline explicitly states zero findings is valid and padding is prohibited
- [ ] Phase 3 output instructions reference Adjacent Findings and implement omit-if-empty
- [ ] Depth scaling documented: quick (1-2 angles, skip indicators), standard (3-5 angles), deep (5 angles)
- [ ] No new files created -- only modifications to the two listed files
- [ ] Every surfaced finding includes a slug-specific "why it matters" sentence (information scent requirement)
- [ ] Reformulated queries use `max_results=3` (not 7) to stay within wall time budget

---

## Validation

Manual validation by running `/cortex-research` on an active slug after modifications and verifying:
1. The dossier contains an `## Adjacent Findings` section (or correctly omits it if zero findings qualify)
2. Adjacent findings use BLUF format with information scent
3. No more than 3 adjacent findings appear
4. The research phase completes within its normal time budget + 2 minutes
