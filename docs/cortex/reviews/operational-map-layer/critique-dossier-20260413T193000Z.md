# Critique: dossier — operational-map-layer

**Gate:** dossier
**Slug:** operational-map-layer
**Timestamp:** 2026-04-13T19:30:00Z
**Artifact:** docs/cortex/research/operational-map-layer/concept-20260413T193000Z.md
**Engine:** codex
**Overall Severity:** STOP

---

## Summary

This dossier overclaims certainty. It locks in a single design path using unproven exclusivity, backs key storage decisions with unsupported numbers, and treats unresolved thresholds as if the research is complete.

---

## Findings (4 total — STOP: 2, CAUTION: 2, GO: 0)

### [STOP] assumption backing

**Finding:** The dossier hard-locks the architecture on an exclusivity claim it never proves. It inspects a narrow set of existing hooks and files, then jumps to "only viable capture mechanism" and "design is confirmed" without demonstrating that no other additive PostToolUse fields, alternate grouping keys, or new capture points could work.

**Quote from artifact:**
> - **What we found:** PostToolUse with session_id grouping is the only viable capture mechanism — Stop and TaskCompleted hooks carry no file-edit data, and neither existing file (dirty-files.json or token-ledger.db) can seed the ledger without new capture infrastructure.
> - **What it changes:** The design is confirmed: a new PostToolUse hook writes to a JSONL ledger, groups co-changes by session_id, and prunes at 500 entries. The clarify brief's assumptions are validated, not overturned.

**Impact:** This freezes the spec around a single implementation path on the basis of an unproven assumption. Downstream work will optimize around session_id grouping and JSONL persistence even if a better grouping boundary or capture path exists, creating avoidable rework when the assumption breaks.

---

### [STOP] evidence adequacy

**Finding:** The storage and pruning recommendations are justified with fabricated performance numbers and unverified event-volume estimates. The dossier presents these as findings even though it provides no benchmark, no calculation trace, and no source for the edit-event assumptions.

**Quote from artifact:**
> - Pruning: read all lines + rewrite; at 500 entries × ~200 bytes/entry = 100KB max → rewrite is fast (<1ms)
> - At estimated 10-30 Edit/Write events per session = 17-51 edit events/day
> - Verdict: JSONL is superior for this use case. Single file, O(1) append, matches established patterns. 100KB rewrite for pruning is fast.

**Impact:** The implementation can be sized and optimized against made-up constraints. If payloads are larger, event rates spike, or rewrite cost is nontrivial in the actual environment, the chosen ledger format and prune strategy will degrade or fail under real usage.

---

### [CAUTION] source authority

**Finding:** The dossier cites another dossier as evidence for a core technical claim instead of relying strictly on primary artifacts. That is circular support, not authoritative validation.

**Quote from artifact:**
> - `docs/cortex/research/structural-map-layer/dossier-concept-20260413.md` — Q2/Q4 session_id payload confirmation from prior research

**Impact:** Core conclusions inherit any error from the earlier writeup and can survive without direct verification. That weakens confidence in the claimed confirmation and makes the research chain brittle.

---

### [CAUTION] traceability

**Finding:** The dossier says all seven research questions are fully resolved and that nothing remains open, but it leaves a consequential design threshold unresolved and pushes it into the future. That means the findings do not actually close the decision loop they claim to close.

**Quote from artifact:**
> - **What's still open:** One edge case to handle in the spec
> - None — all 7 research questions resolved from codebase inspection.
> - Deferred: what injection threshold (min edit_count) should filter hotspot noise — files edited once are not hotspots; files edited 3+ times probably are. Recommend resolving in spec with AC validation.

**Impact:** The next phase will treat the dossier as decision-complete when it is not. That pushes an unresolved threshold into implementation and guarantees ambiguity in how hotspot data is surfaced or filtered.

---
