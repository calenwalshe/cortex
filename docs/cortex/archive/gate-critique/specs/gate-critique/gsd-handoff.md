# GSD Handoff: gate-critique

<!-- ART-04: GSD Handoff Template — produced by /cortex-spec -->

**Slug:** gate-critique
**Timestamp:** 20260412T090000Z
**Status:** draft

---

## Objective

Build a standalone `/cortex-critique` skill that runs an adversarial AI review of Cortex artifacts (clarify brief, research dossier, spec) at each gate transition, so bad assumptions and poor framing are caught before they propagate downstream into expensive execution work.

---

## Deliverables

- Skill file: `skills/cortex-critique/SKILL.md` — new standalone critique skill
- Edited skill: `skills/cortex-clarify/SKILL.md` — Phase 4c addition invoking cortex-critique
- Edited skill: `skills/cortex-research/SKILL.md` — Phase 2.9 addition invoking cortex-critique
- Edited skill: `skills/cortex-spec/SKILL.md` — Phase 1c addition invoking cortex-critique

---

## Requirements

- None formalized

---

## Tasks

- [ ] Write `skills/cortex-critique/SKILL.md` with: artifact-type detection (brief/dossier/spec/contract), Codex exec invocation with adversarial prompt, JSON output parsing with `claude -p` fallback, three-tier severity routing (STOP/CAUTION/GO), critique artifact writer, gate receipt writer to `.cortex/state.json`
- [ ] Define critique dimensions per artifact type in the skill: brief (completeness, unambiguity, consistency, verifiability, framing attack), dossier (evidence adequacy, source authority, finding-to-question traceability, assumption backing), spec (AC testability, scope coherence, risk completeness), contract (done criteria verifiability, validator coverage, write roots completeness)
- [ ] Write the adversarial Codex prompt template with: role declaration ("you are an adversarial critic, not an assistant"), minimum finding requirement with zero-justification escape, artifact-type-specific dimension list, JSON output schema (`severity`, `findings[]` with tier/dimension/finding/quote/impact, `summary`)
- [ ] Add `human_critique` gate to the autonomy gate table in cortex-critique; document: skippable in full-auto, active in supervised; when active, owner sees AI findings in plain language before gate advances
- [ ] Edit `skills/cortex-clarify/SKILL.md` Phase 4: add Phase 4c — invoke cortex-critique on the clarify brief, persist to `docs/cortex/reviews/{slug}/critique-clarify.md`, write gate receipt
- [ ] Edit `skills/cortex-research/SKILL.md` Phase 3: add Phase 2.9 — invoke cortex-critique after dossier write, persist to `docs/cortex/reviews/{slug}/critique-dossier-{timestamp}.md`, write gate receipt
- [ ] Edit `skills/cortex-spec/SKILL.md` Phase 1: add Phase 1c — invoke cortex-critique on spec.md before contract approval gate, persist to `docs/cortex/reviews/{slug}/critique-spec.md`, write gate receipt
- [ ] Smoke test: confirm critique artifact is produced at the correct path after a `/cortex-clarify` invocation on a test slug

---

## Acceptance Criteria

- [ ] `skills/cortex-critique/SKILL.md` exists and implements the cortex-critique skill with: artifact-type routing (brief, dossier, spec, contract), Codex CLI invocation with exec mode and adversarial prompt, three-tier severity output (STOP/CAUTION/GO), and persistent critique artifact output
- [ ] The Codex invocation uses `codex exec --full-auto` with a prompt that explicitly frames Codex as an adversarial critic — not an assistant — before presenting the artifact to critique
- [ ] Running cortex-critique against a clarify brief produces `docs/cortex/reviews/{slug}/critique-clarify.md` containing: severity verdict, finding count by tier, and specific findings with artifact quotes
- [ ] Running cortex-critique against a research dossier produces `docs/cortex/reviews/{slug}/critique-dossier-{timestamp}.md`
- [ ] Running cortex-critique against a spec produces `docs/cortex/reviews/{slug}/critique-spec.md`
- [ ] `skills/cortex-clarify/SKILL.md` invokes cortex-critique after writing the clarify brief (Phase 4c) before completing continuity state update
- [ ] `skills/cortex-research/SKILL.md` invokes cortex-critique after writing each dossier before setting `research_complete: true`
- [ ] `skills/cortex-spec/SKILL.md` invokes cortex-critique against spec.md before presenting the contract approval gate
- [ ] In full-auto mode, AI critique runs and findings are persisted; the `human_critique` gate is skipped and the gate advances automatically
- [ ] In supervised mode, the owner is shown the AI critique findings in plain language and given the opportunity to respond before the gate advances

---

## Contract Link

docs/cortex/contracts/gate-critique/contract-001.md
