# GSD Handoff: research-adjacent-discovery

**Slug:** research-adjacent-discovery
**Spec:** docs/cortex/specs/research-adjacent-discovery/spec.md
**Complexity:** standard
**Estimated contracts:** 1

---

## What This Is

Enhancement to the Cortex research phase. Adds a structured adjacent discovery mechanism so the research skill proactively surfaces 0-3 decision-relevant findings the user did not ask about. All changes are modifications to two existing files: `skills/cortex-research/SKILL.md` and `templates/cortex/research-dossier.md`.

## Key Constraints

- No new files. Two existing files modified.
- Zero adjacent findings is always valid. Never pad.
- VOI (Value of Information) is a mandatory binary gate. Nothing surfaces without decision-relevance.
- Hard cap: 3 findings max. BLUF format. 2-3 sentences each.
- Wall time budget: under 2 minutes additional on standard depth.
- Each reformulated query uses `max_results=3` (not 7).

## Architecture in Brief

1. **Discovery mechanism:** 3-5 reformulated queries using IC Outside-In Thinking domain checklist (political/economic/tech/legal/social/environmental). Pick most relevant domains per slug.
2. **Filtering:** 6-stage pipeline -- VOI gate, specificity (80% test), novelty, timeliness, BLUF format, cap at 3.
3. **Assumption indicators:** For each clarify brief assumption, generate one falsifiable indicator. Surface only if it passes the filter.
4. **"Wait" self-check:** Before finalizing, agent asks itself "what did I not consider?" -- 89.3% blind spot reduction per research.
5. **Output:** `## Adjacent Findings` section in dossier between Recommendations and Open Questions. Omit section if zero findings qualify.

## Sequencing Summary

All 7 tasks fit in a single contract. The template change is trivial (add a section with format instructions). The SKILL.md changes are 4 new sub-phases plus a modification to the existing Phase 3. No dependencies between tasks beyond natural ordering (template before SKILL.md output instructions).

## Files to Modify

| File | What Changes |
|------|-------------|
| `templates/cortex/research-dossier.md` | Add `## Adjacent Findings` section between Recommendations and Open Questions |
| `skills/cortex-research/SKILL.md` | Add Phase 2b (Outside-In queries), Phase 2c (assumption indicators), Phase 2d ("Wait" check), filter pipeline, and modified Phase 3 output |

## Risks Worth Knowing

- **Noise risk** is the main concern. The 6-stage filter with aggressive gates and hard cap is the mitigation. If early runs produce noise, tighten the specificity gate first.
- **Wall time** could creep if reformulated queries are slow. The `max_results=3` constraint and 3-5 query limit bound this.
- **Mirror imaging** (LLM projects its defaults as "adjacent" findings) is countered by the Outside-In checklist forcing non-default perspectives plus the 80% specificity test.

## First Contract

`docs/cortex/contracts/research-adjacent-discovery/contract-001.md` -- covers all 7 tasks. Single contract because all changes are instructional text modifications to two files, no code, no external dependencies.
