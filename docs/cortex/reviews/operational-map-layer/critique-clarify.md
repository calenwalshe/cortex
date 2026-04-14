# Critique: clarify — operational-map-layer

**Gate:** clarify
**Slug:** operational-map-layer
**Timestamp:** 2026-04-13T19:12:00Z
**Artifact:** docs/cortex/clarify/operational-map-layer/20260413T200000Z-clarify-brief.md
**Engine:** codex
**Overall Severity:** STOP

---

## Summary

This brief is structurally unstable: it declares key design choices as assumptions while also listing them as unresolved research questions. It also fails to specify the required output shape or measurable success criteria, so any downstream spec is likely to drift or be rejected.

---

## Findings (4 total — STOP: 2, CAUTION: 2, GO: 0)

### [STOP] consistency

**Finding:** The brief hard-commits to PostToolUse and session-ID grouping in Assumptions while simultaneously treating the hook payloads and grouping boundary as unresolved open questions. That is an internal contradiction: the design choice is presented as both decided and undecided.

**Quote from artifact:**
> - The PostToolUse hook (already proven for structural-indexer) is the right event for capturing individual Edit/Write events, not Stop or TaskCompleted — Stop fires after every response turn, not just session end
> ...
> - q1: What does the Stop hook actually fire on — every agent response turn or only at true session termination?
> ...
> - q4: What is the right co-change grouping unit — per-Stop-event, per-TaskCompleted, or session ID from PostToolUse payload

**Impact:** Downstream work will anchor on a supposedly settled implementation choice and skip the comparison the brief says is still required, producing a spec the owner can reject as internally incoherent.

---

### [STOP] unambiguity

**Finding:** The core output is too vague to implement: "surfacing hotspot and co-change context alongside the structural graph in clarify briefs and specs" never defines where it appears, in what schema, at what threshold, or how much data is injected. Multiple materially different specs could satisfy this sentence and still be rejected.

**Quote from artifact:**
> surfacing hotspot and co-change context alongside the structural graph in clarify briefs and specs so intelligence phases know which files are volatile and which are coupled before making scope decisions

**Impact:** Spec authors will invent incompatible output formats, payload sizes, and injection points, causing churn and rework when the owner rejects the presentation or budget impact.

---

### [CAUTION] verifiability

**Finding:** The brief claims success in terms of better scope decisions and more accurate risk assessment, but it defines no measurable acceptance criteria for those outcomes. The only hinted validation is an anecdotal retrospective on two briefs, which is not a falsifiable success condition.

**Quote from artifact:**
> enabling better write root selection and more accurate risk assessment
> ...
> - q6: What is the minimum hotspot + co-change payload that would have changed scope decisions in two recent clarify briefs

**Impact:** The team can build the ledger and still have no way to prove whether the feature works, leading to subjective debates and indefinite iteration.

---

### [CAUTION] framing attack

**Finding:** The brief prematurely narrows the solution to hook-based event capture plus a rolling on-disk ledger, excluding other plausible ways to derive operational signal before research has been done. That framing bakes in implementation rather than defining the problem to solve.

**Quote from artifact:**
> track which files get edited frequently (hotspots) and which files change together (co-change patterns) by recording Edit/Write events via the Stop and TaskCompleted hooks, storing a rolling edit ledger in .cortex/

**Impact:** Research is biased toward validating the preselected mechanism instead of comparing alternatives, which increases the risk of shipping a more complex or weaker solution than necessary.

---
