# Fit Report: memory-bank-archive

<!-- ART-FIT: Fit Report Template — produced by /cortex-fit -->
<!-- SC2 forced-separation: each section must not repeat content from any other section -->

**Slug:** memory-bank-archive
**Timestamp:** 20260330T183000Z
**Evaluated against:** Cortex v1.0 — docs/cortex/handoffs/, .cortex/state.json, cortex-session-end.sh, cortex-precompact.sh, cortex-postcompact.sh
**Confidence:** high — full continuity hook reads + research dossier at docs/cortex/research/cortex-ak-integration/concept-20260330T180000Z.md
**Status:** pending-human-decision

---

## Tech Radar Ring

**Ring:** Adopt

**Justification:** Purely additive cold path with no conflicts; the only prerequisite is defining "done" as an explicit state.json mode.

---

## Gap

No `docs/cortex/archive/` path exists. No contract-close event is defined — `state.json` has no `done` mode; the mode field cycles through clarify → research → execute → repair but has no terminal state. No archive index exists. Long-running projects accumulate handoff artifacts for every slug with no rotation mechanism. When a slug's work completes, its artifacts (clarify brief, research dossiers, spec, eval results) remain in the active artifact paths indefinitely, with no signal that they are cold.

---

## Overlap

The existing continuity system handles resumption well: `cortex-session-end.sh` persists active state, `cortex-precompact.sh` / `cortex-postcompact.sh` snapshot and restore context across compaction. These serve the live-session recovery case. The archive proposal addresses the post-completion lifecycle case — the two concerns are complementary, not competitive. `docs/cortex/handoffs/decisions.md` exists as a continuity artifact; the archive index would extend it with a cold-storage section rather than replacing it.

---

## Unique Contribution

None identified. The archive pattern is standard lifecycle hygiene applied to cortex's artifact model. Its value is in filling the gap (lifecycle curation), not in introducing a new concept or pattern.

---

## Conflict

**"Done" mode is undefined (design dependency, not a conflict):** `state.json` has no `done` mode. The archive trigger needs a clear firing condition: either `mode == "done"` (requires adding the mode) or all `done_criteria` in the active contract are checked (requires reading the contract). This must be decided before implementation. It is a design dependency, not an architectural conflict.

No other conflicts identified. The proposal is additive: new directory, new index section, new optional step. Nothing existing is modified or removed.

---

## Strategic Direction

**Alignment:** aligned

Cortex's continuity model is strong on recovery but incomplete on lifecycle. Archive closes the loop: a slug goes from active (current-state.md) to cold (archive/) with a timestamped index entry. This is consistent with cortex's artifact-first philosophy — everything produces a written artifact, including the decision to close a piece of work.

---

## Pre-Populated Clarify Brief Fields

**Proposed goal:** Add `docs/cortex/archive/{slug}/` as a cold path for completed slugs, define `done` as an explicit state.json mode, and add an optional `--archive` step to `/cortex-status` (or a `/cortex-close` command) that copies finished artifacts and appends an index entry to `docs/cortex/handoffs/decisions.md`.

**Constraints:**
- Archive must copy, not move — source artifacts stay in place for reference; only the active surface (current-state.md) is cleared
- "Done" trigger must be explicitly defined before implementation: `mode == "done"` in state.json is the cleanest option
- Archive must not modify GSD `.planning/` state — archive is a cortex-layer operation only

**Open questions:**
- Should `done` be a new mode in state.json, or should archive trigger on `all done_criteria checked` in the active contract?
- Should archive be automatic on contract close, or always manual (opt-in via --archive flag)?
- What is the minimum artifact set to archive — all slug artifacts, or only clarify brief + spec + eval results?

---

## Human Decision

**Status:** pending-human-decision

To advance: change status to `approved` or `rejected` and add a one-line note.

- [ ] Approved — proceed to `/cortex-clarify memory-bank-archive`
- [ ] Rejected — archive this report, no further action

**Decision note:** _(fill in when deciding)_
