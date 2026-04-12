# Spec: report-clarity

## 1. Problem

When the owner returns to a Cortex session after multitasking, the two most-read output surfaces — research dossiers and spec.md — require significant cognitive effort to extract actionable information. Dossiers open with frontmatter and jargon-heavy summaries written for technical insiders; specs present nine sections in assembly-line order that buries the owner-critical Acceptance Criteria at the end. The cortex-drive completion summary exists as a template but is never auto-generated, leaving the owner to parse a raw action log. The net effect: the owner cannot quickly understand what happened, what was found, or what a decision requires without reconstructing context from scratch.

## 2. Scope

### In Scope
- Add `## Owner Summary` as the first body section in `templates/cortex/research-dossier.md` — plain-language 3-bullet BLUF with necessity filter enforced in writing instructions
- Reorder `templates/cortex/spec.md` sections: move Acceptance Criteria from position 9 to position 2 (immediately after Problem)
- Update `skills/cortex-spec/SKILL.md` Phase 2 section list to match new template order
- Update `skills/cortex-drive/SKILL.md` Phase 6 with an explicit Level 1 HITL report generation formula (status line + delta bullets + risk line + owner ask)
- Update `skills/cortex-research/SKILL.md` Phase 3 dossier synthesis to include Owner Summary writing instructions with the necessity filter rule

### Out of Scope
- No changes to contract.md, clarify-brief.md, state.json, or any machine-read artifact format
- No changes to eval-proposal.md, eval-plan.md, or review artifacts
- No new commands or skills
- No retroactive reformatting of existing dossiers or specs already on disk
- No changes to the HITL report template structure itself (`templates/cortex/hitl-report.md`) — only to how cortex-drive generates content that follows it

## 3. Architecture Decision

**Chosen approach:** Additive layer on existing templates + explicit instruction formula in skill files.

**Rationale:** The problem is a missing owner-facing layer, not a structural failure. Adding `## Owner Summary` above existing dossier sections preserves all existing content and is backward compatible. Reordering spec sections changes reading order without changing content. Explicit formulas in skill instructions eliminate reliance on implementation discipline. No new infrastructure, no new commands.

**Alternatives Considered:**
- **Replace `## Summary` with a reformatted version** — rejected. Breaking change to existing dossiers; higher implementation complexity; risk of drifting back toward jargon without a dedicated constraint section.
- **Add a `/cortex-report` command** — rejected. Adds ceremony. The fix should be inline in existing output, not gated behind a new command the owner has to remember.
- **Generate HITL report via a separate LLM call** — rejected. Overkill for three surface edits. The formula is deterministic enough to specify as instruction text.

## 4. Interfaces

| Artifact | Type | Read/Write | Notes |
|---|---|---|---|
| `templates/cortex/research-dossier.md` | template | write | Add `## Owner Summary` section before `## Summary` |
| `templates/cortex/spec.md` | template | write | Reorder: Acceptance Criteria moves from §9 to §2 |
| `skills/cortex-research/SKILL.md` | skill instruction | write | Phase 3: add Owner Summary writing instructions + necessity filter |
| `skills/cortex-spec/SKILL.md` | skill instruction | write | Phase 2: update section order to match new template |
| `skills/cortex-drive/SKILL.md` | skill instruction | write | Phase 6: add Level 1 HITL formula (status line + delta + risk + ask) |

All five files are hard-linked between `skills/*/SKILL.md` (repo) and `~/.claude/skills/*/SKILL.md` (installed). One edit updates both.

## 5. Dependencies

- No library or service dependencies — all changes are to markdown files
- Hard-link sync: edits to `skills/*/SKILL.md` automatically propagate to `~/.claude/skills/*/SKILL.md` (pre-existing hard-link infrastructure)

## 6. Risks

- **Owner Summary drifts toward jargon over time** — Mitigation: the necessity filter rule ("cut any sentence that doesn't help the owner decide or act") is written into the skill instruction, not just the template comment. It's a constraint on the writing LLM, not a style suggestion.
- **Spec section reorder breaks existing executor expectations** — Mitigation: section numbering (§1, §2, etc.) changes but section names remain identical. Any executor that reads by section name (not number) is unaffected. cortex-spec SKILL.md is updated simultaneously.
- **Two-summary redundancy in dossiers (Owner Summary + Summary)** — Mitigation: template comments will distinguish them: Owner Summary = "3 bullets, plain language, owner decides whether to read further"; Summary = "single paragraph, technical detail, for research continuity." Different audiences, different purposes.

## 7. Sequencing

1. Update `templates/cortex/research-dossier.md` — add Owner Summary section with formula and necessity filter comment
2. Update `templates/cortex/spec.md` — reorder sections (Acceptance Criteria to §2)
3. Update `skills/cortex-research/SKILL.md` — Phase 3 dossier synthesis Owner Summary instructions
4. Update `skills/cortex-spec/SKILL.md` — Phase 2 section order
5. Update `skills/cortex-drive/SKILL.md` — Phase 6 Level 1 HITL formula
6. Verify: read each updated file and confirm changes landed correctly

## 8. Tasks

- [ ] Edit `templates/cortex/research-dossier.md`: insert `## Owner Summary` block before `## Summary` with 3-bullet BLUF formula and necessity filter comment
- [ ] Edit `templates/cortex/spec.md`: move `## 9. Acceptance Criteria` section content to `## 2. Acceptance Criteria`, renumber all subsequent sections, update section references
- [ ] Edit `skills/cortex-research/SKILL.md`: in Phase 3 "Populate all fields", add Owner Summary population instructions before Summary instructions, including: 3-bullet formula, plain-language rule, no-filepath rule, necessity filter
- [ ] Edit `skills/cortex-spec/SKILL.md`: update Phase 2 section list to read: 1=Problem, 2=Acceptance Criteria, 3=Scope, 4=Architecture Decision, 5=Interfaces, 6=Dependencies, 7=Risks, 8=Sequencing, 9=Tasks
- [ ] Edit `skills/cortex-drive/SKILL.md`: replace Phase 6 Completion Summary instruction with explicit Level 1 formula: status line (1 sentence, what was built, no jargon) + ≤3 delta bullets (past tense, plain language, no file paths) + 1 risk line (or "No risks identified") + explicit owner ask ("Nothing needed — slug is done" or specific action)
- [ ] Verify all 5 files updated correctly by reading each

## 9. Acceptance Criteria

- [ ] `templates/cortex/research-dossier.md` contains `## Owner Summary` as the first body section, before `## Summary`, with a documented 3-bullet formula (what we found / what it changes / what's still open) and an explicit necessity filter comment
- [ ] `templates/cortex/spec.md` lists Acceptance Criteria as section 2, immediately after Problem, with all other sections renumbered accordingly
- [ ] `skills/cortex-drive/SKILL.md` Phase 6 specifies the Level 1 HITL formula verbatim: (a) 1-sentence status line naming what was built in plain language, (b) ≤3 delta bullets in past tense with no file paths, (c) 1 risk line, (d) explicit owner ask
- [ ] `skills/cortex-spec/SKILL.md` Phase 2 section list matches the new template order (1=Problem, 2=Acceptance Criteria, 3=Scope, 4=Architecture Decision, 5=Interfaces, 6=Dependencies, 7=Risks, 8=Sequencing, 9=Tasks)
- [ ] `skills/cortex-research/SKILL.md` Phase 3 includes Owner Summary population instructions with the necessity filter rule ("cut any sentence that doesn't help the owner decide or act right now")
