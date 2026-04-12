# Contract: gate-critique — execute

<!-- ART-05: Contract Template — produced by /cortex-spec -->

**ID:** gate-critique-001
**Slug:** gate-critique
**Phase:** execute
**Created:** 2026-04-12T09:00:00Z
**Status:** approved
**Repair Budget:** max_repair_contracts: 3, cooldown_between_repairs: 1

---

## Objective

Build the `/cortex-critique` skill and wire it into cortex-clarify, cortex-research, and cortex-spec so that every Cortex gate transition includes an adversarial AI review before the gate advances.

---

## Deliverables

- Skill file: `skills/cortex-critique/SKILL.md`
- Edited skill: `skills/cortex-clarify/SKILL.md` (Phase 4c addition)
- Edited skill: `skills/cortex-research/SKILL.md` (Phase 2.9 addition)
- Edited skill: `skills/cortex-spec/SKILL.md` (Phase 1c addition)

---

## Scope

### In Scope

- New skill: `skills/cortex-critique/SKILL.md` — the critique engine with Codex CLI invocation, artifact-type routing, adversarial prompt template, three-tier severity, artifact persistence, and gate receipt writer
- Edit `skills/cortex-clarify/SKILL.md` — Phase 4c addition invoking cortex-critique after writing clarify brief
- Edit `skills/cortex-research/SKILL.md` — Phase 2.9 addition invoking cortex-critique after writing dossier
- Edit `skills/cortex-spec/SKILL.md` — Phase 1c addition invoking cortex-critique before contract approval gate
- Codex CLI invocation with `exec --full-auto` mode and adversarial prompt framing
- Three-tier severity routing (STOP/CAUTION/GO) per finding
- Critique artifact persistence: `docs/cortex/reviews/{slug}/critique-{gate}.md`
- `human_critique` autonomy gate (skippable in full-auto, active in supervised)
- Gate receipt written to `.cortex/state.json` `critique_receipts[]` array

### Out of Scope

- cortex-drive gate critique (follow-on slug after Phase 1 validates)
- Critique of code or implementation output (domain of cortex-review and cortex-audit)
- Full security red-team or STRIDE threat model pass
- Hard-blocking gate advancement based solely on AI critique — AI informs, human decides; STOP severity surfaces prominently but does not veto
- Retroactive critique of artifacts from prior closed slugs
- Calibration tooling for critique thresholds (post-launch concern, enabled by findings register)

---

## Write Roots

- `skills/cortex-critique/` — new skill directory and SKILL.md
- `skills/cortex-clarify/SKILL.md` — edit only
- `skills/cortex-research/SKILL.md` — edit only
- `skills/cortex-spec/SKILL.md` — edit only

---

## Done Criteria

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

## Validators

- [ ] [external] `test -f skills/cortex-critique/SKILL.md` — new skill file exists
- [ ] [external] `grep -q "codex exec --full-auto" skills/cortex-critique/SKILL.md` — Codex invocation present
- [ ] [external] `grep -q "adversarial critic" skills/cortex-critique/SKILL.md` — adversarial framing in prompt
- [ ] [external] `grep -q "STOP\|CAUTION\|GO" skills/cortex-critique/SKILL.md` — three-tier severity defined
- [ ] [external] `grep -q "cortex-critique" skills/cortex-clarify/SKILL.md` — clarify skill wired
- [ ] [external] `grep -q "cortex-critique" skills/cortex-research/SKILL.md` — research skill wired
- [ ] [external] `grep -q "cortex-critique" skills/cortex-spec/SKILL.md` — spec skill wired
- [ ] [external] `grep -q "human_critique" skills/cortex-critique/SKILL.md` — human_critique gate defined
- [ ] [external] `grep -q "critique_receipts" skills/cortex-critique/SKILL.md` — gate receipt writer present
- [ ] [judgment] AI critique runs and produces a valid critique artifact when invoked on a sample clarify brief — severity verdict present, at least one finding with quote and tier

---

## Eval Plan

docs/cortex/evals/gate-critique/eval-plan.md (pending)

---

## Approvals

- [x] Contract approval
- [ ] Evals approval

---

## Completion Promise

<!-- The executing agent MUST emit this signal when all done criteria are satisfied: -->
<!-- CORTEX_PROMISE: gate-critique-001 COMPLETE -->

---

## Failed Approaches

<!-- For initial contracts (contract-001.md), this section is empty. -->

---

## Why Previous Approach Failed

N/A — initial contract

---

## Rollback Hints

- Delete `skills/cortex-critique/` directory
- Revert edits to `skills/cortex-clarify/SKILL.md` (remove Phase 4c block)
- Revert edits to `skills/cortex-research/SKILL.md` (remove Phase 2.9 block)
- Revert edits to `skills/cortex-spec/SKILL.md` (remove Phase 1c block)
- Remove `critique_receipts` field from `.cortex/state.json` if added during testing

---

## Repair Budget

**max_repair_contracts:** 3
**cooldown_between_repairs:** 1
