# Phase 4: Documentation - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning
**Source:** Auto-populated from Cortex artifacts via /cortex-bridge

<domain>
## Phase Boundary

Add a new §7 Terminal States section to `docs/DISCOVERY_LOOP.md` documenting the seven-terminal taxonomy, the 4→7 refinement of necessity-gate verdicts, and the convergence-by-terminal-set-narrowing model. Cross-reference the new section from the existing §1 Mode Transitions and §4 Spec-Readiness Gate.

</domain>

<decisions>
## Implementation Decisions

The new §7 must include:

1. **Definition of each of the seven terminals** (Commit-to-Build, Kill-with-Learning, Decompose, Experiment-Required, Already-Exists, Hold-on-Dependency, Reframe-and-Continue) — at minimum: meaning, when reached, commit action, artifact produced.

2. **The 4→7 refinement mapping table** — explicit mapping from existing necessity-gate verdicts (BUILD/NARROW/DEFER/REJECT) to the seven terminals. The mapping is many-to-one in the "down" direction (each verdict refines into one or two terminals) and one-to-many in the "up" direction.

3. **Note that REJECT already names two terminals in its existing prose** — `/cortex-spec` SKILL.md line 128 says: *"This solves a problem that doesn't exist, OR the existing system already handles it."* The OR is exactly the Kill-with-Learning vs Already-Exists split. This makes the refinement mechanically grounded in existing code, not speculative.

4. **Convergence-by-terminal-set-narrowing model** — at each iteration, the set of possible terminals should narrow as evidence accumulates. The loop converges when the set has reduced to exactly one terminal. The brief's `initial_terminal_set:` declares the starting set; the `ruled_out:` field declares pre-rule-outs.

5. **Cross-references** — add a forward-pointer from §1 Mode Transitions (where `clarify` and `research` modes are described) and §4 Spec-Readiness Gate (where the existing 3 blockers are described) to the new §7.

### Claude's Discretion

Exact tone and depth of §7 should match §1-§6 of the existing DISCOVERY_LOOP.md. The executor should read the existing sections first to calibrate. Section length: ~60 lines is reasonable; longer if needed for clarity but not padding.

</decisions>

<canonical_refs>
## Canonical References

- docs/cortex/specs/clarify-research-loop/spec.md (§3 Architecture Decision describes the refinement)
- docs/cortex/specs/clarify-research-loop/gsd-handoff.md
- docs/cortex/contracts/clarify-research-loop/contract-001.md (Done Criteria 8 and 13)
- docs/cortex/research/clarify-research-loop/concept-20260412T012620Z.md (iter-3 dossier, the 4→7 refinement insight)
- docs/DISCOVERY_LOOP.md (file being modified — read §1-§6 for tone calibration)
- ~/.claude/skills/cortex-spec/SKILL.md lines 116-164 (existing necessity gate verdict logic — the source of truth for the 4 verdicts being refined)

</canonical_refs>

<specifics>
## Specific Ideas

The mapping table to include in §7:

| Necessity Verdict | Terminal Refinement | Notes |
|---|---|---|
| BUILD | commit-to-build | 1:1 — no refinement |
| NARROW | decompose OR reframe-and-continue | Split: hard split into N children vs scope-narrow same slug |
| DEFER | experiment-required OR hold-on-dependency | Split: closeable by bounded test vs blocked by external |
| REJECT | kill-with-learning OR already-exists | Split: no value vs value exists elsewhere |

Cross-references should use the existing DISCOVERY_LOOP.md cross-reference style (look at how §3 Uncertainty Register cross-references §1).

</specifics>

<deferred>
## Deferred Ideas

- Modifying `/cortex-spec` necessity gate prose to use the seven-terminal vocabulary directly — defer to a follow-up slug after pilot validates
- Adding examples of each terminal in DISCOVERY_LOOP.md from real shipped slugs — defer; the dogfood close of this slug will be the first such example

</deferred>

---

*Phase: 04-documentation*
*Context gathered: 2026-04-12 via /cortex-bridge*
