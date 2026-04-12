# Adjacent Discovery Filtering: Research Findings

**Date:** 2026-04-07
**Context:** Cortex clarify-research-spec pipeline — how the research phase should proactively surface adjacent knowledge without drowning the user in noise.

---

## 1. Decision-Relevance Filtering

### Value of Information (VOI) — The Core Framework

VOI from decision theory is the most directly applicable framework. The key question: **would this information change the decision the user is about to make?**

**Expected Value of Perfect Information (EVPI)** sets the upper bound on what any piece of information is worth. If EVPI for a given uncertainty is low, no amount of research on that topic justifies inclusion. The practical test:

1. **Identify the decision** the user is making (from the clarify phase)
2. **Identify the uncertainties** that affect that decision
3. For each adjacent finding, ask: **does this reduce a decision-relevant uncertainty?**
4. If the answer is "it's interesting but doesn't change what I'd build" — file it, don't surface it

**Key insight from VOI literature:** Information has zero value when the optimal decision is the same regardless of what the information reveals. This is the strongest filter. If finding X wouldn't change the spec, it's noise.

**Diminishing returns:** EVPI provides an upper bound — no sample information can exceed it. As you gather more, remaining uncertainty shrinks, and the value of further research drops. This argues for hard caps on adjacent findings.

### The "So What?" Test — Intelligence Analyst Standard

Intelligence analysts use a structured "So What?" protocol with three sub-questions:

1. **What does this mean?** — Require an assessment, not just a fact
2. **How does it affect the decision-maker?** — Map to a specific decision or action
3. **What happens next?** — Identify implications, indicators, or courses of action

If a finding can't answer all three, it doesn't make the brief. This is directly portable to Cortex: every adjacent finding should carry a "so what" annotation that maps the finding to a decision the user faces.

### Intelligence Briefing Filtering Model

The intelligence community separates collection from briefing via a five-step workflow:

1. **Collection** — gather broadly (research phase does this)
2. **Processing** — structure and normalize
3. **Evaluation** — score against defined priorities
4. **Analysis** — synthesize and draw conclusions
5. **Dissemination** — filter to what the consumer needs

The critical principle: **decision-makers don't see raw inputs; they see prioritized, contextualized intelligence.** The research phase should collect broadly but filter aggressively before surfacing.

### BLUF (Bottom Line Up Front)

Military/intelligence standard: lead with the conclusion, not the evidence. For adjacent findings, this means each one should open with "You should know X because it affects Y" — not "I found an interesting thing about X."

---

## 2. T-Shaped Knowledge and Research Breadth

### The T-Shape Applied to Research Output

The T-shaped model (deep expertise + broad awareness) maps well to what a research phase should produce:

- **Vertical bar:** Deep findings on the specific question asked — this is the primary output
- **Horizontal bar:** Adjacent awareness that connects the specific question to neighboring concerns

Research shows that breadth enhances depth by providing more mental frameworks for connecting new specialized knowledge. This is the core argument *for* adjacent discovery — it's not noise if it provides scaffolding for better understanding the primary findings.

### "Need to Know" vs. "Nice to Know"

No formal framework emerged from the literature specifically distinguishing these in research contexts. However, the consulting and intelligence disciplines converge on a practical heuristic:

- **Need to know:** Would change a decision, block progress if missing, or prevent a costly mistake
- **Nice to know:** Adds context that enriches understanding but doesn't alter the action plan

For Cortex, "need to know" adjacent findings get surfaced inline. "Nice to know" findings get stashed (possibly in a collapsible section or appendix) for the user who wants to go deeper.

### McKinsey Pyramid Principle

Consultants use the **Pyramid Principle** (Barbara Minto, McKinsey) to filter what context reaches the client:

1. **Lead with the answer** — the recommendation comes first
2. **Group supporting arguments** — 3-5 logically distinct reasons
3. **Evidence underneath** — only if the reader drills down

The **SCQA framework** (Situation, Complication, Question, Answer) structures the context that *does* get included. Context is included only when it establishes why the answer matters.

For adjacent findings, this suggests a layered structure:
- **Layer 1:** One-sentence finding + why it matters (always visible)
- **Layer 2:** Supporting evidence (on request)
- **Layer 3:** Full research trail (archived)

---

## 3. Anti-Patterns

### Kitchen Sink Research

Surfacing everything tangentially related. The failure mode is treating completeness as quality. The VOI framework directly counters this: if it wouldn't change a decision, it doesn't belong.

### Apophenia / False Pattern Recognition

Seeing meaningful connections between unrelated things. In a research context, this manifests as:
- "This library also does X, which reminds me of Y" — when X and Y share surface similarity but no causal connection
- Treating co-occurrence as correlation
- Overfitting patterns from small samples of search results

**Countermeasure:** Require a causal or logical chain between the adjacent finding and the user's actual decision. "X is related to Y because Z" where Z is a mechanism, not a vibe.

Scientific apophenia is particularly dangerous with large datasets and broad searches — exactly what a research phase does. Rigorous statistical thinking and explicit connection criteria are the main defenses.

