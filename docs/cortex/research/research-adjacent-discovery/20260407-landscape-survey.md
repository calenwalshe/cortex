# Adjacent Discovery: Landscape Survey

**Date:** 2026-04-07
**Scope:** How existing search engines, AI research tools, intelligence tradecraft, information science, and prompt engineering handle the problem of surfacing related knowledge the user didn't explicitly ask about.

---

## 1. Search Engine "Related" Features

### Perplexity AI — "Related Questions"

**Mechanism:** After answering a query, Perplexity generates follow-up questions using its understanding of query intent plus the source material it retrieved. The system uses RAG (Retrieval-Augmented Generation) — it searches the web in real-time, identifies 20-50 top sources by keyword match, authority, recency, and relevance, feeds the context to its LM, and generates the response plus follow-up suggestions.

**Quality assessment:** The related questions are context-aware and intent-derived, not keyword-stuffed SEO bait. The Copilot feature guides multi-step reasoning by proposing follow-ups that narrow or deepen the topic. However, Perplexity keeps the exact generation algorithm proprietary — no published details on the model architecture for related question generation specifically.

**Adjacent discovery value:** Moderate. The questions tend to be logical next-steps rather than genuinely surprising adjacent knowledge. They follow the user's apparent trajectory rather than challenging it.

**Sources:**
- [Perplexity AI Guide 2026](https://notiongraffiti.com/perplexity-ai-guide-2026/)
- [Perplexity AI Review 2025](https://www.glbgpt.com/hub/perplexity-ai-review-2025/)
- [Perplexity Deep Research](https://www.perplexity.ai/hub/blog/introducing-perplexity-deep-research)

### Google — "People Also Ask" (PAA)

**Mechanism:** Machine learning analyzes actual user search patterns — what people search for after their initial query. The algorithm uses:
1. **Query log mining:** Tracks sequential searches across users to identify common follow-up questions
2. **Entity recognition:** Understands entities and relationships (searching "install kitchen cabinets" connects to entities like "kitchen," "cabinets," "installation," "home improvement")
3. **Semantic models:** Groups frequent follow-up questions using semantic similarity, not just keyword overlap
4. **Personalization signals:** Location, device, search history, browsing history influence which PAA questions appear
5. **Dynamic updating:** PAA boxes morph throughout the day, adding/swapping questions based on real-time user behavior

**Quality assessment:** PAA questions are genuinely useful for discovering what other people wanted to know about the same topic. They represent aggregated user curiosity, not algorithmic guesswork. The weakness: they optimize for common questions, not surprising ones. High-frequency questions dominate; edge-case insights are filtered out by the popularity signal.

**Adjacent discovery value:** Low-to-moderate for experts (surfaces common questions they already know the answers to), higher for novices entering a new domain.

**Sources:**
- [Google PAA Overview — iMark Infotech](https://www.imarkinfotech.com/googles-paa-people-also-ask-what-you-need-to-know/)
- [PAA SEO Guide 2026 — ReputationX](https://www.reputationx.com/blog/googles-also-ask)
- [PAA SEO Strategy — Search Engine Land](https://searchengineland.com/guide/people-also-ask)
- [AlsoAsked — PAA Research Tool](https://alsoasked.com)

### Bing/Copilot — Related Suggestions

**Mechanism:** Copilot Search generates clickable topic suggestions after each answer. Clicking a topic triggers a follow-up search with results summarized inline, preserving the context of the original search. Additional suggestions cascade from each follow-up, creating a multi-turn exploration flow.

Under the hood, Copilot Search issues "additional search queries on the user's behalf" beyond the original query, pulling both information and sources. Previous results remain accessible on the same page for cross-referencing.

**Quality assessment:** The multi-turn design is good — it encourages depth without losing context. But the mechanism is closer to "guided browsing" than genuine adjacent discovery. The suggestions follow the user's trajectory rather than introducing orthogonal perspectives.

**Sources:**
- [Introducing Copilot Search in Bing](https://blogs.bing.com/search/April-2025/Introducing-Copilot-Search-in-Bing)
- [Copilot Search — Microsoft](https://www.microsoft.com/en-us/bing/copilot-search)

### Tavily Search API

**Mechanism:** Tavily provides four endpoints: search, extract, map, and crawl. The search endpoint returns query, answer (optional LLM-generated), ranked results (title, URL, content, relevance score), and images. The Research endpoint performs iterative multi-search with reasoning and deduplication.

**Adjacent discovery value:** None built-in. Tavily returns direct results only — no related topics, follow-up queries, or adjacent content suggestions in the API response. It's a retrieval engine, not a discovery engine. Any adjacent discovery would need to be built on top by the consuming application.

**Key detail:** Nebius acquired Tavily in February 2026, which may affect future development direction.

**Sources:**
- [Tavily Search API Reference](https://docs.tavily.com/documentation/api-reference/endpoint/search)
- [Tavily 101 — Developer Guide](https://www.tavily.com/blog/tavily-101-ai-powered-search-for-developers)
- [Best Web Search APIs 2026](https://www.firecrawl.dev/blog/best-web-search-apis)

---

## 2. AI Research Assistant Approaches

### Gemini Deep Research

**Breadth vs. depth strategy:** Gemini creates a custom research plan that starts with general context and narrows into details. At each step, the model grounds itself on all information gathered so far, then identifies missing information and discrepancies to explore — while trading off comprehensiveness against compute and wait time.

**Proactive adjacent exploration:** Explicit. Gemini proactively suggests related resources in reports — interactive charts, planning simulators, and additional deep dives into relevant topics. Users can request more depth on specific subtopics, and Gemini will run additional searches and update its report.

**Key mechanism:** Multi-step iterative planning where each iteration reassesses what's missing. This is the closest existing product to genuine adjacent discovery — the model actively looks for gaps in its own coverage.

**Sources:**
- [Gemini Deep Research Overview](https://gemini.google/overview/deep-research/)
- [Deep Research Guide 2025 — DigitalApplied](https://www.digitalapplied.com/blog/google-gemini-deep-research-guide)
- [Google Blog — Deep Research](https://blog.google/products/gemini/google-gemini-deep-research/)
- [Gemini Deep Research API](https://ai.google.dev/gemini-api/docs/deep-research)

### Elicit.org

**Discovery mechanism:** Semantic search over 138M academic papers (via OpenAlex and Semantic Scholar). The key feature: you don't need the right keywords. Elicit's semantic search finds papers even when they don't overlap in keywords with the query. This is a genuine adjacent discovery mechanism — it surfaces papers the user couldn't have found through keyword-based searching because they didn't know the vocabulary of the adjacent field.

**Scale:** Surfaces and analyzes up to 1,000 papers at once. Extracts key information and summarizes takeaways specific to the user's question.

**Limitation:** Discovery is still query-anchored. Elicit finds papers related to what you asked, not papers related to what you *should have* asked. The semantic space is explored around the query vector, not orthogonal to it.

**Sources:**
- [Elicit — AI for Scientific Research](https://elicit.com/)
- [Elicit Paper Search](https://elicit.com/solutions/search)
- [Elicit Source for Papers](https://support.elicit.com/en/articles/553025)
- [Elicit vs Semantic Scholar vs Perplexity Comparison](https://medium.com/@jabed.akib.iitd/i-tested-elicit-semantic-scholar-and-perplexity-for-academic-research-heres-what-actually-63b216aa12ee)

### Semantic Scholar — SPECTER and Citation Graphs

**Core algorithm:** SPECTER (Document-level Representation Learning using Citation-informed Transformers) generates paper embeddings by pretraining a Transformer on citation graph signals. Direct citations are used as positive training examples; citations-of-citations as weaker signals. The resulting embeddings capture document-level relatedness that goes beyond keyword or abstract similarity.

**Related papers mechanism:** Cosine similarity between SPECTER embeddings, combined with other features (title/author similarity, reference overlap, citation overlap). The citation graph provides a powerful signal — papers that are cited together tend to be intellectually related even if they use different terminology.

**Adjacent discovery value:** High for academic research. The citation graph captures intellectual lineage and cross-pollination that keyword search misses entirely. Two papers can be deeply related through shared citations even if they never use the same terms.

**Extensions:** PR-SGCN combines SPECTER with Graph Convolutional Networks to address cold-start problems (new papers with no citations yet).

**Sources:**
- [SPECTER Paper — ACL 2020](https://arxiv.org/abs/2004.07180)
- [SPECTER GitHub — Allen AI](https://github.com/allenai/specter)
- [Semantic Scholar Academic Graph API](https://api.semanticscholar.org/api-docs)
- [SPECTER-BS Citation Recommendation](https://link.springer.com/article/10.1007/s10115-025-02677-y)

### Consensus.app

**Discovery pipeline:**
1. Hybrid search: semantic (AI embeddings for intent) + keyword (BM25 for precision) across 200M scientific papers
2. Top 1,500 papers re-ranked by research quality, not just query relevance
3. Deep Search runs up to 20 targeted searches with varied strategies, reviews top 1,000 results, screens to top 50

**Adjacent discovery features:**
- AI-generated visuals showing consensus among research, key authors, and extracted claims
- Integration of Semantic Scholar's "Influential Citations" — pivotal papers that shaped a research area
- Knowledge gap identification: surfaces where research is missing or contradictory

**Key insight:** The varied search strategy in Deep Search (20 different queries) is an explicit adjacent discovery mechanism. By reformulating the question multiple ways, it reaches papers that a single query formulation would miss.

**Sources:**
- [Consensus — AI for Research](https://consensus.app/)
- [Consensus Deep Search](https://consensus.app/home/blog/deep-search/)
- [Consensus Research Database](https://help.consensus.app/en/articles/10055108-consensus-research-database)

### Connected Papers and Research Rabbit

**Connected Papers:** Displays an unordered graph of papers related to a single seed paper, with connections based on citation overlap. Good for quickly seeing the "core cluster" around a specific paper. Single-paper input, no customization.

**Research Rabbit:** Collection-based discovery — input multiple papers, get suggestions based on the collection. Traces search iterations and lets you revisit earlier steps. Every search iteration is saved. Better for ongoing research projects and expanding outward across authors and citation chains.

**Key distinction:** Connected Papers is for scoping ("what's the landscape around this paper?"). Research Rabbit is for exploration ("what should I read next given everything I've read so far?"). Research Rabbit's collection-based approach is closer to genuine adjacent discovery because it can identify papers at the intersection of multiple topics.

**Sources:**
- [Connected Papers vs Research Rabbit 2026](https://papersflow.ai/blog/connected-papers-vs-research-rabbit)
- [Litmaps vs ResearchRabbit vs Connected Papers 2025](https://effortlessacademic.com/litmaps-vs-researchrabbit-vs-connected-papers-the-best-literature-review-tool-in-2025/)
- [Research Rabbit](https://www.researchrabbit.ai/)

---

## 3. Intelligence Analyst Tradecraft

### CIA Outside-In Thinking

**What it is:** A structured analytic technique (SAT) for broadening analytical perspective. Most analysts focus on factors familiar to them within their field — they think "inside-out" from their expertise. Outside-In Thinking forces the reverse: examine all variables from global, political, social, legal, environmental, economic, and technological perspectives.

**Purpose:** Discover factors, significant dynamics, or pertinent alternative hypotheses that domain-focused analysis would miss. The technique requires participants to broaden their perspective to a larger contextual and conceptual framework.

**Application to research tools:** Outside-In Thinking is a checklist-driven expansion technique. For a research agent, this translates to: given the user's question, systematically check whether political, economic, technological, legal, social, or environmental factors have been considered. If any domain hasn't been explored, flag it.

**Sources:**
- [CIA Tradecraft Primer (PDF)](https://www.cia.gov/resources/csi/static/Tradecraft-Primer-apr09.pdf)
- [Structured Analytic Techniques — Canvalytic](https://www.canvalytic.com/post/what-are-structured-analytic-techniques-and-why-does-the-cia-use-them)
- [SATs Guide — Grey Dynamics](https://greydynamics.com/a-guide-to-structured-analytic-techniques-sats-for-intelligence/)

### Indicators and Warnings (I&W) Framework

**Core methodology:** Decompose an anticipated scenario into indicators that can be continuously monitored. Seven steps:
1. Identify and prioritize assets
2. Prioritize the threat
3. Assess threat courses of action
4. Decompose scenarios into indicators
5. Plan and exercise countermeasures
6. Align to the intelligence cycle
7. Execute proactive measures

**How it detects the unexpected:** Analysts determine whether each indicator is "active" or "dormant" — dormant indicators are signals that would become relevant if certain conditions change. The framework is not meant to predict specific events but to warn that the probability of a risk event is increasing or decreasing.

**Modern extensions:** Examine actors through motive, conditions, opportunity, triggers, and trajectory to build a broad picture of emerging situations.

**Critical gap identified:** The IC places disproportionate emphasis on current intelligence over long-term I&W analyses. I&W is often treated as "an additional duty or afterthought" — the most significant obstacle to accuracy.

**Application to research tools:** The I&W decomposition approach maps to research: identify what signals would indicate your assumptions are wrong, then monitor for those signals. A research agent could generate "indicator questions" — things that, if true, would fundamentally change the research conclusion.

**Sources:**
- [I&W Methodology for Strategic Intelligence — HSAJ](https://www.hsaj.org/articles/14420)
- [INSA Framework for Cyber I&W](https://www.insaonline.org/docs/default-source/default-document-library/2022-white-papers/insa-framework-for-cyber-indications-and-warning.pdf)
- [I&W for Cyber Incidents — CCDCOE](https://www.ccdcoe.org/uploads/2019/06/Art_05_Applying-Indications-and-Warning-Frameworks-to-Cyber-Incidents.pdf)
- [Threat Intelligence — AMU](https://www.amu.apus.edu/area-of-study/intelligence/resources/threat-intelligence/)

### Mirror Imaging — The Central Cognitive Trap

**Definition:** Assuming a subject will think and behave the same way the analyst would. Described as "without a doubt the most common error of intelligence-estimating" that "frequently results in gross distortions of intelligence."

**Why it matters for research tools:** An LLM doing research will mirror-image by default — it searches for what *it* thinks is relevant based on its training distribution, not what the *user's specific context* makes relevant. The model assumes the user's problem space looks like the average problem space it was trained on.

**Countermeasures from IC tradecraft:**

1. **Red Team Analysis:** Model the adversary's (or alternative stakeholder's) behavior by adopting their cultural, organizational, and personal setting. For research: explicitly adopt the perspective of someone who disagrees with the user's approach.

2. **Analysis of Competing Hypotheses (ACH):** Treat all plausible explanations equally. Don't try to prove one theory — instead, identify evidence that discriminates between hypotheses. Developed by Richards Heuer at CIA.

3. **Perspective-taking method:** Ask "How would I solve this?" then separately ask "How would [specific other actor] solve this?" — comparing the two reveals implicit assumptions.

4. **Supplementing personal experience:** Exposure to diverse viewpoints and domains reduces the tendency to project familiar patterns.

**Sources:**
- [Mirror-Imaging and Its Dangers — ResearchGate](https://www.researchgate.net/publication/236805126_Of_Note_Mirror-Imaging_and_Its_Dangers)
- [Mirror Imaging — Critical Thinking](https://www.howtogetyourownway.com/biases/mirror_imaging.html)
- [Psychology of Intelligence Analysis — CIA](https://www.cia.gov/resources/csi/static/Pyschology-of-Intelligence-Analysis.pdf)
- [15 Steps to Overcome Cognitive Bias — OSINTIA](https://osintia.com/15-essential-steps-to-overcome-cognitive-bias-in-intelligence-analysis-a-practical-guide/)

### Opportunity Analysis vs. Threat Analysis

**Core distinction:** Nations face both threats and opportunities under uncertainty, requiring different analytical tools for each.

- **Threat analysis:** Evaluate robustness against uncertainty while guaranteeing critical outcomes. The outcome is satisficed (adequate) while robustness to surprise is maximized. This is called **robust satisficing**.
- **Opportunity analysis:** Exploit favorable circumstances to facilitate better-than-anticipated outcomes. The outcome is maximized while accepting that guarantees are weaker.

**Why this matters for research:** Most research is threat-oriented ("what could go wrong? what are the risks?"). Opportunity analysis asks the inverse: "what favorable conditions exist that the user hasn't noticed? What adjacent developments could be exploited?" A research agent that only flags risks is doing half the job.

**Sources:**
- [Threats and Opportunities: Intelligence Analysis for Managing Uncertainty — Taylor & Francis](https://www.tandfonline.com/doi/full/10.1080/08850607.2022.2091415)

---

## 4. Information Science and Knowledge Management

### Serendipitous Information Discovery

**Definition (Agarwal):** "Serendipity as an incident-based, unexpected discovery of information when the actor is either in a passive, non-purposive state or in an active, purposive state, followed by a period of incubation leading to insight and value."

**Key distinction from accidental discovery:** Serendipity requires three elements that accidental discovery does not:
1. **Unexpectedness** — the information was not anticipated
2. **Insight** — the discoverer recognizes its significance
3. **Value** — it's useful, not just surprising

Greater degrees of each element indicate "purer" serendipity (Makri and Blandford framework).

**Two enabling scenarios:**
1. **Non-purposive state:** Finding information while not actively seeking anything (Newton observing gravity)
2. **Purposive state:** Finding different information while searching for something else (Fleming's penicillin)

**Precipitating conditions:** Social networking, active learning, and exploratory search behaviors. Serendipity is not always instant — a period of incubation is sometimes necessary before recognition.

**Application to tools:** "Information encountering" — passively finding unsought, unexpected information during active seeking — is the specific mechanism. Research tools can facilitate this by exposing the user to material adjacent to their query, not just material matching it.

**Sources:**
- [Towards a Definition of Serendipity in Information Behaviour](https://informationr.net/ir/20-3/paper675.html)
- [Down the Rabbit Hole: Disruption of Information Encountering](https://asistdl.onlinelibrary.wiley.com/doi/abs/10.1002/asi.24233)
- [Serendipity and Information Seeking — ResearchGate](https://www.researchgate.net/publication/37146876_Serendipity_and_Information_Seeking_An_Empirical_Study)
- [Spark — Serendipitous Knowledge Discovery](https://www.sciencedirect.com/science/article/pii/S1532046415002944)

### Information Foraging Theory

**Core principle (Pirolli & Card):** When people look for information, they attempt to maximize the rate of information gain over time — get as much information as possible in the minimum time. This is modeled on optimal foraging theory from ecology (how animals maximize caloric intake).

**Key concepts:**
- **Information scent:** Cues that indicate the value of following a particular path (like link text, headings, snippets). Strong scent keeps the user moving forward; weak scent causes abandonment.
- **Information patches:** Clusters of related content. Users forage within a patch until diminishing returns, then move to a new patch.
- **Sensemaking interaction:** Information foraging feeds into sensemaking (deriving meaning from new information). Together they form a feedback loop: foraging provides raw material, sensemaking structures it, which then redirects foraging.

**Application to adjacent discovery:** A research tool should provide strong information scent for adjacent findings — clear signals of why following that thread would be valuable. Without scent, users rationally ignore adjacent material (the foraging cost exceeds expected gain). The BLUF format from the filtering research directly addresses this: the "why it matters" sentence IS the information scent.

**Sources:**
- [Information Foraging Theory — IxDF](https://ixdf.org/literature/book/the-glossary-of-human-computer-interaction/information-foraging-theory)
- [Information Foraging — Nielsen Norman Group](https://www.nngroup.com/articles/information-foraging/)
- [Information Foraging — Peter Pirolli](https://www.peterpirolli.com/ewExternalFiles/31354_C01_UNCORRECTED_PROOF.pdf)
- [Information Foraging — ScienceDirect Overview](https://www.sciencedirect.com/topics/computer-science/information-foraging)

### The Adjacent Possible (Stuart Kauffman)

**Core concept:** At any given moment, a system has a limited number of real options for what it can become next. But every time a new option is explored, the space of future possibilities expands. You cannot leap to distant futures; you must move through adjacent, reachable possibilities. Each step taken expands the neighboring possibility space.

**The room metaphor:** Imagine rooms connected by doors. You can only enter rooms directly connected to your current location, but each new room opens additional doorways you couldn't previously see.

**Steven Johnson's extensions:**
- The "shadow future" — the evolving frontier hovering just beyond the present
- Innovation emerges from recombining existing adjacent elements
- Breakthroughs are rarely instantaneous; they result from incremental steps through the adjacent possible

**Applied to research evaluation:** Adjacent possibilities are key to understanding scientific development driven by the appearance/disappearance of research topics. "Cognitive distance" measures the adjacency of knowledge — how far a new finding is from what the user already knows. Too far = incomprehensible. Too close = obvious. The sweet spot is the immediately adjacent possible.

**Application to research tools:** The adjacent possible provides a formal framework for what "good adjacent discovery" means: findings that are one step beyond the user's current knowledge, opening doors they didn't know existed. Not findings from five rooms away (incomprehensible without intermediate context) and not findings from the room they're already in (obvious).

**Sources:**
- [Adjacent Possible — Conversational Leadership](https://conversational-leadership.net/adjacent-possible/)
- [Stuart Kauffman TED Talk — The Adjacent Possible](https://www.ted.com/talks/stuart_kauffman_the_adjacent_possible_and_how_it_explains_human_innovation)
- [Adjacent Possible and Research Evaluation — CWTS](https://www.cwts.nl/blog?article=n-r2w294)
- [The Adjacent Possible — Edge.org](https://www.edge.org/conversation/stuart_a_kauffman-the-adjacent-possible)
- [Harnessing Functional Excess — SSRN](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4374767)

### Bisociation (Arthur Koestler)

**Definition:** The simultaneous perception of a situation within "two self-consistent but habitually incompatible frames of reference." Unlike ordinary association (which operates within a single mental plane), bisociation brings together independent, autonomous matrices that developed separately.

**Three domains:**
1. **Humor:** Pun as proof — "two strings of thought tied together by an acoustic knot"
2. **Science:** Permanent integration of separate frameworks into unified code (electricity + magnetism = electromagnetism). Creates cumulative hierarchical knowledge.
3. **Art:** Juxtaposition without fusion — maintains matrices as distinct sensory/emotional experiences

**Why it matters for knowledge discovery:** Minor bisociative processes are "the main vehicle of untutored learning." But objective novelty comes into being only when subjective originality operates on the highest level of existing knowledge hierarchies. The implication: adjacent discovery that produces genuine insight requires connecting two well-developed knowledge domains, not just two random facts.

**Application to research tools:** A research tool could explicitly look for bisociative connections — findings from Domain A that share structural patterns with the user's Domain B, even when the two domains don't share vocabulary. Semantic Scholar's SPECTER embeddings approach this by capturing citation-graph relatedness that transcends keyword overlap. The deeper application: prompt a model to identify which of its findings come from a fundamentally different frame of reference than the user's question, and articulate the structural parallel.

**Sources:**
- [Koestler's Theory of Bisociation — The Marginalian](https://www.themarginalian.org/2013/05/20/arthur-koestler-creativity-bisociation/)
- [The Act of Creation — Wikipedia](https://en.wikipedia.org/wiki/The_Act_of_Creation)
- [Bisociation — Edge.org](https://www.edge.org/response-detail/27080)
- [Bisociation — Grand O Mastery](https://www.grandomastery.com/post/bisociation-the-forgotten-architecture-of-creative-breakthroughs)
- [Towards Creative Information Exploration Based on Bisociation — ResearchGate](https://www.researchgate.net/publication/233841538_Towards_Creative_Information_Exploration_Based_on_Koestler's_Concept_of_Bisociation)

---

## 5. Prompt Engineering for "What Else Should I Know"

### Techniques That Work

**1. Steelman the alternative:**
Instruct the model to: (a) identify the stance inferred from the prompt, (b) construct the strongest possible argument for the opposite view with equal detail, (c) identify which evidence was excluded in the first version. Daniel Dennett's protocol: re-express the other position so clearly they'd say "I wish I'd thought of putting it that way," list points of agreement, mention what you learned, and only then rebut.

**2. "What would a domain expert be surprised I didn't ask?":**
This framing works because it activates domain-specific knowledge the model has but wouldn't surface unprompted. The key: specify the domain expert type ("What would a distributed systems engineer be surprised I didn't ask?" vs. generic "What am I missing?"). Specificity prevents generic filler.

**3. Analytic hints injection (IBM Research, AAAI 2026):**
Domain experts identify recurring LLM blind spots, then inject these as "analytic hints" into prompts. Results: LLMs alone detect ~45% of errors; with hints, up to 94% coverage. The technique: flag domain-specific issues and dynamically inject them to guide the model toward known blind spots.

**4. Self-correction via "Wait" prompt:**
Appending a minimal "Wait" trigger to LLM output activates an 89.3% reduction in blind spots. The mechanism: it triggers the model's latent self-correction capabilities that otherwise remain dormant. Minimal prompt, maximal effect.

**5. Unverbalized bias detection pipeline (2026 research):**
Automated system that discovers what LLMs systematically consider but never mention in their reasoning. Uses paired input variations to test whether changing a factor changes the output, then checks whether that factor appears in the model's stated reasoning. Key finding: models construct post-hoc rationalizations — identical inputs get reframed differently depending on hidden factors the model won't cite.

### Techniques That Fail

**1. Generic "what am I missing?" prompts:**
Without domain specificity, these produce platitudes: "Don't forget about scalability," "Consider security implications." The genericness test: if the advice applies to 80%+ of projects, it's noise.

**2. Open-ended "explore related topics":**
Produces kitchen-sink output — everything tangentially related, with no filtering for decision-relevance. The model treats completeness as quality.

**3. "Give me your honest opinion":**
Models default to hedging and balanced presentation. "Honest opinion" doesn't override this tendency. What works instead: "State your position and what evidence would change your mind."

### Good vs. Bad Adjacent Discovery in LLM Outputs

**Good example:**
> "The `zod` library you're using for validation has a known performance cliff above 10k validations/sec (issue #1234). Your Kalshi polling interval would hit this at scale. Consider `valibot` as a drop-in alternative with 3x throughput."

Why: specific to the project, maps to a decision (library choice), includes the threshold where it matters, offers an alternative.

**Bad example:**
> "You might also want to consider error handling best practices when building API integrations."

Why: generic (applies to every API project), no specific finding, no decision impact, no source.

**The pattern:** Good adjacent discovery is specific, decision-relevant, and actionable. Bad adjacent discovery is generic, universally applicable, and informational without being actionable.

**Sources:**
- [Steelmanning Technique](https://conversion-rate-experts.com/steel-manning/)
- [Steelmanning — The Mind Collection](https://themindcollection.com/steelmanning-how-to-discover-the-truth-by-helping-your-opponent/)
- [Beyond Blind Spots: Analytic Hints — IBM/AAAI 2026](https://arxiv.org/abs/2512.16272)
- [Biases in the Blind Spot: Detecting What LLMs Fail to Mention](https://arxiv.org/abs/2602.10117)
- [Thought Space Explorer — Blind Spot Navigation](https://arxiv.org/html/2410.24155)
- [Prompt Engineering Guide 2026 — Lakera](https://www.lakera.ai/blog/prompt-engineering-guide)

---

## 6. Cross-Cutting Synthesis

### What the best systems have in common

1. **Multi-query reformulation:** Consensus (20 varied searches), Gemini Deep Research (iterative replanning), and the IC's Outside-In Thinking all share the same core mechanism — approach the question from multiple angles rather than optimizing a single query.

2. **Graph-based discovery over keyword matching:** Semantic Scholar's SPECTER embeddings, Connected Papers' citation graphs, and Research Rabbit's collection-based suggestions all leverage relational structure (who cites whom, what appears alongside what) rather than surface-level text similarity.

3. **Filtering is as important as discovery:** The IC's "So What?" test, VOI framework, and BLUF format (from the prior research) all emphasize that surfacing everything is worse than surfacing nothing. The value is in the filter, not the search.

4. **Cognitive distance calibration:** Kauffman's adjacent possible and information foraging theory converge on the same insight — findings need to be close enough to be comprehensible but far enough to be surprising. SPECTER embeddings implicitly capture this through citation-graph distance.

### What no existing system does well

1. **Bisociative discovery:** No tool systematically connects findings from fundamentally different frames of reference. Semantic Scholar gets closest through citation-graph embeddings, but it operates within academic literature only. Cross-domain bisociation (connecting a biology paper's methodology to a software architecture problem) remains a human capability.

2. **Opportunity analysis:** Every tool is optimized for answering questions (threat/risk framing). None proactively surfaces favorable conditions the user hasn't noticed. The IC's opportunity analysis framework exists in theory but is underused even by analysts.

3. **Indicator generation:** The I&W framework's approach — decompose your assumptions into falsifiable indicators and monitor them — has no equivalent in any research tool. No tool generates "here's what would prove your approach wrong" indicators.

4. **Mirror-imaging correction:** No research tool accounts for the fact that its search strategy reflects its own training distribution, not the user's actual problem space. ACH (Analysis of Competing Hypotheses) could be implemented but isn't.

### Implications for implementation

The strongest adjacent discovery mechanism available today is: **multi-angle query reformulation** (approach the question from 3-5 different disciplinary perspectives) + **graph-based relatedness** (use citation/reference structure, not just text similarity) + **aggressive filtering** (VOI gate + specificity gate + BLUF formatting). This combination doesn't require novel research — it combines existing techniques that no single tool currently integrates.
