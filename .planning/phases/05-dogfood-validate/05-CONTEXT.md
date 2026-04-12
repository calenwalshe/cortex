# Phase 5: Dogfood + Validate - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning
**Source:** Auto-populated from Cortex artifacts via /cortex-bridge

<domain>
## Phase Boundary

Final phase. Three deliverables: (1) the working-example `current-understanding.md` for *this* slug populated from its three briefs and three dossiers, (2) three smoke tests on a throwaway test slug, (3) the dogfood close of this slug via `/cortex-close --terminal commit-to-build`. The dogfood close is itself the most important integration test — the slug must use its own new mechanism.

</domain>

<decisions>
## Implementation Decisions

**Deliverable 1: `docs/cortex/research/clarify-research-loop/current-understanding.md`** — populate the new template with this slug's actual content. Sections:

- **Possible Terminals**: at the start of this slug, all six non-transitional terminals were live. By the end (now), only `commit-to-build` is live; the other five are ruled out by the iter-3 reframe and the spec decision. Each ruled-out row should cite the artifact that ruled it out.
- **Durable Findings**: ~10 findings preserved across iterations — the dormant-loop discovery (iter-1 dossier), the necessity-gate refinement insight (iter-3 dossier), the ADR pattern (iter-2 dossier), the empty `experiments/` directory observation, etc. Each with source link.
- **Provisional Thoughts**: open spec-level details that were not fully resolved (e.g., should current-understanding.md auto-update on subsequent passes? what's the long-term command shape?). Mark explicitly as provisional.
- **Open Questions**: the deferred-gaps.md backlog items, moved here as future-slug candidates with their trigger-to-revisit conditions.
- **Iteration History**: 3-row table — iter 1 (brief, dossier, "(initial)"), iter 2 (brief, dossier, dormant-loop discovery + epistemic reframe), iter 3 (brief, dossier, philosophical-core gap).

**Deliverables 2-4: Three smoke tests** on a throwaway test slug:

```bash
# Test 1: Auto-write
/cortex-clarify "test slug for terminal flow"
test -f docs/cortex/research/eval-test-terminal-1/current-understanding.md
grep -q "Possible Terminals" docs/cortex/research/eval-test-terminal-1/current-understanding.md

# Test 2: Terminal-recording close
/cortex-close --terminal commit-to-build
grep -q "terminal: commit-to-build" docs/cortex/handoffs/decisions.md

# Test 3: Negative — ruled-out rejection
# (manually edit a test brief to add ruled_out: [kill-with-learning])
/cortex-close --terminal kill-with-learning
# Expect: error mentioning the field
```

**Deliverable 5: Dogfood close** — after Phases 1-4 are validated and Deliverables 1-4 are complete, run `/cortex-close --terminal commit-to-build` for this slug (`clarify-research-loop`). Verify the resulting `decisions.md` line includes `terminal: commit-to-build`.

### Claude's Discretion

The exact wording of the populated current-understanding.md sections is at executor's discretion as long as it's faithful to the iter-1/2/3 brief and dossier content. Reading is a heavy lift — budget time for it.

The throwaway test slug name should be memorable and clearly disposable (e.g., `eval-test-terminal-1`, `eval-test-terminal-2-rejected`).

</decisions>

<canonical_refs>
## Canonical References

- docs/cortex/specs/clarify-research-loop/spec.md
- docs/cortex/specs/clarify-research-loop/gsd-handoff.md
- docs/cortex/contracts/clarify-research-loop/contract-001.md (Done Criteria 9-12, 14)
- docs/cortex/clarify/clarify-research-loop/20260411T234737Z-clarify-brief.md (iter 1)
- docs/cortex/research/clarify-research-loop/concept-20260411T235252Z.md (iter 1)
- docs/cortex/clarify/clarify-research-loop/20260412T001619Z-clarify-brief.md (iter 2)
- docs/cortex/research/clarify-research-loop/concept-20260412T002407Z.md (iter 2)
- docs/cortex/clarify/clarify-research-loop/20260412T011953Z-clarify-brief.md (iter 3)
- docs/cortex/research/clarify-research-loop/concept-20260412T012620Z.md (iter 3)
- docs/cortex/clarify/clarify-research-loop/deferred-gaps.md (six follow-up slug candidates)
- templates/cortex/current-understanding.md (template to populate)

</canonical_refs>

<specifics>
## Specific Ideas

The dogfood close is the most important test — if the entire pipeline works for THIS slug (which used the conventions from the start in iter-2 and iter-3 of the brief), it works in production. If it doesn't work for this slug, the pilot has a critical bug.

Order of operations matters: do all of (1)-(4) BEFORE the dogfood close. Closing this slug makes its state read-only via the archive — there's no recovery if a smoke test fails after the dogfood close.

After the dogfood close, the eval execution path (`/cortex-eval-run`) runs against the eval plan. That's a separate skill invocation, not part of this phase's deliverables.

</specifics>

<deferred>
## Deferred Ideas

- Adding a "show me the full convergence trail for this slug" view that walks back through all iterations — defer; current-understanding.md is sufficient
- Cleaning up the throwaway test slugs from `decisions.md` after smoke tests pass — manual archive is fine for the pilot

</deferred>

---

*Phase: 05-dogfood-validate*
*Context gathered: 2026-04-12 via /cortex-bridge*
