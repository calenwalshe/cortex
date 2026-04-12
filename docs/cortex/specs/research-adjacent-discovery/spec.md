# Spec: research-adjacent-discovery

**Slug:** research-adjacent-discovery
**Timestamp:** 20260407T050000Z
**Status:** draft

---

## 1. Problem

The Cortex research phase answers exactly what it is asked. It follows the clarify brief's open questions and next research steps, then stops. It never surfaces adjacent knowledge -- concepts, risks, prior art, opportunities, or domain context that the user did not think to ask about but that would change their decisions. The highest-value research findings are often things the user did not know to request. Without a structured mechanism for adjacent discovery, the research phase informs but does not educate, and users carry blind spots into the spec and build phases where the cost of discovering them is much higher.

---

## 2. Scope

### In Scope

- Add a 6-stage VOI-gated filter pipeline to the research skill instructions (cortex-research SKILL.md) that identifies, scores, and filters adjacent findings during every research pass
- Add multi-angle query reformulation (3-5 angles from IC Outside-In Thinking) as the discovery mechanism within the existing research execution phases
- Add assumption-indicator generation: for each assumption in the clarify brief, produce one falsifiable indicator
- Add a "Wait" self-check step before dossier finalization
- Add an "## Adjacent Findings" section to the research dossier template (`templates/cortex/research-dossier.md`) between Recommendations and Open Questions
- Produce BLUF-formatted adjacent findings: finding + why-it-matters + source, 2-3 sentences max per finding
- Hard cap of 0-3 adjacent findings per research pass; zero is valid

### Out of Scope

- Citation graph traversal or Semantic Scholar integration (too narrow for general-purpose use; revisit if academic research contexts become common)
- Separate companion artifact for adjacent findings (rejected -- too much ceremony for 0-3 items)
- Opportunity analysis as a standalone feature (folded into Outside-In angles instead)
- Changes to the autonomy config system, gate resolution, or eval pipeline
- Quality tracking dashboard or A/B testing infrastructure for adjacency recommendations
- Modifications to the clarify brief template or spec template
- Connecting late-relevant stashed findings to `/cortex-stash` (deferred; open question)

---

## 3. Architecture Decisions

### Decision 1: Inline section in the research dossier, not a separate artifact

Adjacent findings go into a new `## Adjacent Findings` section in the existing research dossier template, positioned between Recommendations and Open Questions. This avoids creating a new artifact type, keeps findings in context with primary research, and respects the low-ceremony constraint. The section is optional -- if zero findings pass the filter pipeline, the section is omitted entirely (not present with "None" or similar filler).

### Decision 2: VOI as the mandatory gate, not relevance scoring

Value of Information (VOI) is the primary filter: a finding has zero value if the optimal decision is the same regardless of what it reveals. This is a binary pass/fail gate, not a soft score. Everything else (novelty, specificity, timeliness) is secondary scoring applied only after VOI passes. This prevents the system from surfacing "interesting but irrelevant" findings.

### Decision 3: Outside-In query reformulation, not exhaustive search expansion

Discovery happens through 3-5 reformulated queries using the IC Outside-In Thinking domain checklist (political, economic, technological, legal, social, environmental). The researcher picks the 3-5 domains most relevant to the slug and runs one additional query per domain. This is bounded, systematic, and adds at most 2 minutes to wall time. It replaces the alternative of Consensus-style 20-query expansion (too expensive, too noisy).

### Decision 4: Assumption indicators as a sub-component, not a standalone feature

For each assumption listed in the clarify brief, the research phase generates one falsifiable indicator ("if you observe X, this assumption is wrong"). Only indicators that pass the VOI gate AND score on at least one secondary dimension are surfaced. This maps directly to the I&W (Indicators and Warnings) framework from IC tradecraft.

### Alternatives Considered

- **Consensus-style 20-query reformulation:** Rejected -- 20 queries is too expensive and noisy for the marginal gain over 3-5 targeted angles.
- **Semantic Scholar SPECTER embeddings:** Deferred -- only works for academic/documented knowledge, adds an external API dependency, too narrow for Cortex's general-purpose use case.
- **Generic "what am I missing?" prompts:** Rejected -- research shows these produce platitudes without domain anchoring. Domain-specific expert framing ("what would a [specific expert type] be surprised I didn't ask?") works; generic prompts do not.
- **Separate adjacency quality tracking artifact:** Rejected -- premature optimization. Track engagement informally first.