### Genericness

"You should also consider scalability" or "Don't forget about security" — findings so general they apply to any project. The specificity test: **could this finding apply to 80%+ of projects? If yes, it's generic and should be filtered out.**

### Information Overload

Research is clear: when input exceeds processing capacity, decision quality drops. The optimal response is not "provide everything and let the user filter" — it's "filter before exposure." Overload coping strategies split into:

- **Excluding strategies:** Ignoring, filtering (reduce quantity)
- **Including strategies:** Customizing, saving (manage complexity)

The research phase should use excluding strategies on behalf of the user, not delegate filtering to them.

---

## 4. Scoring/Ranking Adjacent Findings

### Proposed Scoring Dimensions

Based on the converged literature, four dimensions capture the quality of an adjacent finding:

| Dimension | Question | Score 0 (filter out) | Score 1 (surface) |
|-----------|----------|---------------------|-------------------|
| **Impact** | Would this change a decision? | Same decision either way | Would alter approach, choice, or priority |
| **Novelty** | Does the user likely already know this? | Common knowledge in their domain | Unlikely to have encountered this |
| **Specificity** | Is this concrete or generic? | Applies to 80%+ of projects | Specific to this problem, stack, or context |
| **Timeliness** | Is this relevant now? | Relevant later or theoretically | Affects the current phase or imminent decision |

**Minimum threshold:** A finding should score 1 on Impact AND at least one other dimension to be surfaced. Impact alone is necessary but not sufficient (because a high-impact but obvious finding is just noise).

### Information-Theoretic Surprise

Shannon's information theory formalizes the intuition that surprising = informative. Self-information (surprisal) is higher for low-probability events. But raw improbability isn't enough — **Bayesian surprise** (KL divergence between prior and posterior beliefs) is the better measure. A finding is truly surprising only if it would update the user's beliefs.

This maps to the scoring model: **Novelty x Impact = Bayesian surprise.** A finding that's novel but irrelevant (high Shannon surprise, low belief update) is trivia. A finding that's relevant but known (high impact, low novelty) is redundant.

### Recommendation System Parallels

RecSys research on exploration vs. exploitation is directly relevant:

- **Exploitation:** Surface findings the user would expect and confirm their approach — safe but low value-add
- **Exploration:** Surface findings that challenge assumptions or introduce new considerations — risky but high potential value

The serendipity metric from RecSys captures what good adjacent discovery should feel like: "pleasantly surprised by something you wouldn't have thought of but still resonates with your interests." The tradeoff: too much exploration feels irrelevant; too much exploitation feels obvious.

**Entropy sampling** balances relevance and surprise by adjusting the diversity of recommendations. With too low expected surprise, recommendations look boring; too high, they look irrelevant. This is the same dial Cortex needs to tune.

---

## 5. Implementation Patterns

### How Many Adjacent Findings?

**Miller's Law** (1956): working memory holds 7 plus or minus 2 items. Modern research revises this to **4 plus or minus 1** for complex/novel information. Since adjacent findings are by definition outside the user's primary focus, they're novel — so the lower bound applies.

**Recommendation: 1-3 adjacent findings per research pass.** Rationale:
- 1 feels intentional, not noisy
- 3 is the upper bound before cognitive load degrades the primary research output
- 0 is valid — not every research pass has decision-relevant adjacencies

Never pad to a fixed number. If nothing passes the scoring threshold, surface nothing.

### Should Findings Include Relevance Justification?

Yes, mandatory. Based on BLUF and the "So What?" test, each adjacent finding should include:

1. **The finding** (one sentence)
2. **Why it matters to this specific task** (one sentence mapping to a decision)
3. **Source** (link or reference)

Without the "why it matters" sentence, users can't efficiently evaluate whether to engage. The intelligence community learned this: analysts who present facts without assessments waste their consumers' time.

### Layered Disclosure Pattern

Based on the Pyramid Principle and progressive disclosure research:

- **Always visible:** Finding + relevance justification (2 sentences)
- **On expand:** Supporting evidence, tradeoffs, alternatives
- **On deep dive:** Full research trail, raw sources, methodology

This mirrors how the President's Daily Brief works: headline assessment up front, supporting detail available on request, full intelligence report in the archive.

### Examples of This Done Well vs. Poorly

**Well (hypothetical):**
> "Adjacent: The `zod` library you're using for validation has a known performance cliff above 10k validations/sec (issue #1234). Your Kalshi polling interval would hit this at scale. Consider `valibot` as a drop-in alternative with 3x throughput."

Why it works: specific to the project, maps to a decision (library choice), includes the threshold where it matters, offers an alternative.

**Poorly (hypothetical):**
> "Adjacent: You might also want to consider error handling best practices when building API integrations."

Why it fails: generic (applies to every API project), no specific finding, no decision impact, no source.

---

## 6. Synthesis: The Adjacent Discovery Filter Pipeline

