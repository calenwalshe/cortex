# Spec: gate-critique

**Slug:** gate-critique
**Timestamp:** 20260412T090000Z
**Status:** draft

---

## 1. Problem

Cortex's intelligence pipeline (clarify → research → spec → contract) advances through gates that check structural conditions — does a contract exist? are assumptions backed? is there a slug conflict? — but none challenge whether the artifact being reviewed is actually correct, well-framed, or free of subtle errors. Bad framing at the clarify stage propagates undetected through research, spec, and contract before execution begins. The owner is currently the only adversarial voice at gates, but they review AI-generated artifacts without any independent critique to react to — they are approving in a vacuum. This slug adds a structured dual-critique step at each gate transition: an AI adversarial critique (Codex CLI, exec mode, explicit adversarial prompt) that always runs, followed by an owner plain-language response gate (skippable in full-auto), so bad assumptions and poor framing are caught before they become expensive execution work.

---

## 2. Acceptance Criteria

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

## 3. Scope

### In Scope

- New skill: `skills/cortex-critique/SKILL.md` — the critique engine
- Edit `skills/cortex-clarify/SKILL.md` — Phase 4c addition invoking cortex-critique
- Edit `skills/cortex-research/SKILL.md` — Phase 2.9 addition invoking cortex-critique
- Edit `skills/cortex-spec/SKILL.md` — Phase 1c addition invoking cortex-critique
- Codex CLI invocation with `exec --full-auto` mode and adversarial prompt framing
- Three-tier severity routing (STOP/CAUTION/GO) per finding
- Critique artifact persistence: `docs/cortex/reviews/{slug}/critique-{gate}.md`
- `human_critique` autonomy gate (skippable in full-auto, active in supervised)
- Gate receipt written to `.cortex/state.json` at each gate advance

### Out of Scope

- cortex-drive gate critique (follow-on slug after Phase 1 validates)
- Critique of code or implementation output (domain of cortex-review and cortex-audit)
- Full security red-team or STRIDE threat model pass
- Hard-blocking gate advancement based solely on AI critique — AI informs, human decides; STOP severity surfaces prominently but does not veto
- Retroactive critique of artifacts from prior closed slugs
- Calibration tooling for critique thresholds (post-launch concern, enabled by findings register)

---

## 4. Architecture Decision

**Chosen approach:** New `/cortex-critique` skill invoked at gate transitions by existing skills, using Codex CLI with `exec --full-auto` mode and an explicit adversarial framing prompt. Critique findings are persisted as separate artifacts per gate. The `human_critique` autonomy gate controls whether the owner sees findings before proceeding.

**Rationale:** Codex CLI exec mode creates a genuinely separate invocation context — the critic does not share the generating skill's conversation history, which is the root cause of same-model confirmation bias. Explicit adversarial framing in the prompt ("you are a critic, not an assistant; assume this artifact has problems") overcomes the model's default cooperative stance. A new standalone skill keeps critique dimensions versioned independently from the skills it serves.

### Alternatives Considered

- **cortex-critic subagent (Agent tool):** Shares the parent conversation context, risks confirmation bias from accumulated context. Also user explicitly specified Codex CLI. Rejected.
- **Self-critique (same model, same call):** Documented failure mode — same-model confirmation bias means the critic shares the assumptions it should be challenging. Rejected.
- **Extending cortex-review:** cortex-review is architecturally built for `git diff` inputs. Extending it to critique prose artifacts (clarify briefs, dossiers) would require major rework and muddle the skill's scope. Rejected.
- **Inline gate implementation (dimensions in each skill file):** Scatters dimension logic across 4+ skill files with no shared versioning. Updates to critique dimensions require editing every skill. Rejected.

---

## 5. Interfaces

- `docs/cortex/clarify/{slug}/*.md` — read by cortex-critique as input artifact (clarify gate)
- `docs/cortex/research/{slug}/*.md` — read by cortex-critique as input artifact (research gate)
- `docs/cortex/specs/{slug}/spec.md` — read by cortex-critique as input artifact (spec gate)
- `docs/cortex/reviews/{slug}/critique-{gate}.md` — written by cortex-critique; read by gate brief renderer and subsequent gate critique calls
- `.cortex/state.json` — read for slug context; written with `critique_receipts[]` gate receipt entries
- `skills/cortex-critique/SKILL.md` — new file (write); invoked by cortex-clarify, cortex-research, cortex-spec
- `skills/cortex-clarify/SKILL.md` — existing file (edit); Phase 4c addition
- `skills/cortex-research/SKILL.md` — existing file (edit); Phase 2.9 addition
- `skills/cortex-spec/SKILL.md` — existing file (edit); Phase 1c addition
- `codex` CLI binary — external tool; invoked as `codex exec --full-auto --profile llm --skip-git-repo-check --cd /tmp "<adversarial-prompt>"`

