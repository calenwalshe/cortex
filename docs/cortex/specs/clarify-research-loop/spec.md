# Spec: clarify-research-loop

**Slug:** clarify-research-loop
**Timestamp:** 20260412T013145Z
**Status:** draft

> **Authoritative substrate:** clarify brief iteration 3 (`20260412T011953Z-clarify-brief.md`) + concept dossier iteration 3 (`concept-20260412T012620Z.md`). Prior iterations and the deferred-gaps backlog are referenced but not load-bearing. The seven-terminal taxonomy and the necessity-gate refinement (4→7) are the philosophical and mechanical cores.

---

## 1. Problem

The Cortex pre-spec phase currently has a hidden assumption that every slug is heading toward `/cortex-spec`. Mechanisms exist to detect when research should reframe a brief (`reclarify_required` field, mandatory `reclarify` gate, `cortex-experiment` skill, structured uncertainty register), but they have never fired in practice — the trigger criteria are soft prose that the LLM never trips. More fundamentally, the pipeline cannot recognize valid resolutions other than "produce a spec": a slug whose correct resolution is "this already exists, activate it" or "we should kill this with the learning preserved" has no clean exit. The owner — the human-on-the-loop observer — has no way to ask "what do I currently understand about this slug?" or "which resolution am I heading toward?" without manually reading every dossier. The result is that slugs drift toward Build by default, and the loop's actual job — finding the *right* terminal state for each slug — is invisible.

---

## 2. Scope

### In Scope

- Add a `--terminal {name}` flag to `/cortex-close` that records which of seven terminal states the slug closed at, with backward-compatible extension of the `decisions.md` archive line format.
- Define the seven terminal states (Commit-to-Build, Kill-with-Learning, Decompose, Experiment-Required, Already-Exists, Hold-on-Dependency, Reframe-and-Continue) as a documented vocabulary, with mapping to existing `/cortex-spec` necessity-gate verdicts (BUILD/NARROW/DEFER/REJECT) as a 4→7 refinement.
- Create a new artifact template `templates/cortex/current-understanding.md` with sections for Possible Terminals (table), Durable Findings, Provisional Thoughts, Open Questions, and Iteration History.
- Extend `/cortex-clarify` to auto-write the initial `current-understanding.md` for a slug from the brief's YAML frontmatter `initial_terminal_set` field at brief-write time.
- Document two new optional clarify brief frontmatter fields (`initial_terminal_set:` array and `ruled_out:` array) in `templates/cortex/clarify-brief.md` and the `/cortex-clarify` SKILL, with sensible defaults (all six non-transitional terminals on, none ruled out).
- Run a pre-pilot retroactive audit of historical `gate: necessity | verdict:` entries in `decisions.md` to validate that the 4→7 refinement is clean against past data. The audit is itself the first micro-experiment under the new philosophy.
- Update `docs/DISCOVERY_LOOP.md` to reference the seven-terminal taxonomy and the refinement of necessity-gate verdicts.
- Dogfood the entire loop on the `clarify-research-loop` slug itself — close it via `/cortex-close --terminal commit-to-build` and produce a final `current-understanding.md` for this slug as part of the deliverable.

### Out of Scope