```
Research findings
    |
    v
[1] Decision-relevance gate: Would this change a decision?
    |-- No --> archive silently
    |-- Yes/Maybe --> continue
    v
[2] Specificity gate: Is this specific to THIS project/context?
    |-- No (generic) --> archive silently
    |-- Yes --> continue
    v
[3] Novelty check: Does the user likely already know this?
    |-- Yes (obvious) --> archive silently
    |-- No/Uncertain --> continue
    v
[4] Timeliness check: Is this relevant NOW vs. later?
    |-- Later --> stash with trigger condition
    |-- Now --> continue
    v
[5] Format as BLUF: Finding + Why-it-matters + Source
    |
    v
[6] Cap at 3 max per research pass
    |-- If >3 pass filter, rank by Impact * Novelty, take top 3
    v
Output: 0-3 adjacent findings in research report
```

---

## Sources

- [Value of Information — Wikipedia](https://en.wikipedia.org/wiki/Value_of_information)
- [VOI: Four Examples — LessWrong](https://www.lesswrong.com/posts/vADtvr9iDeYsCDfxd/value-of-information-four-examples)
- [A Practical Guide to VOI Analysis — PharmacoEconomics](https://link.springer.com/article/10.1007/s40273-014-0219-x)
- [EVPI — Wikipedia](https://en.wikipedia.org/wiki/Expected_value_of_perfect_information)
- [EVPI Decision Making — Dartmouth](https://cushman.host.dartmouth.edu/courses/engs41/Value-of-info.pdf)
- [Value of Information and Decision Pathways — Frontiers](https://www.frontiersin.org/journals/environmental-science/articles/10.3389/fenvs.2022.805214/full)
- [Intelligence Briefing Preparation — DataCalculus](https://datacalculus.com/en/blog/armed-forces/military-intelligence-analyst/military-intelligence-analyst-intelligence-briefing-preparation)
- [Intelligence Briefing — Grey Dynamics](https://greydynamics.com/glossary/intelligence-briefing/)
- [How to Build an Intelligence Report — Octopus CI](https://www.octopusintelligence.com/how-to-build-an-intelligence-report/)
- [BLUF Writing Format — Illinois Physics](https://courses.physics.illinois.edu/phys280/sp2022/docs-for-assignments/BLUF%20Writing%20Format.pdf)
- [BLUF — Wikipedia](https://en.wikipedia.org/wiki/BLUF_(communication))
- [Report Writing for Intelligence — SpecialEurasia](https://www.specialeurasia.com/2024/11/27/report-writing-for-intelligence/)
- [The Pyramid Principle — McKinsey's Secret](https://winningpresentations.com/pyramid-principle-presentations/)
- [The Pyramid Principle — Slideworks](https://slideworks.io/resources/the-pyramid-principle-mckinsey-toolbox-with-examples)
- [Pyramid Principle Applied — ManagementConsulted](https://managementconsulted.com/pyramid-principle/)
- [Dealing with Information Overload — PMC/Frontiers](https://pmc.ncbi.nlm.nih.gov/articles/PMC10322198/)
- [Information Overload — Wikipedia](https://en.wikipedia.org/wiki/Information_overload)
- [Cognitive Load Theory — ScienceDirect](https://www.sciencedirect.com/topics/psychology/cognitive-load-theory)
- [Miller's Law — Laws of UX](https://lawsofux.com/millers-law/)
- [The Magical Number Seven — Wikipedia](https://en.wikipedia.org/wiki/The_Magical_Number_Seven,_Plus_or_Minus_Two)
- [Apophenia — Wikipedia](https://en.wikipedia.org/wiki/Apophenia)
- [Apophenia as False Positives — PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC7112154/)
- [Apophenia — Psychology Today](https://www.psychologytoday.com/us/basics/apophenia)
- [T-Shaped Skills Profile Framework — ResearchGate](https://www.researchgate.net/publication/383779500_Shaping_the_Knowledge_Worker_Through_a_T-shaped_Skills_Profile_Framework)
- [T-Shaped Person — College Info Geek](https://collegeinfogeek.com/become-t-shaped-person/)
- [Exploration-Exploitation in RecSys — ACM](https://dl.acm.org/doi/10.1145/3109859.3109866)
- [Beyond-Accuracy: Diversity, Serendipity, Fairness — Frontiers/PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC10762851/)
- [Serendipity in RecSys — Shaped](https://www.shaped.ai/blog/not-your-average-recsys-metrics-part-1-serendipity)
- [Entropy Sampling for Relevance and Surprise — Medium](https://medium.com/@reika.k.fujimura/entropy-sampling-how-to-balance-relevance-and-surprise-in-recommendation-2223417a38ce)
- [Information is Surprise — Plus Maths](https://plus.maths.org/content/information-surprise)
- [Information Theoretic Uncertainty and Surprise — Frontiers](https://www.frontiersin.org/articles/10.3389/frai.2020.00005/full)
- [Shannon Entropy — Quanta Magazine](https://www.quantamagazine.org/how-claude-shannons-concept-of-entropy-quantifies-information-20220906/)
