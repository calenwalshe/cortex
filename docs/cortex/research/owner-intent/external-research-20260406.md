# Owner Intent — External Research Dossier

**Slug:** owner-intent
**Phase:** concept (external)
**Date:** 2026-04-06
**Status:** complete

---

## Research Objective

Survey how production AI agent systems and frameworks model owner/user intent, goals, and preferences. Identify patterns, formats, schemas, and mechanisms that Cortex can adopt or adapt for the owner-intent slug.

---

## 1. Principal Hierarchy Models

### 1.1 OpenAI Model Spec — 4-Level Authority Chain

**Source:** [OpenAI Model Spec (2025/04/11)](https://model-spec.openai.com/2025-04-11.html)

OpenAI structures intent through a chain of command with escalating authority:

1. **Platform** (Model Spec itself) — non-negotiable, cannot be overridden
2. **Developer** (API system messages) — can override user and guideline levels
3. **User** (end-user requests) — can override guideline level only
4. **Guideline** (default behaviors) — lowest authority, implicitly overridable

Conflict resolution rules:
- When two platform-level principles conflict, default to inaction
- Later instructions at the same level supersede earlier ones
- Untrusted data (tool outputs, quoted text, images) has **no inherent authority** — requires explicit delegation

The latest versions (2025/12) refined this to: **Root > System > Developer > User**, where Root instructions come only from the Model Spec itself.

**How intent feeds into decisions:** Instructions at each level act as constraints on the model's action space. Higher levels gate lower levels. The model cannot satisfy a user request that violates developer or platform instructions.

**Static or evolving:** Static per version. Updated by OpenAI periodically. Developers set their layer once via system messages.

**Production-tested:** Yes — powers all OpenAI API interactions.

**What Cortex can steal:**
- The **tiered override model** maps directly to Cortex's resolution order: Anthropic > Cortex framework > project intent > slug-level context
- The principle that **untrusted/inferred data has no authority by default** validates the preferences.json `source` field design — `inferred` preferences should carry less weight than `explicit`
- The concept of **inapplicability** (instructions become void when misaligned with higher authority) maps to non-negotiables killing any conflicting preference

### 1.2 Anthropic Claude Constitution / Soul Document

**Source:** [Anthropic Constitution](https://www.anthropic.com/constitution), [Claude 4.5 Opus Soul Document analysis](https://zenvanriel.com/ai-engineer-blog/anthropic-claude-constitution-ai-alignment-guide/)

Anthropic's 23,000-word "soul document" establishes a 3-tier principal hierarchy:

1. **Anthropic** — highest trust, sets meta-rules
2. **Operators** — "relatively (but not unconditionally) trusted employer" — configure Claude via system prompts
3. **Users** — "relatively (but not unconditionally) trusted adult member of the public"

Priority stack for behavior:
1. Broadly safe (first)
2. Broadly ethical (second)
3. Adherent to Anthropic's principles (third)
4. Genuinely helpful (last)

Critical design pattern — **hardcoded vs softcoded behaviors:**

| Type | Examples | Override Rules |
|------|----------|---------------|
| Hardcoded (immutable) | Weapons assistance, CSAM refusal, AI identity disclosure | Cannot be overridden by any principal |
| Softcoded (operator-adjustable) | Tone, content explicitness, domain restrictions, format | Operators can tune within bounds |

**What Cortex can steal:**
- The **hardcoded/softcoded split** directly validates the `strength: "requirement"` vs `strength: "preference"` distinction in preferences.json. Requirements are hardcoded (never auto-demote). Preferences are softcoded (can be overridden with evidence).
- **Trust asymmetry between principals** — operators get more latitude than users. Maps to: owner intent overrides cortex-drive inference, which overrides stash-level context.
- **Encoding reasoning, not just rules** — the soul doc explains *why* each constraint exists. The `context` field in preferences.json serves this purpose.

### 1.3 Microsoft 4-Layer Intent Framework

**Source:** [Microsoft Security Blog — Governing AI Agent Behavior](https://techcommunity.microsoft.com/blog/microsoft-security-blog/governing-ai-agent-behavior-aligning-user-developer-role-and-organizational-inte/4503551)

Microsoft structures agent governance around four intent layers:

1. **Organizational intent** — enterprise policies, compliance (outermost boundary)
2. **Role-based intent** — business function, scope of responsibility, autonomy bounds
3. **Developer intent** — capabilities, guardrails, operational constraints
4. **User intent** — goals, context, constraints, preferences, success criteria, risk level

Each layer has explicit elements: **goal, context, constraints, preferences, success criteria, risk level**.

Conflict resolution: outer layers always override inner layers. Organizational > Role > Developer > User.

Enforcement mechanisms:
- Dynamic guardrails at each layer
- Least privileged access based on intent dimensions
- Continuous monitoring and behavior audits
- Human-in-the-loop escalation for high-risk requests

**What Cortex can steal:**
- The explicit **element taxonomy** (goal, context, constraints, preferences, success criteria, risk level) per intent layer is a useful checklist for validating the owner-intent.md schema completeness
- **Dynamic guardrails** at each layer = the non-negotiable violation check proposed for cortex-drive's Phase 5
- The **risk level** element is missing from the current design — could add risk tolerance to preferences.json

---

## 2. AI Agent Configuration File Formats

### 2.1 The Agent Rules File Landscape

**Source:** [Comprehensive gist: AI Agent Rule Files](https://gist.github.com/0xdevalias/f40bc5a6f84c4c5ad862e314894b2fa6)

A standardized ecosystem has emerged. Key formats:

| Tool | File | Format | Scope |
|------|------|--------|-------|
| Claude Code | `CLAUDE.md` | Markdown (unstructured) | Root + parent + child dirs |
| OpenAI Codex | `AGENTS.md` | Markdown (unstructured) | Hierarchical root-to-leaf |
| GitHub Copilot | `.github/copilot-instructions.md` | Markdown + YAML frontmatter | Per-feature or global |
| Cursor | `.cursor/rules/*.mdc` | Markdown Component files | Per-pattern (glob-matched) |
| Continue | `.continue/config.yaml` | YAML | Composable blocks |
| JetBrains Junie | `.junie/guidelines.md` | Markdown | Per-project |
| Google ADK | `agent.yaml` | YAML | Per-agent |

**Common patterns across all formats:**
- Markdown is the dominant format for human-readable instructions
- YAML frontmatter provides machine-readable metadata
- Hierarchical precedence (nested files override parent files)
- Glob-pattern targeting for context-specific rules
- Progressive disclosure (load only what's relevant to current task)

**What Cortex can steal:**
- **Every system uses markdown as the human layer and structured data (YAML/JSON) as the machine layer** — validates the dual-artifact approach (owner-intent.md + preferences.json)
- **Hierarchical precedence** already designed into Cortex (global > project resolution)
- The **progressive disclosure principle** from CLAUDE.md best practices suggests keeping owner-intent.md concise and linking to supporting detail rather than inlining everything

### 2.2 CLAUDE.md Best Practices

**Source:** [HumanLayer Guide](https://www.humanlayer.dev/blog/writing-a-good-claude-md), [Anthropic Best Practices](https://code.claude.com/docs/en/best-practices)

Key findings:
- **Instruction budget:** ~150-200 instructions with reasonable compliance. Claude Code's system prompt uses ~50, leaving ~100-150 for CLAUDE.md
- **Anti-pattern: over-specification** — long files get ignored. Important rules get lost in noise
- **Best practice: progressive disclosure** — task-specific instructions in separate files, referenced from CLAUDE.md
- **WHAT/WHY/HOW framework** — tell Claude about the tech (what), the purpose (why), and the workflow (how)
- **Keep it under 300 lines** (ideally under 60 for the root file)
- **Never send an LLM to do a linter's job** — automate what's enforceable

**Implication for owner-intent.md:**
- owner-intent.md is consumed by Claude via SKILL.md instructions, not directly as a system prompt
- But the **instruction budget** still applies — the more intent context loaded into a session, the less room for other instructions
- Design for **parsimony**: the intent doc should be the minimum viable signal, not an essay

### 2.3 AGENTS.md (OpenAI/Linux Foundation Standard)

**Source:** [agents.md](https://agents.md/), [OpenAI Codex Docs](https://developers.openai.com/codex/guides/agents-md)

AGENTS.md is now stewarded by the Agentic AI Foundation under the Linux Foundation.

Key design decisions:
- **No required sections** — intentionally unstructured
- **Standard Markdown** with any headings
- **Hierarchical file discovery** — agents read nearest file in directory tree, nested files take precedence
- **Complementary to README** — README for humans, AGENTS.md for agents
- OpenAI's own repo has **88 AGENTS.md files** — one per significant directory

**What Cortex can steal:**
- The **complementary relationship** between AGENTS.md and README mirrors the relationship between owner-intent.md and CLAUDE.md — they serve different purposes and should not duplicate content
- The **directory-scoped override** pattern could inform future slug-scoped intent overrides

---

## 3. Spec-Driven Development Systems

### 3.1 Kiro (Amazon/AWS)

**Source:** [Kiro](https://kiro.dev/), [Martin Fowler SDD Analysis](https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html)

Kiro inserts a structured planning step before writing code. Three sequential artifacts:

1. **Requirements.md** — user stories in "As a..." format with GIVEN/WHEN/THEN acceptance criteria (EARS notation)
2. **Design.md** — component architecture, data flow, data models, error handling, testing strategy
3. **Tasks.md** — actionable items traced to requirement numbers

**How intent is modeled:** User intent is captured through natural language prompts that Kiro expands into structured requirements. The spec becomes the contract between human intent and AI execution.

**What Cortex can steal:**
- The **EARS notation** (Easy Approach to Requirements Syntax) for acceptance criteria is more rigorous than freeform criteria — could improve contract validator definitions
- The **three-artifact decomposition** (requirements/design/tasks) parallels Cortex's clarify/spec/contract pipeline but with tighter traceability between layers
- **Hooks** (user prompts triggered by file changes) are analogous to cortex-drive's event-driven dispatch

### 3.2 spec-kit (GitHub)

**Source:** [GitHub spec-kit](https://github.com/github/spec-kit/blob/main/spec-driven.md)

spec-kit introduces the **constitution** concept — immutable architectural principles governing all spec-to-code transformations:

- **Article I** — Library-First: every feature starts as a standalone library
- **Article III** — Test-First: no code before failing tests
- **Article VII** — Simplicity: max 3 projects initially
- **Article VIII** — Anti-Abstraction: use frameworks directly, don't wrap them
- **Article IX** — Integration-First: prefer real services over mocks

Three-command workflow:
1. `/speckit.constitution` — establish immutable principles
2. `/speckit.specify` → generates spec.md with user stories and acceptance criteria
3. `/speckit.plan` → translates spec into implementation plan with constitutional compliance gates

**Phase -1 gates** enforce constitutional compliance before any coding:
- Simplicity Gate
- Anti-Abstraction Gate
- Integration-First Gate

**What Cortex can steal:**
- The **constitution as immutable principles** maps directly to non-negotiables in owner-intent.md — both are "hard constraints that no work may violate"
- **Phase -1 gates** (pre-implementation constitutional compliance) is the same pattern as the non-negotiable violation check proposed for cortex-drive
- The **file creation order** (contracts > tests > implementation) enforces intent-to-code traceability
- **Speculative Feature Prevention** — all features must trace to concrete user stories. Equivalent: all slugs must trace to an objective in owner-intent.md

### 3.3 BMAD Method

**Source:** [BMAD Docs](https://docs.bmad-method.org/), [BMAD Project Context](https://docs.bmad-method.org/explanation/project-context/)

BMAD assigns specialized AI agent roles mirroring a real team: Analyst, Product Manager, Architect, Scrum Master, Product Owner, Developer, QA.

**project-context.md** serves as the "constitution" — an implementation guide for AI agents:
- Technology stack and versions
- Critical implementation rules by category (TypeScript config, code organization, testing patterns, framework-specific)
- Loaded automatically by every implementation workflow
- Documents "what's unobvious" — rules agents wouldn't infer from code alone

**How intent feeds in:** Each agent role has scoped context. The product-context.md provides the persistent "why" that each role references. Changes to context propagate to all agent decisions.

**What Cortex can steal:**
- The principle of documenting **"what's unobvious"** is the right filter for owner-intent.md content — only include what Claude would get wrong without the instruction
- **Role-scoped context loading** — cortex-drive needs different intent sections than cortex-clarify. Consider marking sections with intended consumers.
- The distinction between **project-context (persistent/stable)** and **sprint artifacts (ephemeral/per-iteration)** mirrors owner-intent (stable) vs contracts (per-slug)

### 3.4 Addy Osmani's Spec Writing Guide

**Source:** [How to Write a Good Spec for AI Agents](https://addyo.substack.com/p/how-to-write-a-good-spec-for-ai-agents)

Analysis of 2,500+ agent configuration files identified six core areas:

1. **Commands** — full executable commands with flags
2. **Testing** — framework, locations, coverage expectations
3. **Project structure** — explicit directory layout
4. **Code style** — real code examples of preferred patterns
5. **Git workflow** — branch naming, commit format, PR requirements
6. **Boundaries** — clear guidelines on what agents should/shouldn't touch

Three-tier boundary system:
- **Always do** — "Always run tests before commits"
- **Ask first** — "Ask before modifying database schemas"
- **Never do** — "Never commit secrets or API keys"

**What Cortex can steal:**
- The **three-tier boundary system** maps to `strength` in preferences.json: `requirement` = always/never, `preference` = default behavior, `suggestion` = try first
- The **"curse of instructions"** finding — model performance drops as you pile on requirements — reinforces keeping owner-intent.md concise
- **Conformance tests** derived from specifications that implementations must satisfy = contract validators derived from intent objectives

---

## 4. Memory and Preference Systems

### 4.1 LangGraph Long-Term Memory

**Source:** [LangGraph Memory Overview](https://docs.langchain.com/oss/python/langgraph/memory), [LangChain Blog](https://blog.langchain.com/launching-long-term-memory-support-in-langgraph/)

LangGraph stores long-term memories as JSON documents in a hierarchical namespace:

```
Namespace: (user_id, application_context)
Key: individual memory identifier
Value: JSON document
```

Two approaches for user preferences:

| Approach | Structure | Pros | Cons |
|----------|-----------|------|------|
| **Profile** | Single continuously-updated JSON document | Simple, complete picture | Error-prone updates as complexity grows |
| **Collection** | Multiple narrow documents added over time | Higher recall, incremental | Complex deletion/update logic, search overhead |

Memory creation patterns:
- **Hot path** — agent decides what to remember during runtime (immediate but adds latency)
- **Background** — async tasks create memories after the fact (no latency but risks staleness)

**What Cortex can steal:**
- The **Profile vs Collection** tradeoff maps to the preferences.json design choice. Cortex chose the Profile approach (single JSON file) which LangGraph warns becomes error-prone as complexity grows. Consider: should preferences.json support a hybrid model where frequently-changing preferences are separate from stable ones?
- **Hot path vs background memory creation** maps to explicit vs inferred preference sources. `source: "inferred"` preferences are the "background" pattern — observed asynchronously, lower trust
- The **namespace hierarchy** (user > application > context) validates the global > project > slug scope model

### 4.2 Comprehensive Preference Taxonomy (AI Copilots Survey)

**Source:** [Modeling and Optimizing User Preferences in AI Copilots (2025)](https://arxiv.org/html/2505.21907)

This survey organizes preference modeling across three lifecycle phases:

**Pre-interaction (Detection):**
- Implicit signals: clickstreams, gaze tracking, user edits to AI outputs
- Explicit feedback: pairwise comparisons, satisfaction ratings, direct labeling
- Hybrid: behavioral + explicit combined

**Mid-interaction (Adaptation):**
- Real-time persona attribute extraction
- In-dialogue learning (incremental persona updates)
- Engagement and emotion modeling

**Post-interaction (Refinement):**
- Active preference learning from sparse feedback
- Long-term persona refinement
- Retrieval-augmented quality feedback loops

Preference representation schema:
- **Static profiles** — demographic and behavioral attributes
- **Dynamic personas** — session-based and dialogue-context embeddings
- **Preference pairs** — (preferred response, rejected response, context)
- **Feedback signals** — implicit (edits, behavior) and explicit (ratings)
- **Multi-dimensional objectives** — vectorized alignment across multiple values

**What Cortex can steal:**
- The **three-phase lifecycle** (detect > adapt > refine) maps to the intent bootstrap flow: `/cortex-intent init` (detect from CLAUDE.md and history) > runtime preference reads (adapt) > `/cortex-intent review` (refine based on drift)
- **"User edits to AI outputs as coactive signals"** — when the owner modifies cortex-drive decisions or overrides preferences, those edits are implicit preference signals. The `source: "inferred"` pattern could capture these.
- The **multi-dimensional objective vector** is more sophisticated than the current ranked tradeoff list — but the ranked list is simpler and sufficient for a single-user system

### 4.3 Adaptive Preference Arithmetic

**Source:** [Adaptive Preference Arithmetic (ICLR 2025)](https://openreview.net/forum?id=gkG8JOOUF4)

Key insight: "User preferences are often stable in content but their relative strengths shift over time due to changing goals and contexts."

This means preference *content* (e.g., "prefer correctness over speed") is durable, but preference *weight* (e.g., how much more important correctness is) changes based on current context.

**What Cortex can steal:**
- The **content vs weight separation** validates the preferences.json design where `value` (content) is separate from `strength` and `confidence` (weight). A preference can maintain the same value while its effective weight changes through staleness demotion or confidence adjustment.
- This supports the staleness model: stale preferences don't change their content (still "correctness over speed") but their effective binding force weakens (from `preference` to `suggestion`)

### 4.4 Dynamic User Profiling

**Source:** [Dynamic Personalization through Continuous Feedback Loops (2026)](https://arxiv.org/html/2602.23376), [Capturing Dynamic User Preferences (2025)](https://www.mdpi.com/2079-8954/13/11/1034)

Key mechanisms for handling preference evolution:
- **Non-linear forgetting curves** — preferences decay following power-law rather than linear models
- **Evolving topics** — preference categories themselves change over time, not just values
- **Event-driven updates** — preferences shift at discrete events (project milestones, direction changes), not continuously

**What Cortex can steal:**
- The **event-driven update model** fits Cortex better than continuous adaptation. Preferences should change at: slug completion, milestone boundaries, explicit owner edits — not continuously during execution.
- The current **linear staleness model** (age > TTL = demote) could be replaced with a **power-law decay** if needed, but linear is simpler and sufficient for the scale of preferences Cortex manages

---

## 5. Goal Alignment in Software Practice

### 5.1 Multi-Level Value Alignment Framework

**Source:** [Application-Driven Value Alignment in Agentic AI Systems (2025)](https://arxiv.org/html/2506.09656v1)

Three-tier hierarchy:

| Level | Scope | Examples |
|-------|-------|---------|
| **Macro** | Universal values | Beneficence, justice, honesty, responsibility, harmlessness, trust |
| **Meso** | Contextual implementation | National policies, industry standards, cultural dimensions |
| **Micro** | Operational specificity | Role-specific requirements (recruitment fairness, legal transparency) |

Three alignment approaches:
1. **Top-down** — designers establish explicit ethical frameworks, deploy via RLHF/SFT
2. **Bottom-up** — agents infer norms from behavioral data (risks perpetuating biases)
3. **Interaction-based** — values transmitted through interaction rules and organizational structures

**What Cortex can steal:**
- The **macro/meso/micro mapping** validates the global/project/slug scope hierarchy
- The **top-down vs bottom-up distinction** maps to `source: "explicit"` vs `source: "inferred"` — explicit is safer but requires more owner effort, inferred is cheaper but risks bias
- **Interaction-based embedding** suggests that intent should not only be a static document but should shape *how commands interact* — which is exactly what the cortex-drive decision table modifications do

### 5.2 Project Charters and Definition of Done

**Source:** [Atlassian DoD Guide](https://www.atlassian.com/agile/project-management/definition-of-done), [Smartsheet Agile Charter](https://www.smartsheet.com/content/agile-project-charter)

**Project Charter** standard sections: vision, mission statement, objectives, success criteria, roles, constraints, risks, timeline.

**Definition of Done** operates at two levels:
- **Organization-level DoD** — minimum quality bar for all work. Stable across sprints.
- **Item-level Acceptance Criteria** — specific conditions for individual stories.

The DoD functions as a "contract template where some portions may be marked as Not Applicable." This is exactly a **non-negotiable** in intent language — a quality floor that all work must meet.

**What Cortex can steal:**
- **Organization DoD = non-negotiables in owner-intent.md** — both are stable quality floors
- **Item AC = contract validators** — both are per-item testable conditions
- The **traceability** principle (acceptance criteria trace back to the Done checklist) validates the proposed rule that contract validators must reference intent success metrics

### 5.3 OKR / North Star Metric Framework

**Source:** [OKR, OGSM, and North Star Metrics](https://doronsegal.medium.com/okr-ogsm-and-north-star-metrics-526c37358fe0), [Product Strategy-Metrics Sandwich](https://herbig.co/product-strategy-metrics-sandwich/)

The hierarchy:
1. **North Star Metric** — the single measure that captures core value delivery
2. **Objectives** — qualitative goals aligned to the north star
3. **Key Results** — quantitative measures of objective progress

Kill criteria: "Kill all the metrics you don't have complete control over or can't measure and track accurately."

**What Cortex can steal:**
- owner-intent.md's **Mission** section is the North Star
- **Objectives** section maps directly to OKR Objectives
- **Success Metrics** section maps to Key Results
- The **kill criteria for metrics** ("can't measure or control? remove it") should be a validation rule for success metrics in intent — every metric must be measurable within the Cortex system

---

## 6. Preference Elicitation Methods

### 6.1 Solicit-Then-Suggest Model

**Source:** [Elicitation Inference Optimization (2026)](https://arxiv.org/html/2603.20972)

Framework: AI conducts *m* rounds of targeted questioning in a *d*-dimensional preference space, then recommends *k* options.

Key finding: **asking well-targeted questions outperforms exponentially expanding options**, especially in high-dimensional preference spaces. Loss shrinks at O(1/m) with questioning vs O(k^-2/d) with broader options.

**What Cortex can steal:**
- The `/cortex-intent init` bootstrap asking 5-8 questions is the right approach. The research confirms that **targeted questioning is more efficient than broad option-presentation**
- Questions should be designed to maximally reduce uncertainty about the owner's preference space — ask about the axes with highest variance first (e.g., speed vs correctness tradeoff before code comment verbosity)

### 6.2 Inverse Reward Design

**Source:** [Inverse Reward Design (NeurIPS 2017)](https://people.eecs.berkeley.edu/~russell/papers/nips17-ird.pdf), [Active Inverse Reward Design](https://arxiv.org/abs/1809.03060)

IRD infers true intent from observed proxy signals. Key insight: when a user specifies a reward/preference, they're providing a **proxy** that may not capture their full intent. The system should maintain uncertainty about the true reward and act conservatively where the proxy might be wrong.

Active IRD extends this by asking users to compare reward functions directly for maximum informativeness.

**What Cortex can steal:**
- **Preferences are proxies, not ground truth.** The `confidence` field in preferences.json captures this — low confidence = the system should be more conservative about relying on this preference
- **Acting conservatively under uncertainty** = when a preference has low confidence or is stale, cortex-drive should prefer the safer/more conservative action rather than optimizing for the stated preference
- **Active querying** — the `/cortex-intent review` command should ask the owner to compare their stated preferences against observed execution patterns, not just confirm yes/no

### 6.3 Constitutional AI and Preference Learning

**Source:** [Constitutional AI (Anthropic)](https://www.anthropic.com/research/constitutional-ai-harmlessness-from-ai-feedback), [Collective Constitutional AI](https://www.anthropic.com/research/collective-constitutional-ai-aligning-a-language-model-with-public-input)

Key innovation: Using a set of principles (constitution) as a replacement for human preference labels. The AI generates self-critiques based on constitutional principles, then trains on its own revised outputs.

Collective Constitutional AI extends this with **publicly-sourced principles** — a representative sample provides input on what the constitution should contain. The public constitution overlapped 50% with Anthropic's internal one, with differences in emphasis (public emphasized objectivity and accessibility more).

**What Cortex can steal:**
- The **self-critique mechanism** is analogous to cortex-drive checking its decisions against non-negotiables before dispatch. The constitution (owner-intent non-negotiables) serves as the critique rubric.
- The **difference between expert-authored and user-authored constitutions** warns that owner-stated preferences may emphasize different things than what would produce best outcomes. The `source` and `confidence` fields help flag this gap.

---

## 7. Cursor Rules Architecture

**Source:** [Cursor Rules Documentation](https://docs.cursor.com/context/rules)

Cursor evolved from a single `.cursorrules` file to a structured system:

- `.cursor/rules/*.mdc` — Markdown Component files with YAML frontmatter
- Each rule targets specific file patterns via glob matching
- Three types: Project Rules (version-controlled), Global Rules (user-level), Legacy rules (deprecated)

Best practices:
- Be specific and actionable (vague = inconsistent results)
- Under 500 lines per rule
- Use examples over descriptions
- Decompose complex standards into focused files

**What Cortex can steal:**
- The **evolution from monolithic to modular rules** is a warning: owner-intent.md should stay concise now, but the architecture should support decomposition later (e.g., separate files for different preference categories)
- **Glob-pattern targeting** for rules = scope-based preference application. A preference could target specific slug types or command contexts.

---

## 8. Synthesis: Patterns Across All Systems

### 8.1 Universal Design Patterns

Every system surveyed shares these structural elements:

| Pattern | Frequency | Cortex Mapping |
|---------|-----------|---------------|
| Tiered authority hierarchy | 6/6 principal-based systems | Anthropic > framework > project intent > slug context |
| Immutable vs adjustable constraints | 5/6 systems | `strength: "requirement"` vs `"preference"` |
| Human-readable + machine-readable dual format | All agent config systems | owner-intent.md + preferences.json |
| Hierarchical scope (global > project > local) | All systems with scale | Global > project > slug preferences |
| Staleness/evolution mechanism | 4/6 preference systems | Staleness model with TTL and demotion |
| Bootstrap via questioning | 3/6 elicitation systems | `/cortex-intent init` asking 5-8 questions |
| Traceability (high-level goals to low-level criteria) | All spec-driven systems | Intent objectives > contract validators |

### 8.2 Validated Design Decisions

The existing design-research-20260406.md makes several decisions that are **strongly validated** by external evidence:

1. **YAML frontmatter + markdown sections** — used by Kiro, GitHub Copilot, spec-kit, and CLAUDE.md ecosystem. The standard pattern.

2. **Dual-artifact approach** (intent.md + preferences.json) — mirrors the universal pattern of human-readable + machine-readable formats. LangGraph, Cursor, and BMAD all separate human prose from structured data.

3. **Staleness/decay model** — academic research confirms preferences are "stable in content but their relative strengths shift over time." The demotion model (preference > suggestion > ignored) is well-founded.

4. **Three strength levels** (requirement/preference/suggestion) — maps directly to the three-tier boundary system found in spec-writing best practices (always/ask-first/never) and Anthropic's hardcoded/softcoded split.

5. **Non-negotiables as kill criteria** — spec-kit's constitution, Anthropic's hardcoded behaviors, and organization-level Definition of Done all implement this pattern.

6. **`source` field distinguishing explicit vs inferred** — validated by RLHF research (explicit labels > implicit signals), IRD research (preferences are proxies), and LangGraph's distinction between hot-path and background memory.

7. **Resolution order** (project > global) — matches OpenAI's "later instructions supersede earlier ones at the same level" and every hierarchical config system surveyed.

### 8.3 Gaps and Recommendations

Issues the external research surfaces that the current design should address:

**Gap 1: Risk tolerance is missing**
Microsoft's framework includes "risk level" as an explicit intent element. The current schema has no equivalent. Consider adding a `risk_tolerance` field to preferences.json or a "Risk Appetite" section to owner-intent.md.

**Gap 2: Consumer-scoped sections**
BMAD loads different context for different agent roles. The current design loads all intent for all commands. Consider adding optional `consumers: [drive, clarify, spec]` metadata to preferences so commands can filter for relevant preferences only.

**Gap 3: Instruction budget pressure**
CLAUDE.md research shows a ~150-instruction compliance ceiling. owner-intent.md adds to the instruction budget when loaded into SKILL.md. Design for parsimony: the loaded version should be a distilled subset, not the full document.

**Gap 4: Profile growth problem**
LangGraph warns that single continuously-updated JSON profiles become error-prone as they grow. preferences.json may need a maximum preference count or a category-based file split at some point.

**Gap 5: Active preference querying**
The current `/cortex-intent review` is passive (flags staleness). IRD research suggests active comparison queries would be more effective: "Your stated preference is X, but your last 5 slugs suggest Y. Which is correct?"

---

## 9. Sources

### AI Agent Frameworks
- [Microsoft — Governing AI Agent Behavior: 4-Layer Intent](https://techcommunity.microsoft.com/blog/microsoft-security-blog/governing-ai-agent-behavior-aligning-user-developer-role-and-organizational-inte/4503551)
- [OpenAI Model Spec (2025/04/11)](https://model-spec.openai.com/2025-04-11.html)
- [OpenAI Model Spec (2025/12/18)](https://model-spec.openai.com/2025-12-18.html)
- [Anthropic Claude Constitution](https://www.anthropic.com/constitution)
- [Claude Soul Document Analysis](https://zenvanriel.com/ai-engineer-blog/anthropic-claude-constitution-ai-alignment-guide/)
- [Claude 4.5 Opus Soul Document](https://gist.github.com/Richard-Weiss/efe157692991535403bd7e7fb20b6695)
- [BMAD Method Documentation](https://docs.bmad-method.org/)
- [BMAD Project Context](https://docs.bmad-method.org/explanation/project-context/)
- [CrewAI Tasks Documentation](https://docs.crewai.com/en/concepts/tasks)
- [CrewAI Planning Workflow](https://www.analyticsvidhya.com/blog/2025/12/crewai-planning/)
- [AutoGen Framework (Microsoft)](https://github.com/microsoft/autogen)
- [LangGraph Memory Overview](https://docs.langchain.com/oss/python/langgraph/memory)
- [LangGraph Long-Term Memory Launch](https://blog.langchain.com/launching-long-term-memory-support-in-langgraph/)
- [Devin AI Coding Agents 101](https://devin.ai/agents101)
- [Google ADK Agent Config](https://google.github.io/adk-docs/agents/config)

### Spec-Driven Development
- [Kiro — Spec-Driven IDE](https://kiro.dev/)
- [Kiro Blog — Future of Software Development](https://kiro.dev/blog/kiro-and-the-future-of-software-development/)
- [spec-kit — GitHub Spec-Driven Development](https://github.com/github/spec-kit/blob/main/spec-driven.md)
- [spec-kit Announcement (GitHub Blog)](https://github.blog/ai-and-ml/generative-ai/spec-driven-development-with-ai-get-started-with-a-new-open-source-toolkit/)
- [Martin Fowler — Understanding Spec-Driven Development: Kiro, spec-kit, and Tessl](https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html)
- [Addy Osmani — How to Write a Good Spec for AI Agents](https://addyo.substack.com/p/how-to-write-a-good-spec-for-ai-agents)

### Agent Configuration Files
- [Comprehensive AI Agent Rule Files Landscape](https://gist.github.com/0xdevalias/f40bc5a6f84c4c5ad862e314894b2fa6)
- [AGENTS.md Standard](https://agents.md/)
- [OpenAI Codex — AGENTS.md Guide](https://developers.openai.com/codex/guides/agents-md)
- [Claude Code Best Practices](https://code.claude.com/docs/en/best-practices)
- [HumanLayer — Writing a Good CLAUDE.md](https://www.humanlayer.dev/blog/writing-a-good-claude-md)
- [Cursor Rules Documentation](https://docs.cursor.com/context/rules)

### Preference Modeling and Alignment
- [Modeling and Optimizing User Preferences in AI Copilots: Survey and Taxonomy (2025)](https://arxiv.org/html/2505.21907)
- [Adaptive Preference Arithmetic (ICLR 2025)](https://openreview.net/forum?id=gkG8JOOUF4)
- [Dynamic Personalization through Continuous Feedback Loops (2026)](https://arxiv.org/html/2602.23376)
- [Elicitation Inference Optimization for Multi-Principal-Agent Alignment (2026)](https://arxiv.org/html/2603.20972)
- [Inverse Reward Design (NeurIPS 2017)](https://people.eecs.berkeley.edu/~russell/papers/nips17-ird.pdf)
- [Active Inverse Reward Design](https://arxiv.org/abs/1809.03060)
- [Constitutional AI: Harmlessness from AI Feedback (Anthropic)](https://www.anthropic.com/research/constitutional-ai-harmlessness-from-ai-feedback)
- [Collective Constitutional AI (Anthropic)](https://www.anthropic.com/research/collective-constitutional-ai-aligning-a-language-model-with-public-input)
- [Application-Driven Value Alignment in Agentic AI Systems (2025)](https://arxiv.org/html/2506.09656v1)
- [Value Alignment Problem Guide (2025)](https://www.shadecoder.com/topics/value-alignment-problem-a-comprehensive-guide-for-2025)
- [RLHF Book — Reward Modeling](https://rlhfbook.com/c/07-reward-models.html)

### Software Practice
- [Atlassian — Definition of Done](https://www.atlassian.com/agile/project-management/definition-of-done)
- [Scrum.org — Acceptance Criteria and Definition of Done](https://www.scrum.org/forum/scrum-forum/17103/acceptance-criteria-definition-done)
- [OKR, OGSM, and North Star Metrics](https://doronsegal.medium.com/okr-ogsm-and-north-star-metrics-526c37358fe0)
- [Product Strategy-Metrics Sandwich](https://herbig.co/product-strategy-metrics-sandwich/)
- [Smartsheet — Agile Project Charter Guide](https://www.smartsheet.com/content/agile-project-charter)