---

## 4. Interfaces

### Modified Files

| File | Change |
|------|--------|
| `skills/cortex-research/SKILL.md` | Add Phase 2b (adjacent discovery), Phase 2c (assumption indicators), Phase 2d ("Wait" self-check). Modify Phase 3 to include adjacent findings in dossier output. |
| `templates/cortex/research-dossier.md` | Add `## Adjacent Findings` section between Recommendations and Open Questions, with format instructions and 0-3 cap. |

### No New Files

No new templates, scripts, or artifacts are created. All changes are modifications to existing files.

### Adjacent Findings Format (in dossier)

```markdown
## Adjacent Findings

<!-- 0-3 findings that passed the VOI filter. Omit this section entirely if zero findings qualify. -->

- **[Finding title]:** [1-2 sentence BLUF statement of the finding and why it matters to this slug's decisions]. Source: [link or reference]
```

### Filter Pipeline Interface (in SKILL.md instructions)

The 6-stage pipeline is documented as a sequential checklist in the SKILL.md. It is not a separate script or function -- it is instructional text that the research agent follows during synthesis. The stages are:

1. Decision-relevance gate (VOI): would knowing this change a decision the user faces?
2. Specificity gate (80% test): does this apply to 80%+ of projects? If yes, filter it out.
3. Novelty check: does the user likely already know this given the clarify brief's context?
4. Timeliness check: is this relevant now, or only later? If later, note it in Open Questions with a trigger condition instead.
5. Format as BLUF: finding + why-it-matters + source. 2-3 sentences max.
6. Hard cap at 3, ranked by Impact x Novelty. Zero is valid.

---

## 5. Dependencies

- **Clarify brief** (existing) -- assumption indicators require the Assumptions section of the clarify brief as input. If the clarify brief has no Assumptions section, skip indicator generation.
- **power-search / search()** (existing) -- reformulated queries use the same search backend as primary research. No new providers or intents required.
- **Research dossier template** (existing) -- modified in-place to add the Adjacent Findings section.
- **cortex-research SKILL.md** (existing) -- modified in-place to add discovery phases.

No new external dependencies. No new API keys. No new packages.

---

## 6. Risks

- **False positives (noise):** The filter pipeline surfaces findings that seem decision-relevant but are not. Mitigation: the 80% specificity test and VOI gate are intentionally aggressive filters. The hard cap of 3 limits damage even if filters are imperfect. Zero is explicitly valid -- the system should err toward omission, not inclusion.
- **Wall time increase:** Adding 3-5 reformulated queries could push standard-depth research beyond the 5-minute target. Mitigation: reformulated queries use the same search backend with `max_results=3` (not 7). Target: under 2 minutes additional. If a query returns nothing useful, do not force a finding from it.
- **Assumption indicator quality:** Falsifiable indicators for vague assumptions may themselves be vague or unfalsifiable. Mitigation: only surface indicators that pass VOI + at least one secondary dimension. If an assumption is too vague to generate a concrete indicator, skip it rather than producing a weak one.
- **Mirror imaging:** The LLM projects its training distribution onto the user's problem, surfacing "adjacent" findings that reflect common patterns rather than the user's specific context. Mitigation: the Outside-In domain checklist forces perspectives outside the model's default frame. The specificity gate (80% test) catches generic advice.
- **Cognitive load on researcher agent:** Adding 4 new sub-phases (2b, 2c, 2d, modified 3) increases instruction complexity. Mitigation: each sub-phase is self-contained with clear entry/exit criteria. The "Wait" self-check is a single sentence appended to the synthesis prompt.

---

## 7. Sequencing

1. **Modify research dossier template** -- Add the `## Adjacent Findings` section to `templates/cortex/research-dossier.md` between Recommendations and Open Questions, with format instructions and the 0-3 cap rule. Verify: template contains the new section with BLUF format instructions.

2. **Add Phase 2b to SKILL.md: multi-angle query reformulation** -- After Phase 2 Step 2 (analyze and identify gaps), add a new step that selects 3-5 Outside-In domains relevant to the slug and runs one reformulated query per domain through the existing search backend. Verify: SKILL.md contains Phase 2b with the Outside-In domain checklist and query generation instructions.

