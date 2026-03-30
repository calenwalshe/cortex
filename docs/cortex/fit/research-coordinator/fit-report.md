# Fit Report: research-coordinator

<!-- ART-FIT: Fit Report Template — produced by /cortex-fit -->
<!-- SC2 forced-separation: each section must not repeat content from any other section -->

**Slug:** research-coordinator
**Timestamp:** 20260330T183000Z
**Evaluated against:** Cortex v1.0 — skills/cortex-research/SKILL.md (--team flag), runtime-manifest.json agents list, cortex-critic agent, cortex-eval-designer agent
**Confidence:** high — full skill and manifest reads + research dossier at docs/cortex/research/cortex-ak-integration/concept-20260330T180000Z.md
**Status:** pending-human-decision

---

## Tech Radar Ring

**Ring:** Trial

**Justification:** --team flag exists but has no explicit orchestration logic; the coordinator pattern is novel and needs a bounded experiment to validate cost/quality trade-off.

---

## Gap

The `--team` flag on `/cortex-research` is declared in the skill signature with the description "invokes agent team for research (opt-in, adds cost)" but the Phase 2 instructions do not branch on `--team`. There is no defined coordinator agent, no fan-out pattern for parallel search subagents, no adversarial split for implementation research, and no explicit handoff from subagent workers to a synthesizer. `--team` is a named stub, not a working feature.

Specifically absent:
- Coordinator role definition (who fans out, who synthesizes)
- Phase-specific orchestration: concept → coordinator+3 search agents; implementation → adversarial pair; evals → critic+eval-designer pair
- Synthesis step: how worker outputs are merged into a single dossier
- Cost warning before agent spawn

---

## Overlap

`cortex-critic` and `cortex-eval-designer` are already defined as agents in `runtime-manifest.json`. The evals-phase coordinator pattern (critic + eval-designer pair) maps directly onto existing agents — no new agents needed for that phase. The multi-agent Agent tool invocation pattern is established in cortex skills. The `--team` flag already exists as the user-facing entry point.

---

## Unique Contribution

The adversarial split pattern for implementation research: one agent argues for the proposed approach, one argues against, a coordinator adjudicates. This is not the same as the critic pattern (which reviews a completed artifact) — it is an upstream divergent-perspective pattern applied during the research phase, before a position is formed. No existing agent or skill in cortex does this. It produces a richer implementation dossier by forcing both the strongest case and the strongest counter-case to be articulated before synthesis.

---

## Conflict

**Cost (hard constraint, not a blocker):** Three parallel search agents for concept research is 3x the token cost of solo research. This must be surfaced to the user before spawning — a cost warning and confirmation prompt is mandatory, not advisory. `--team` must never activate silently.

**Coordinator identity (design decision required):** There is no `cortex-coordinator` agent definition. Two options: (a) main session acts as coordinator — simpler, consistent with how the Agent tool works in other skills; (b) dedicated coordinator agent — adds overhead but isolates coordination logic. Option (a) is lower risk for v1. This is a design choice, not a conflict, but it must be decided before implementation.

**Non-fit boundary (soft, requires explicit enforcement):** The proposal specifies that `--team` semantics must never extend to execute or repair mode. This must be enforced in the skill via a mode guard — if `state.json.mode` is `execute` or `repair`, `--team` is silently ignored with a notice. Without this guard, future contributors may inadvertently wire team mode into execution.

---

## Strategic Direction

**Alignment:** aligned

Multi-agent research quality is a clear direction for cortex — the critic, eval-designer, and specifier agents are evidence of this. The coordinator pattern completes the multi-agent story for the research phase. The non-fit boundary (no swarm execution) is explicitly respected by this proposal, which keeps cortex from drifting into the execution swarm pattern that belongs to GSD.

---

## Pre-Populated Clarify Brief Fields

**Proposed goal:** Implement explicit orchestration logic for the `--team` flag on `/cortex-research` with phase-specific patterns: coordinator + 3 parallel search agents for concept, adversarial pair for implementation, cortex-critic + cortex-eval-designer for evals — all gated behind a cost warning and a mode guard that prevents activation in execute/repair.

**Constraints:**
- `--team` must display a cost warning and require confirmation before spawning agents
- Mode guard required: `--team` is a no-op (with notice) if state.json.mode is execute or repair
- Main session as coordinator is the v1 approach — no new coordinator agent definition until v1 is validated
- Adversarial split output must feed a synthesis step before writing the dossier — raw adversarial outputs alone are not a valid dossier

**Open questions:**
- Concept phase: 3 parallel search agents — what are the three search angles? (suggested: prior art, market/existing tools, analogues from adjacent domains)
- Implementation phase adversarial split: how is the "pro" vs "con" assignment made — are both agents given the same brief with opposing instructions, or is the brief split?
- Synthesis step: does the coordinator write the final dossier, or does it append a synthesis section to the worker outputs?
- Should `--team` be available for all three phases, or only concept and implementation in v1?

---

## Human Decision

**Status:** pending-human-decision

To advance: change status to `approved` or `rejected` and add a one-line note.

- [ ] Approved — proceed to `/cortex-clarify research-coordinator`
- [ ] Rejected — archive this report, no further action

**Decision note:** _(fill in when deciding)_