- New commands `/cortex-decompose`, `/cortex-hold`, `/cortex-kill` — defer until a slug actually reaches one of those terminals (deferred-gap candidates).
- Per-terminal artifact templates (`kill-rationale.md`, `decomposition.md`, `use-existing.md`, `hold-trigger.md`) — defer; design empirically when the first slug needs them.
- Modifying the `/cortex-spec` necessity gate to produce 7 verdicts instead of 4 — defer; pilot the refinement layer first to validate the mapping in practice before touching `/cortex-spec`.
- Cross-artifact frontmatter sync mechanism (a script that auto-updates `current-understanding.md` when the brief changes) — defer; manual update at clarify time is sufficient for the pilot.
- Fact extraction pipeline from dossiers to `facts.jsonl` — separate concern, listed in deferred-gaps.md.
- Iteration history log as a separate artifact — covered by the Iteration History section of `current-understanding.md`.
- Uncertainty register writeback — separate concern.
- Stage-gate Go/Kill/Hold/Recycle interactive verdict UI — the mechanical Reframe Trigger check (already covered by the necessity gate's existing logic) is sufficient for the pilot.
- Promoting `--terminal` flag values to specialized commands (e.g., `/cortex-kill`) — long-term refinement, not pilot scope.

---

## 3. Architecture Decision

**Chosen approach:** Layer the seven-terminal taxonomy on top of the existing `/cortex-spec` necessity gate as a 4→7 *refinement*, not a replacement. The pilot ships as three small additions: (a) a `--terminal {name}` flag on `/cortex-close` that records terminal state in `decisions.md`, (b) a new `current-understanding.md` template with a Possible Terminals table that derives from the clarify brief's `initial_terminal_set` frontmatter, (c) a `/cortex-clarify` extension that auto-writes the initial `current-understanding.md` for each slug. The new flow is unconditional (every `/cortex-close` requires `--terminal`), the convention is documented in templates so all future slugs adopt it, and the model is empirically validated before code is written via a retroactive audit of historical necessity verdicts.

**Rationale:** The iteration-3 dossier identified that the existing necessity gate already produces four verdicts (BUILD, NARROW, DEFER, REJECT) that map cleanly onto the seven terminals as a 4→7 refinement, and the existing REJECT verdict description already names two distinct cases ("solves a problem that doesn't exist OR the existing system already handles it") that correspond exactly to Kill-with-Learning vs Already-Exists. This means the conceptual machinery for the seven-terminal model is already latent in the codebase — the work is elevating and refining it, not building it. The MVP scope (1 SKILL change + 1 template + 1 SKILL extension + 1 doc convention) is small enough to ship in one slug while still producing a complete pilot. The retroactive audit is the cheapest possible test of whether the model holds against real data, matching the iteration-3 brief's "little tests build to decision gates" philosophy by being a self-experiment.

### Alternatives Considered

- **Top-down ship of all 9 gap closures from iter-2 dossier (decomposition skill, fact extraction pipeline, etc.):** rejected — 3-5x larger than prior slugs; speculative; reproduces dormant-loop failure mode at higher cost.
- **Add per-terminal commands (`/cortex-decompose`, `/cortex-hold`, `/cortex-kill`) and artifact templates up front:** rejected — speculative specialization without empirical usage data; CLI design literature recommends starting polymorphic and promoting to specialized once usage patterns are known.
- **Subsume the necessity gate by modifying `/cortex-spec` to produce 7 verdicts directly:** rejected for the pilot — touches core infrastructure, creates a backward-compat fork in decisions.md verdict history, and is irreversible. Defer until the pilot validates the refinement is correct.
- **Auto-derive `current-understanding.md` from the brief via a sync script:** rejected — no precedent for cross-artifact frontmatter sync in Cortex; manual update at clarify time is sufficient for MVP and avoids introducing a new sync primitive.
- **Build a `/cortex-converge` skill between research and spec:** rejected — adds new surface area when the existing surface (`/cortex-close`, `/cortex-spec`, the necessity gate) already has the right hooks. The dormant-loop failure showed that adding new mechanisms without fixing the existing dormant ones is the wrong move.
- **Build a separate `/cortex-resolve --terminal {name}` command instead of extending `/cortex-close`:** rejected — `/cortex-close` already does exactly what's needed (state transition, archive, decisions.md log); adding a flag is purely additive. A new top-level command would be redundant.
- **Add an 8th terminal for RFC "Steady State" (consensus reached but no decision to act):** rejected — covered by Hold-on-Dependency with a "manual re-entry" trigger; adding a marginal-case terminal violates simplicity.

---

## 4. Interfaces

- **`/cortex-close` SKILL** — `.claude/skills/cortex-close/SKILL.md` and `skills/cortex-close/SKILL.md`. This spec extends Phase 5 (decisions.md write) and adds argument validation. Reads: state.json, clarify brief frontmatter (to validate `--terminal` value against brief's allowed terminal set). Writes: extended decisions.md archive line; state.json (existing reset behavior).
- **`/cortex-clarify` SKILL** — `.claude/skills/cortex-clarify/SKILL.md` and `skills/cortex-clarify/SKILL.md`. This spec adds a Phase 4b (after artifact write) that conditionally writes `current-understanding.md` for the slug if it does not already exist, populating Possible Terminals from the brief frontmatter. Reads: brief frontmatter; existing `current-understanding.md` for the slug (to check existence). Writes: `docs/cortex/research/{slug}/current-understanding.md` (new file on first call, no-op on subsequent calls — updates are deferred to a future slug).
- **`templates/cortex/clarify-brief.md`** — extended with documentation of two optional frontmatter fields: `initial_terminal_set:` (list of terminal slugs; default: all six non-transitional) and `ruled_out:` (list; default: empty). Backward-compatible — existing briefs without these fields use defaults.
- **`templates/cortex/current-understanding.md`** — new file. Schema documented in section 8 below.
- **`docs/cortex/handoffs/decisions.md`** — Archive Index format extended to include optional `terminal: {name}` field. Backward-compatible — legacy entries simply lack the field.
- **`docs/DISCOVERY_LOOP.md`** — extended with a new section documenting the seven-terminal taxonomy and the 4→7 refinement of necessity-gate verdicts.
- **`docs/cortex/research/clarify-research-loop/current-understanding.md`** — produced as a deliverable for *this* slug; demonstrates the new template in production use.

---

## 5. Dependencies

- **Existing `/cortex-close` skill** — owned by Cortex; this spec modifies its argument schema and Phase 5 logic.
- **Existing `/cortex-clarify` skill** — owned by Cortex; this spec adds a new Phase 4b for current-understanding.md generation.
- **Existing `/cortex-spec` necessity gate logic** — owned by Cortex; not modified by this spec, but the seven-terminal taxonomy explicitly refines its verdict vocabulary. The existing 4-verdict logic continues to work unchanged.
- **`docs/cortex/handoffs/decisions.md`** — owned by Cortex; existing format is extended with an optional field.
- **`docs/DISCOVERY_LOOP.md`** — authoritative discovery loop reference; extended with a new section.
- **`templates/cortex/clarify-brief.md`** — Cortex template; extended with new optional frontmatter.
- **`docs/cortex/clarify/clarify-research-loop/`** — this slug's own clarify briefs and current-understanding.md serve as the working example deliverable.
- No external libraries, no new third-party services, no infrastructure changes. Pure markdown + skill prose changes.

---

## 6. Risks

- **Risk: the dormant-loop failure mode reproduces — the new flow ships but nobody invokes it.** — Mitigation: make `--terminal` mandatory on every `/cortex-close` invocation (no optional flag, no opt-in). Validate the failure mode is closed by closing this slug itself as the first user of the new mechanism. Track adoption by grepping `decisions.md` for `terminal:` field over the next 5 closed slugs.
- **Risk: the 4→7 refinement does not hold against real history (retroactive audit fails).** — Mitigation: run the audit BEFORE writing any code (recommendation 1 of the iter-3 dossier). If <60% of historical NARROW/DEFER/REJECT verdicts can be cleanly assigned a finer terminal, pause the pilot and re-clarify rather than shipping a broken model.
- **Risk: the `current-understanding.md` doc becomes stale because it is manually updated.** — Mitigation: scope the pilot to "write at clarify time only" — no expectation of synchronization with research dossiers in this iteration. If staleness is felt as a pain, that becomes the trigger for a follow-up sync slug from the deferred-gaps backlog.
- **Risk: brief authors do not adopt the `initial_terminal_set` frontmatter field, defaulting to all-six everywhere, making the field useless.** — Mitigation: document the field with a worked example in the template; pre-populate it in the iteration-3 brief of *this* slug (already done) as the canonical example; add a note in the `/cortex-clarify` SKILL prompting the author to consider whether any terminals should be pre-ruled-out.
- **Risk: the `--terminal` flag value is not validated against the brief's allowed set, allowing users to close at terminals that were never on the table.** — Mitigation: include argument validation in the `/cortex-close` Phase 1 (after reading state.json and the brief) — refuse the close with a clear error if the chosen terminal was in `ruled_out: []` of the brief.
- **Risk: scope creep — once the spec is approved, the implementer adds "while we're here" features from the deferred-gaps backlog.** — Mitigation: contract done_criteria explicitly enumerate the 4 deliverables (1 SKILL change, 1 template, 1 SKILL extension, 1 doc update), the audit, and the dogfood close. Anything else is a contract violation.
- **Risk: the necessity gate audit (pre-pilot validation) reveals that the 4→7 mapping is judgment-dependent, not mechanical.** — Mitigation: this is a feature, not a bug — the audit's failure mode is "the model needs more thinking before code." Treat it as a gate, not a formality. If it fails, return to clarify.

---

## 7. Sequencing

1. **Pre-pilot retroactive audit (~30 min, no code).** Grep `docs/cortex/handoffs/decisions.md` for all entries matching `gate: necessity | verdict:`. For each non-BUILD verdict, manually classify which of the seven terminals it should have mapped to in retrospect. Produce `docs/cortex/research/clarify-research-loop/audit-results-{ts}.md` with a small results table: `slug | verdict | confidence | terminal | reasoning`. **Pass criterion: ≥60% of non-BUILD verdicts can be cleanly mapped to a finer terminal with confidence ≥0.7.** If pass: proceed to step 2. If fail: stop and re-clarify.
2. **Update `templates/cortex/clarify-brief.md`** to document the `initial_terminal_set:` and `ruled_out:` YAML frontmatter fields. Include a worked example (the iter-3 brief of this slug). Both fields are optional with sensible defaults.
3. **Create `templates/cortex/current-understanding.md`** with the schema defined in Tasks below. Lightweight (~50 lines), all sections optional except Possible Terminals.
4. **Modify `/cortex-clarify` SKILL** to add Phase 4b: after writing the brief, if `docs/cortex/research/{slug}/current-understanding.md` does not exist, write it from the template, populating the Possible Terminals table from the brief's `initial_terminal_set` frontmatter (defaulting to all six if absent). No-op if the file already exists.
5. **Modify `/cortex-close` SKILL** to add `--terminal {name}` as a required flag. Validate the value against the seven allowed terminal slugs. If the active brief has a non-empty `ruled_out:` field, refuse close with the chosen terminal if it appears there. Extend Phase 5 to write the terminal value into the `decisions.md` Archive Index line as a new field.
6. **Update `docs/DISCOVERY_LOOP.md`** with a new section documenting the seven-terminal taxonomy and the necessity-gate refinement. Cross-reference the new section from sections §1 (Mode Transitions) and §4 (Spec-Readiness Gate).
7. **Dogfood close: produce `docs/cortex/research/clarify-research-loop/current-understanding.md` for this slug**, populated with the durable findings, provisional thoughts, open questions, and iteration history extracted from this slug's three briefs and three dossiers. This is the working-example deliverable for the new template.
8. **Validate end-to-end on this slug:** when the work is complete and the contract is approved-and-implemented, close this slug via `/cortex-close --terminal commit-to-build`. Verify the new decisions.md line includes the `terminal:` field. Verify the retroactive audit results are preserved in the archive.

---

## 8. Tasks

- [ ] Run pre-pilot retroactive necessity-verdict audit; produce `docs/cortex/research/clarify-research-loop/audit-results-{timestamp}.md` with results table and pass/fail verdict
- [ ] Update `templates/cortex/clarify-brief.md` to document `initial_terminal_set:` and `ruled_out:` optional YAML frontmatter fields with worked example
- [ ] Create `templates/cortex/current-understanding.md` with sections: Possible Terminals (table with columns Terminal, Status, Ruled-Out Reason, Evidence), Durable Findings, Provisional Thoughts, Open Questions, Iteration History
- [ ] Modify `.claude/skills/cortex-clarify/SKILL.md` to add Phase 4b: auto-write `current-understanding.md` from brief frontmatter if it does not exist
- [ ] Modify `skills/cortex-clarify/SKILL.md` (project-local copy) to match
- [ ] Modify `.claude/skills/cortex-close/SKILL.md` to add required `--terminal {name}` flag with validation against the seven terminal slugs and against brief's `ruled_out:` field
- [ ] Modify `skills/cortex-close/SKILL.md` (project-local copy) to match
- [ ] Modify `/cortex-close` Phase 5 to extend the `decisions.md` Archive Index line format with `terminal: {name}` field; update format comment in `docs/cortex/handoffs/decisions.md` line ~29
- [ ] Update `docs/DISCOVERY_LOOP.md` with a new section "§7 Terminal States" documenting the seven terminals and the 4→7 refinement mapping; cross-reference from §1 and §4
- [ ] Produce `docs/cortex/research/clarify-research-loop/current-understanding.md` for this slug as the working example, populated from the three briefs and three dossiers
- [ ] Move the six deferrals from the iter-2 deferred-gaps.md into the explicit "future-slug candidates" section of this slug's current-understanding.md, with the same trigger-to-revisit conditions
- [ ] Update the `templates/cortex/clarify-brief.md` example brief to show `initial_terminal_set:` and `ruled_out:` in the frontmatter as the canonical pattern
- [ ] Add a brief documentation note in the `/cortex-clarify` SKILL output that when iteration > 1, the iteration metadata fields (`iteration:`, `supersedes:`, `informed_by:`, `reframe_reason:`) are required (already established as convention in this slug's iter-2 and iter-3 briefs)

---

## 9. Acceptance Criteria

- [ ] Retroactive audit results file exists at `docs/cortex/research/clarify-research-loop/audit-results-{timestamp}.md` with a complete table of historical non-BUILD necessity verdicts and their proposed terminal mapping
- [ ] Audit pass criterion is met: ≥60% of historical non-BUILD verdicts can be cleanly mapped to a finer terminal with confidence ≥0.7, with reasoning recorded per row
- [ ] `templates/cortex/clarify-brief.md` documents `initial_terminal_set:` and `ruled_out:` YAML frontmatter fields with at least one worked example
- [ ] `templates/cortex/current-understanding.md` exists with all five sections (Possible Terminals, Durable Findings, Provisional Thoughts, Open Questions, Iteration History) and is well-formed Markdown
- [ ] `.claude/skills/cortex-clarify/SKILL.md` and `skills/cortex-clarify/SKILL.md` both contain a Phase 4b that writes `current-understanding.md` from the brief frontmatter when the file does not exist
- [ ] `.claude/skills/cortex-close/SKILL.md` and `skills/cortex-close/SKILL.md` both require `--terminal {name}` as a flag, validate against the seven allowed values, and reject values that appear in the brief's `ruled_out:` field
- [ ] The `decisions.md` Archive Index format includes `terminal: {name}` as a documented field; the format comment at the top of the section is updated
- [ ] `docs/DISCOVERY_LOOP.md` contains a new section documenting the seven-terminal taxonomy and the 4→7 refinement of necessity-gate verdicts; the section is cross-referenced from §1 and §4
- [ ] `docs/cortex/research/clarify-research-loop/current-understanding.md` exists and is populated with the durable findings, provisional thoughts, open questions, and iteration history of this slug — serving as the canonical working example
- [ ] Running `/cortex-clarify` on a fresh test slug produces a new `current-understanding.md` automatically with the Possible Terminals table populated from the default initial_terminal_set
- [ ] Running `/cortex-close --terminal commit-to-build` on a test slug succeeds and writes a `decisions.md` line containing the `terminal:` field
- [ ] Running `/cortex-close --terminal kill-with-learning` on a test slug whose brief has `ruled_out: [kill-with-learning]` is rejected with a clear error
- [ ] All seven terminal slugs (commit-to-build, kill-with-learning, decompose, experiment-required, already-exists, hold-on-dependency, reframe-and-continue) are documented in at least one of: clarify brief template, DISCOVERY_LOOP.md §7, or current-understanding.md template
- [ ] [external] `grep -n "terminal:" docs/cortex/handoffs/decisions.md` returns at least one match (this slug's own close) after the pilot
- [ ] [external] `grep -n "initial_terminal_set" templates/cortex/clarify-brief.md` returns matches
- [ ] [external] `grep -n "Possible Terminals" templates/cortex/current-understanding.md` returns a match
- [ ] [external] `test -f templates/cortex/current-understanding.md`
- [ ] [external] `test -f docs/cortex/research/clarify-research-loop/current-understanding.md`
- [ ] [judgment] The current-understanding.md for this slug is readable and useful — a future reader (the owner or another developer) can understand "what we currently know about this slug" without reading the full brief and dossier history
- [ ] [judgment] The DISCOVERY_LOOP.md §7 section explains the seven terminals clearly enough that a new contributor can understand the taxonomy without prior context
