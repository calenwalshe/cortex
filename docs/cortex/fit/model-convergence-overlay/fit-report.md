# Fit Report: model-convergence-overlay

<!-- ART-FIT: Fit Report Template — produced by /cortex-fit -->
<!-- SC2 forced-separation: each section must not repeat content from any other section -->

**Slug:** model-convergence-overlay
**Timestamp:** 20260330T183000Z
**Evaluated against:** Cortex v1.0 — cortex-critic agent, cortex-eval-designer agent, cortex-spec/SKILL.md, cortex-research/SKILL.md (--team flag), runtime-manifest.json agents list
**Confidence:** high — full agent manifest and skill reads + research dossier at docs/cortex/research/cortex-ak-integration/concept-20260330T180000Z.md
**Status:** pending-human-decision

---

## Tech Radar Ring

**Ring:** Assess

**Justification:** The goal is sound but model homogeneity makes same-model convergence self-review; model routing infrastructure doesn't exist yet.

---

## Gap

No automated multi-model review of high-stakes artifacts exists. The cortex-critic is invoked explicitly by the user or by cortex-review — it is never automatically triggered as part of an approval gate. There is no `--converge` flag on any command. There is no pattern for "run an independent reader on this artifact before surfacing the approval prompt." High-stakes artifacts (spec.md, eval-plan.md, security audit reports) can reach approval-pending status without any adversarial review having occurred.

---

## Overlap

`cortex-critic` (adversarial reviewer) — already performs exactly the analysis that convergence wants, for spec and contract artifacts. It is invoked via `/cortex-review` or directly. The gap is automation, not capability: the critic exists and works; it just isn't wired into the approval gate.

`cortex-eval-designer` (eval suite proposer) — already provides a second read on evaluation dimensions. Used in the evals research phase.

`--team` flag on `/cortex-research` — already invokes an agent team for research tasks. The multi-agent pattern is established.

`cortex-task-completed.sh` approval gate — already blocks completion on eval failures. The gate mechanism that convergence would extend already exists.

---

## Unique Contribution

Model routing: running the critic agent on a different model than the artifact author (e.g., Opus critiquing a Sonnet-authored spec). This is not currently possible in cortex — all agents inherit the session model. Model routing would require per-agent model configuration in the agent definition files and a dispatch mechanism in the installer. This is genuinely new infrastructure, not a variation of anything existing.

---

## Conflict

**Model homogeneity (hard blocker for genuine convergence):** If cortex-critic runs on the same model as the spec author, the "convergence" is self-review with a role label. Same-model critique is not independent. This is the most important finding. For v1, same-model is better than nothing (the critic prompt forces adversarial framing even on the same model) — but it should be documented as a known limitation, not presented as true convergence.

**No model routing infrastructure (architectural prerequisite):** Agent definitions in cortex (cortex-critic.md etc.) do not currently support per-agent model specification. Adding this requires changes to the agent definition schema and the installer. This is not a reason to reject the proposal, but it means the full value of the proposal is gated on infrastructure that doesn't exist.

**Critic paralysis risk (soft tension):** If every high-stakes artifact requires a critic pass before approval, and the critic always surfaces findings, the approval loop becomes a negotiation rather than a gate. Mitigation: severity tiers — only CRITICAL/HIGH critic findings block; MEDIUM/LOW are advisory. This must be specified in the critic agent definition before automation is added.

---

## Strategic Direction

**Alignment:** partially aligned

The goal (independent verification of high-stakes artifacts) is directly aligned with cortex's quality and honesty principles. The trajectory is right. The misalignment is timing — the model routing prerequisite means the proposal's full value cannot be realized with the current infrastructure. Implementing convergence on same-model now, with a documented upgrade path to model routing, is the pragmatic partial-alignment path.

---

## Pre-Populated Clarify Brief Fields

**Proposed goal:** Add a `--converge` flag to cortex-spec, cortex-research (--phase evals), and cortex-audit (--comprehensive) that invokes cortex-critic on the produced artifact before surfacing the approval prompt, appending critic output as a `## Critic Review` section with severity-tiered findings.

**Constraints:**
- Same-model critique is acceptable for v1 but must be documented as limited convergence, not true independence
- Only CRITICAL and HIGH severity critic findings may block approval; MEDIUM/LOW are advisory
- Model routing (per-agent model config) is a v2 prerequisite for genuine convergence — do not promise it in v1 scope
- `--converge` must be an opt-in flag, not default, until cost/latency profile is validated

**Open questions:**
- Is same-model convergence worth shipping as v1, or should it wait for model routing infrastructure?
- Should `--converge` be a flag or a mode in state.json (affects whether it persists across a session)?
- What is the severity tier schema for cortex-critic findings — does the critic agent definition need to be updated first?
- Should cortex-audit --comprehensive enable convergence by default (as proposed) or require explicit --converge?

---

## Human Decision

**Status:** pending-human-decision

To advance: change status to `approved` or `rejected` and add a one-line note.

- [ ] Approved — proceed to `/cortex-clarify model-convergence-overlay`
- [ ] Rejected — archive this report, no further action

**Decision note:** _(fill in when deciding)_
