---
slug: clarify-research-loop
created: 20260412T002700Z
informed_by:
  - docs/cortex/research/clarify-research-loop/concept-20260412T002407Z.md
status: backlog
purpose: |
  Six gap closures identified by the iteration-2 codebase audit but explicitly
  deferred from this slug's scope. Each is a candidate future slug. Captured
  here so they are not lost when clarify-research-loop closes.
---

# Deferred Gaps — Epistemic Loop Follow-Ups

These six gaps were identified by the codebase audit in `concept-20260412T002407Z.md` (Findings section) but deferred from the current slug's scope to keep it shippable in one cycle. Each is a candidate future slug.

## 1. Fact-extraction pipeline (dossier → facts.jsonl)

**The gap:** `facts.jsonl` is read by `/cortex-research`, `/cortex-drive`, and `/cortex-investigate`, but no skill writes to it after research synthesis. Findings stay in dossiers; the knowledge engine never accumulates them.

**Why deferred:** The new `current-understanding.md` artifact (recommendation 2 in this slug) gives the human a queryable surface that doesn't require facts.jsonl ingestion. Fact extraction is a cross-slug knowledge accumulation feature, separate from within-slug epistemic coherence.

**Trigger to revisit:** When the user starts asking "have I learned this before in another slug?" — currently no signal that this is a felt pain.

**Suggested follow-up slug name:** `dossier-fact-extraction`

---

## 2. Separate per-slug iteration-history log

**The gap:** Iteration history (which briefs and dossiers exist for a slug, in what order, with what reframe reasons) is currently scattered across YAML frontmatter on each artifact. There is no single "audit log" view per slug.

**Why deferred:** The "iteration history" table inside `current-understanding.md` (recommendation 2) covers this need at a basic level. A separate artifact would be duplicative until the basic view proves insufficient.

**Trigger to revisit:** If users start asking "show me the full timeline of this slug" and the table inside current-understanding.md isn't enough.

**Suggested follow-up slug name:** `slug-iteration-log`

---

## 3. Uncertainty-resolution writeback to open-questions.md

**The gap:** The structured uncertainty register schema (`type | severity | resolution_path | status | resolved_by`) is documented and read by `/cortex-spec`'s critical-uncertainty gate, but no skill writes to it. Entries are hand-maintained or absent.

**Why deferred:** The current-understanding.md "open questions" section (recommendation 2) provides a working substrate. Auto-writeback to the structured register requires designing a binding from research findings to question entries, which is its own design problem.

**Trigger to revisit:** When the critical-uncertainty gate in `/cortex-spec` starts firing (or failing to fire when it should), proving the register is load-bearing in practice.

**Suggested follow-up slug name:** `uncertainty-resolution-tracker`

---

## 4. Dossier consolidation skill

**The gap:** A slug with concept + implementation + evals dossiers has its knowledge scattered across three files with no aggregation layer. The reader must reconcile them mentally.

**Why deferred:** `current-understanding.md` (recommendation 2) IS the consolidation. A separate skill would be duplicative.

**Trigger to revisit:** Only if `current-understanding.md` proves insufficient AND a slug needs phase-specific aggregation that the single doc cannot capture.

**Suggested follow-up slug name:** `cortex-research-consolidate` (likely never needed; document as "do not build")

---

## 5. Intra-dossier finding versioning (retraction support)

**The gap:** When a dossier is revised because new research invalidates a prior finding, there is no convention for marking specific findings as superseded — only file-level supersession.

**Why deferred:** ADR-style file-level supersession (recommendation 4 in this slug) is sufficient for now. Intra-file versioning is overkill until proven necessary.

**Trigger to revisit:** When a dossier survives multiple research passes and contains a mix of still-valid and invalidated findings that the reader needs to distinguish in-line.

**Suggested follow-up slug name:** `dossier-finding-versioning` (probably never needed)

---

## 6. Stage-gate Go/Kill/Hold/Recycle interactive verdict UI at research → spec boundary

**The gap:** The decision gate from research → spec is currently implicit. Recommendations 1 (Reframe Triggers) and 2 (current-understanding.md) make the gate visible but do not force an explicit Go/Kill/Hold/Recycle verdict from the human.

**Why deferred:** Adds friction to the happy-path single-pass slug case. The mechanical Reframe Trigger check in recommendation 1 already prevents the worst failure mode (silently advancing past a needed reframe). The interactive verdict is a "polish" feature, not a core mechanism.

**Trigger to revisit:** If users start advancing to spec when they should have killed/held/recycled — i.e., if the absence of the explicit verdict prompt produces wrong decisions in practice.

**Suggested follow-up slug name:** `spec-gate-verdict-prompt`

---

## Notes

- This file is itself an example of the "preserved learning" principle the parent slug is designing — a deferral is a *learning*, not a cancellation, and deserves to live on disk where future-you can find it.
- When this slug closes via `/cortex-close`, this file is archived alongside the other artifacts (under `docs/cortex/archive/clarify-research-loop/`).
- If/when any of these become active follow-up slugs, the new slug's clarify brief should `informed_by:` this file in its frontmatter.
