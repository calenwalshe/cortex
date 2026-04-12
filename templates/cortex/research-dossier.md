# Research Dossier: {SLUG} — {PHASE}

<!-- ART-02: Research Dossier Template — produced by /cortex-research -->
<!-- Copy this template to docs/cortex/research/{SLUG}/{PHASE}-{TIMESTAMP}.md in the target project repo -->
<!-- Each phase (concept, implementation, evals) produces a separate dossier — do not combine phases -->

**Slug:** {SLUG} <!-- lowercase-hyphenated identifier matching the active clarify brief -->
**Phase:** {PHASE} <!-- concept | implementation | evals -->
**Timestamp:** {TIMESTAMP} <!-- ISO 8601 UTC timestamp when this dossier was produced -->
**Depth:** {DEPTH} <!-- quick | standard | deep — controls thoroughness of investigation -->

---

## Owner Summary

{OWNER_SUMMARY}

<!-- PLAIN LANGUAGE ONLY — no jargon, no file paths, no slug names, no artifact references -->
<!-- 3 bullets maximum. Necessity filter: cut any sentence that doesn't help the owner decide or act right now. -->
<!--   - What we found: the single most important discovery from this research pass -->
<!--   - What it changes: how this finding affects the decision or approach for this slug -->
<!--   - What's still open: the biggest unresolved question, or "Nothing — research complete" -->
<!-- This section is for the owner returning cold. Everything else below is for research continuity. -->

---

## Summary

{SUMMARY}

<!-- One paragraph: the single most important takeaway from this research pass -->
<!-- Written for research continuity — more detail than Owner Summary, technical depth ok -->
<!-- Written so a reader who skips everything else still gets the core finding -->

---

## Findings

{FINDINGS}

<!-- Key findings — each on its own line starting with "- " -->
<!-- Findings are factual observations, not recommendations -->
<!-- Order by importance: most consequential findings first -->

---

## Trade-offs

{TRADE_OFFS}

<!-- Options considered during research with their trade-offs -->
<!-- Format per option:
### Option: {OPTION_NAME}
**Pros:** ...
**Cons:** ...
**Verdict:** selected | rejected | deferred
-->

---

## Recommendations

{RECOMMENDATIONS}

<!-- What to do based on the findings — actionable direction for the spec or next phase -->
<!-- Each recommendation on its own line starting with "- " -->
<!-- If a recommendation conflicts with a finding, explain why -->

---

## Adjacent Findings

{ADJACENT_FINDINGS}

<!-- 0-3 findings discovered outside the primary research focus that passed the VOI filter pipeline -->
<!-- Omit this entire section (including the heading) if zero findings qualify — do not render an empty section or "None" placeholder -->
<!-- Each finding uses BLUF format: -->
<!--   - **[Finding title]:** [1-2 sentence statement of the finding]. [One sentence: why this matters to the current slug's decisions — the information scent]. Source: [link or reference] -->
<!-- Hard cap: 3 findings maximum. Zero is valid — never pad to fill a quota -->
<!-- Findings must be specific to this slug — reject anything that applies to 80%+ of projects -->

---

## Open Questions

{OPEN_QUESTIONS}

<!-- Questions not resolved by this research pass -->
<!-- Each on its own line starting with "- " -->
<!-- Carry forward to next phase if unresolved — do not discard -->

---

## Sources

{SOURCES}

<!-- List of sources consulted during this research pass -->
<!-- Each on its own line starting with "- " -->
<!-- Include: documentation links, file paths read, external references, prior artifacts -->