3. **Add Phase 2c to SKILL.md: assumption-indicator generation** -- After Phase 2b, add a step that reads the clarify brief's Assumptions section, generates one falsifiable indicator per assumption, and holds them for the filter pipeline. Verify: SKILL.md contains Phase 2c with indicator generation instructions and the skip-if-no-assumptions guard.

4. **Add Phase 2d to SKILL.md: "Wait" self-check** -- After all research is gathered but before synthesis, add an explicit self-correction step: the agent asks itself "what did I not consider?" and evaluates the response against the filter pipeline. Verify: SKILL.md contains Phase 2d with the "Wait" trigger instruction.

5. **Add the 6-stage filter pipeline to SKILL.md** -- In the synthesis section (Phase 2 Step 5 or equivalent), document the full filter pipeline as a sequential checklist the agent applies to all candidate adjacent findings. Verify: SKILL.md contains the 6 stages with decision criteria for each.

6. **Modify Phase 3 dossier output to include adjacent findings** -- Update the dossier writing instructions to populate the Adjacent Findings section using findings that survived the filter pipeline, or omit the section if zero findings qualify. Verify: SKILL.md Phase 3 references the Adjacent Findings section and the omit-if-empty rule.

---

## 8. Tasks

- [ ] Add `## Adjacent Findings` section to `templates/cortex/research-dossier.md` with BLUF format, 0-3 cap, and omit-if-empty instruction
- [ ] Add Phase 2b (Outside-In query reformulation) to `skills/cortex-research/SKILL.md` with domain checklist and 3-5 angle selection logic
- [ ] Add Phase 2c (assumption-indicator generation) to `skills/cortex-research/SKILL.md` with clarify brief Assumptions input and skip guard
- [ ] Add Phase 2d ("Wait" self-check) to `skills/cortex-research/SKILL.md` before synthesis
- [ ] Add the 6-stage VOI filter pipeline to `skills/cortex-research/SKILL.md` with all decision criteria documented inline
- [ ] Modify Phase 3 dossier output instructions to populate or omit the Adjacent Findings section
- [ ] Add depth-scaling guidance: quick depth gets 1-2 reformulated queries (not 3-5), deep depth gets 5 reformulated queries

---

## 9. Acceptance Criteria

- [ ] `templates/cortex/research-dossier.md` contains an `## Adjacent Findings` section between Recommendations and Open Questions
- [ ] The template section documents BLUF format (finding + why-it-matters + source), 2-3 sentence max per finding, and 0-3 hard cap
- [ ] The template instructs omission of the section when zero findings qualify (no empty section, no "None" placeholder)
- [ ] `skills/cortex-research/SKILL.md` contains Phase 2b with Outside-In domain checklist (political/economic/technological/legal/social/environmental) and instructions to select the 3-5 most relevant domains
- [ ] Phase 2b uses the existing `search()` interface with `max_results=3` for reformulated queries
- [ ] `skills/cortex-research/SKILL.md` contains Phase 2c with assumption-indicator generation that reads the clarify brief's Assumptions section
- [ ] Phase 2c skips cleanly when no Assumptions section exists in the clarify brief
- [ ] `skills/cortex-research/SKILL.md` contains Phase 2d with explicit "Wait" self-check before synthesis
- [ ] The 6-stage filter pipeline is documented in SKILL.md with all stages: (1) decision-relevance/VOI gate, (2) specificity/80% test, (3) novelty check, (4) timeliness check, (5) BLUF formatting, (6) cap at 3 ranked by Impact x Novelty
- [ ] Stage 1 (VOI) is documented as a mandatory binary gate -- nothing proceeds without it
- [ ] The filter pipeline explicitly states that zero findings is a valid outcome and the system must not pad
- [ ] Phase 3 dossier output instructions reference the Adjacent Findings section and implement the omit-if-empty rule
- [ ] Depth scaling is documented: quick = 1-2 angles, standard = 3-5 angles, deep = 5 angles
- [ ] No new files are created beyond modifications to the two existing files (SKILL.md and research-dossier.md)
- [ ] Information scent requirement: every surfaced finding includes a "why it matters" sentence specific to the current slug's decisions (not generic)
