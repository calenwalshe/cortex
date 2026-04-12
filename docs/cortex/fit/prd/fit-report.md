# Fit Report: prd

<!-- ART-FIT: Fit Report Template — produced by /cortex-fit -->
<!-- SC2 forced-separation: each section must not repeat content from any other section -->

**Slug:** prd
**Timestamp:** 20260412T080000Z
**Evaluated against:** Cortex intelligence-to-execution pipeline (clarify → research → spec → contract → GSD)
**Confidence:** low — no dossier exists; reasoning from concept description
**Status:** pending-human-decision

---

## Tech Radar Ring

**Ring:** Assess

**Justification:** PRD's genuine gaps (success metrics, stakeholder narrative) are real, but the overlap with existing Cortex artifacts is too high to adopt wholesale without creating two sources of truth.

---

## Gap

What does a PRD fill that the current Cortex ecosystem lacks entirely?

- **Ongoing success metrics**: Cortex acceptance criteria are binary pass/fail for implementation completion (did this ship correctly?). PRDs typically include KPIs and outcome metrics that are evaluated post-launch (did this succeed in the product sense? e.g., "MAU increases 15%", "p95 latency < 200ms in production"). Cortex has no dedicated artifact for outcome metrics that survive past contract closure.

- **Stakeholder narrative layer**: Cortex artifacts are optimized for AI-agent and technical-owner consumption. A PRD is written for non-technical stakeholders — PMs, designers, business leads — who need to understand what is being built and why without interpreting a clarify brief or a spec. Cortex has the new Owner Summary layer in dossiers, but no single-document narrative intended for external stakeholders.

- **Multi-stakeholder approval tracking**: Cortex tracks one approval signal (contract approved: yes/no, typically one human). PRDs often carry explicit RACI — PM, design, engineering lead, legal, exec — with separate sign-off fields. Cortex has no equivalent for multi-party alignment before execution begins.

---

## Overlap

Where does a PRD duplicate content already present in Cortex?

- **Problem statement**: The spec's §1 (Problem) captures what is being built, for whom, and why now — the core PRD problem section verbatim. The clarify brief's Goal field covers the same ground in one sentence.

- **Scope / Non-goals**: The clarify brief's Non-Goals and the spec's §3 (Scope → In Scope / Out of Scope) are functionally identical to a PRD's scope section. Explicit exclusions are tracked in both.

- **Functional requirements / acceptance criteria**: The spec's §2 (Acceptance Criteria) and the contract's Done Criteria together constitute the PRD's functional requirements, with the additional constraint that they must be machine-executable in Cortex's model.

- **Risks and constraints**: The spec's §7 (Risks) and the clarify brief's Constraints section cover risk registers and hard limits. These map directly to the constraints section of a PRD.

- **Architecture decisions**: The spec's §4 (Architecture Decision) with alternatives-considered format exceeds what most PRDs contain for technical decisions.

- **Open questions / assumptions**: The clarify brief explicitly tracks both. Most PRDs include these informally or not at all.

---

## Unique Contribution

What does a PRD bring that is genuinely novel — not covered by Gap or Overlap?

- **Unified stakeholder artifact**: A PRD consolidates all of the above into a single document written in one voice for one audience. Cortex deliberately distributes the same information across multiple phase-specific artifacts (brief, dossiers, spec, contract). The PRD format's unique value is not its content — it's the consolidation. A reader can hand a PRD to any stakeholder and they get the full picture; in Cortex, they would need to read 3–4 files in sequence. This is a communication architecture difference, not a capability difference.

---

## Conflict

Where would a PRD actively clash with Cortex's principles or architecture?

- **Two sources of truth for "done"**: Cortex's contract Done Criteria are machine-executable and serve as the authoritative definition of completion. A PRD's acceptance criteria are typically informal prose. If both exist, they will diverge over time — the contract gets updated during repair cycles, the PRD does not. Teams will disagree about which is authoritative.

- **Snapshot document vs. living artifacts**: Cortex artifacts evolve across the lifecycle (briefs iterate, specs get superseded, contracts get repaired). PRDs are snapshot documents that become stale rapidly. Importing the PRD concept without a clear staleness model creates an artifact that Cortex's scribe/continuity machinery has no protocol to maintain.

- **Format mismatch with AI agent consumption**: Cortex artifacts are structured markdown with explicit sections, YAML frontmatter, and machine-checkable fields. PRDs are written for human narrative consumption. An AI agent reading a PRD to extract constraints or acceptance criteria must infer structure from prose — a step backward from Cortex's current structured-intake model.

- **Process length**: Cortex's pipeline is already clarify → research → spec → contract, often with gates between each phase. Adding a PRD step (whether before clarify as a precursor or after spec as a translation artifact) extends the pipeline without replacing any existing step, since Cortex already captures what the PRD contains.

---

## Strategic Direction

**Alignment:** partially aligned

Cortex's trajectory is toward increasing autonomy, machine-readable artifacts, and AI agent orchestration — artifacts are structured for agents to read, update, and validate. The PRD concept's trajectory is in the opposite direction: it is a human-written, human-read document produced for organizational alignment, optimized for a world where humans, not agents, do most of the work. The genuine overlap is that both care deeply about capturing requirements and goals clearly before building — but their execution models diverge sharply. Cortex is also moving toward progressive disclosure (Owner Summary, HITL formula) which partially closes the "stakeholder readability" gap without adopting the full PRD format.

---

## Pre-Populated Clarify Brief Fields

**Proposed goal:** Add an ongoing success-metrics artifact to the Cortex pipeline so that outcome KPIs (post-launch, product-level) are captured separately from implementation acceptance criteria and survive contract closure.

**Constraints:**
- Must not create a second source of truth for implementation acceptance criteria — any new artifact must clearly defer to the contract's Done Criteria for "is this built correctly" questions
- Must remain machine-readable or at least machine-parseable — no free-prose-only artifact formats
- Must fit into the existing artifact lifecycle (scribe must have a protocol for when it gets written and updated)
- Must not require a full PRD process — the minimal version of the gap (success metrics) should be addable as a field extension, not a new document type

**Open questions:**
- Is the lack of ongoing success metrics actually felt as a pain point, or is it theoretical? Have slugs failed or been judged incorrectly because there were no post-launch KPIs?
- Who is the target audience for the "stakeholder narrative" gap — is there an actual non-technical stakeholder who would read a unified document, or is this hypothetical?
- Could the Owner Summary layer in dossiers (just shipped in report-clarity) close the stakeholder readability gap sufficiently without needing a PRD?
- Would a lightweight `success-metrics.md` artifact per slug — written at spec time, linked from the contract — satisfy the KPI gap without importing the full PRD format?
- Is multi-stakeholder approval tracking a real need in the current Cortex deployment context, or is it a pattern from larger org setups?

---

## Human Decision

**Status:** pending-human-decision

To advance: change status to `approved` or `rejected` and add a one-line note.

- [ ] Approved — proceed to `/cortex-clarify prd` (or a narrower slug if the scope is reduced)
- [ ] Rejected — archive this report, no further action

**Decision note:** _(fill in when deciding)_