---

## 6. Dependencies

- **Codex CLI** — must be installed and accessible (`which codex`). cortex-critique checks availability at invocation start; if absent, falls back to running the adversarial prompt via `claude -p` with a warning logged.
- **cortex-clarify skill** (existing) — edited to invoke cortex-critique at Phase 4c
- **cortex-research skill** (existing) — edited to invoke cortex-critique at Phase 2.9
- **cortex-spec skill** (existing) — edited to invoke cortex-critique at Phase 1c
- **`.cortex/state.json`** — must support new `critique_receipts[]` array (backward compatible — field is added if absent, ignored if not present by legacy readers)

---

## 7. Risks

- **Codex CLI unavailable in some environments** — Mitigation: cortex-critique detects `which codex` at invocation start; falls back to `claude -p` with the same adversarial prompt and logs the fallback in the critique artifact header
- **Codex exec output format varies** — Mitigation: cortex-critique wraps the Codex call and parses JSON from stdout with a regex boundary; if JSON parse fails, the raw output is saved in the critique artifact and severity defaults to CAUTION
- **Critique noise degrades trust** — Mitigation: adversarial prompt requires minimum 1 finding or explicit zero-justification; three-tier routing prevents INFO noise from surfacing at gates; findings register enables post-launch threshold tuning
- **Skill edits to cortex-clarify/spec/research break existing gate flow** — Mitigation: cortex-critique invocation is additive (does not replace any existing gate logic); if cortex-critique itself fails (non-zero exit), the gate proceeds with a CRITIQUE_FAILED warning in state.json
- **Same-model confirmation if adversarial prompt is weak** — Mitigation: prompt explicitly states "you are a critic, not an assistant; assume this artifact has at least 2 significant problems; justify zero findings explicitly"; Codex exec mode isolates the call from generating context

---

## 8. Sequencing

1. Write `skills/cortex-critique/SKILL.md` — standalone skill with Codex invocation, artifact-type routing, adversarial prompt template, three-tier severity, artifact persistence, and gate receipt writer. This is the foundation — nothing else can be built without it.
2. Manually verify Codex exec invocation against a sample clarify brief — confirm JSON output is produced and parseable.
3. Edit `skills/cortex-clarify/SKILL.md` — add Phase 4c: invoke cortex-critique after writing clarify brief.
4. Edit `skills/cortex-research/SKILL.md` — add Phase 2.9: invoke cortex-critique after writing dossier.
5. Edit `skills/cortex-spec/SKILL.md` — add Phase 1c: invoke cortex-critique against spec.md before contract approval gate.
6. Smoke test end-to-end: run a `/cortex-clarify` call on a test slug, confirm `docs/cortex/reviews/test-slug/critique-clarify.md` is produced.

---

## 9. Tasks

- [ ] Write `skills/cortex-critique/SKILL.md` with: artifact-type detection (brief/dossier/spec/contract), Codex exec invocation with adversarial prompt, JSON output parsing with fallback, three-tier severity routing (STOP/CAUTION/GO), critique artifact writer, gate receipt writer to `.cortex/state.json`
- [ ] Define critique dimensions per artifact type in the skill: brief (completeness, unambiguity, consistency, verifiability, framing attack), dossier (evidence adequacy, source authority, finding-to-question traceability, assumption backing), spec (AC testability, scope coherence, risk completeness), contract (done criteria verifiability, validator coverage, write roots completeness)
- [ ] Write the adversarial Codex prompt template with: role declaration ("you are an adversarial critic, not an assistant"), minimum finding requirement with zero-justification escape, artifact-type-specific dimension list, JSON output schema (`severity`, `findings[]` with tier/dimension/finding/quote/impact, `summary`)
- [ ] Add `human_critique` gate to the autonomy gate table in cortex-critique; document: skippable in full-auto, active in supervised; when active, owner sees AI findings in plain language before gate advances
- [ ] Edit `skills/cortex-clarify/SKILL.md` Phase 4: add Phase 4c — invoke cortex-critique on the clarify brief, persist to `docs/cortex/reviews/{slug}/critique-clarify.md`, write gate receipt
- [ ] Edit `skills/cortex-research/SKILL.md` Phase 3: add Phase 2.9 — invoke cortex-critique after dossier write, persist to `docs/cortex/reviews/{slug}/critique-dossier-{timestamp}.md`, write gate receipt
- [ ] Edit `skills/cortex-spec/SKILL.md` Phase 1: add Phase 1c — invoke cortex-critique on spec.md before contract approval gate, persist to `docs/cortex/reviews/{slug}/critique-spec.md`, write gate receipt
- [ ] Smoke test: confirm critique artifact is produced at the correct path after a `/cortex-clarify` invocation on a test slug
