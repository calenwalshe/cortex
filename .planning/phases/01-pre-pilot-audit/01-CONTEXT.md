# Phase 1: Pre-pilot Retroactive Audit - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning
**Source:** Auto-populated from Cortex artifacts via /cortex-bridge

<domain>
## Phase Boundary

Validate the 4→7 refinement of the necessity-gate verdicts empirically against historical decisions.md entries BEFORE writing any code. This is a hard gate: if the audit fails (<60% mapping rate at confidence ≥0.7), the pilot stops and the slug returns to clarify. If it passes, Phase 2 begins.

</domain>

<decisions>
## Implementation Decisions

The audit reads `docs/cortex/handoffs/decisions.md`, greps for `gate: necessity | verdict:` entries, and for each non-BUILD verdict (NARROW, DEFER, REJECT), classifies which of the seven terminals it should map to in retrospect with a confidence score and 1-2 sentence reasoning. Output is `docs/cortex/research/clarify-research-loop/audit-results-{timestamp}.md` with a Markdown table.

Pass criterion: ≥60% of non-BUILD verdicts have confidence ≥0.7 AND a clean terminal assignment.

The 4→7 mapping (per iter-3 dossier):
- BUILD → commit-to-build (1:1)
- NARROW → {decompose, reframe-and-continue}
- DEFER → {experiment-required, hold-on-dependency}
- REJECT → {kill-with-learning, already-exists}

### Claude's Discretion

The audit is performed manually (read decisions.md, classify each row). No automation or LLM agent involved — the point is empirical validation by a human (or an LLM with explicit reasoning) reading the actual historical context for each verdict.

</decisions>

<canonical_refs>
## Canonical References

- docs/cortex/specs/clarify-research-loop/spec.md
- docs/cortex/specs/clarify-research-loop/gsd-handoff.md
- docs/cortex/contracts/clarify-research-loop/contract-001.md
- docs/cortex/clarify/clarify-research-loop/20260412T011953Z-clarify-brief.md (iter 3)
- docs/cortex/research/clarify-research-loop/concept-20260412T012620Z.md (iter 3 — defines the 4→7 refinement)
- docs/cortex/handoffs/decisions.md (audit input)

</canonical_refs>

<specifics>
## Specific Ideas

The audit results file should record at minimum: slug name, verdict (NARROW/DEFER/REJECT), confidence (0.0-1.0), proposed terminal, 1-2 sentence reasoning per row. A summary line at the bottom shows the mapping rate.

If the audit reveals fewer than 3 historical non-BUILD verdicts in decisions.md (small sample size), document the limitation explicitly in the audit results — the threshold check still applies but the result should be flagged as "small sample."

</specifics>

<deferred>
## Deferred Ideas

- Automated audit (e.g., a script that does the classification) — defer; manual is simpler for the pilot
- Cross-slug audit dashboard — defer; this is a one-shot pre-pilot check

</deferred>

---

*Phase: 01-pre-pilot-audit*
*Context gathered: 2026-04-12 via /cortex-bridge*
