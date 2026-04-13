# Phase 2: Wire skill insertions - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning
**Source:** Auto-populated from Cortex artifacts via /cortex-bridge

<domain>
## Phase Boundary

Insert `cortex-vault-extractor.py` calls at the three intelligence gate transition points in the Cortex skill files: Phase 4c (cortex-clarify after clarify brief write), Phase 2.9 (cortex-research after dossier write), Phase 2c (cortex-spec after spec write). Phase 1 must be complete — extractor must exist and be verified before this phase begins.

</domain>

<decisions>
## Implementation Decisions

### Locked — do not revisit without evidence

- **cortex-clarify insertion point:** Phase 4c — after the clarify brief artifact is written to disk (after `Write` tool call), before Phase 5 (continuity state update). Match the pattern already established for `cortex-critique` Phase 4c invocation in the same skill.

- **cortex-research insertion point:** Phase 2.9 — after the research dossier is written to disk, matching the existing Phase 2.9 pattern in that skill. The dossier path is available in context at this point.

- **cortex-spec insertion point:** Phase 2c — after the spec artifact (`docs/cortex/specs/{slug}/spec.md`) is written, before Phase 2b (project-context.md generation). The spec path is known at this point.

- **Extractor invocation pattern (consistent across all 3 insertions):**
  ```bash
  python3 scripts/cortex/cortex-vault-extractor.py \
    --artifact {artifact_path} \
    --slug {slug}
  ```
  Soft-fail: extractor errors must not block skill execution. Wrap in try/catch or check exit code and log warning only.

- **All 3 insertions are additive** — must not modify existing gate logic, break existing skill flows, or require changes to primary artifact formats. Insert as new numbered phases between existing phases.

### Claude's Discretion

- Whether to call extractor synchronously or background it (prefer synchronous for reliability; background only if latency is observed as problematic)
- How to surface extractor errors to the user (warn in output vs. silent log)
- Whether to add an explicit "extractor skipped" note when `scripts/cortex/cortex-vault-extractor.py` doesn't exist yet (useful during bootstrap)

</decisions>

<canonical_refs>
## Canonical References

- docs/cortex/specs/cortex-vault/spec.md
- docs/cortex/specs/cortex-vault/gsd-handoff.md
- docs/cortex/contracts/cortex-vault/contract-001.md

</canonical_refs>

<specifics>
## Specific Ideas

From spec Section 3 (Scope):
- Three skill files to modify: `~/.claude/skills/cortex-clarify/SKILL.md`, `~/.claude/skills/cortex-research/SKILL.md`, `~/.claude/skills/cortex-spec/SKILL.md`
- These are in `~/.claude/skills/` (not in the cortex project repo) — edit them directly.

From spec Section 8 (Sequencing):
- Steps 5-7 in spec sequencing map directly to this phase's three tasks.
- Step 8 (run validators) should be executed at end of phase: grep for insertion patterns in all 3 skill files.

Contract validators for this phase:
- `grep -c "cortex-vault-extractor.py" ~/.claude/skills/cortex-clarify/SKILL.md` — expect ≥ 1
- `grep -c "cortex-vault-extractor.py" ~/.claude/skills/cortex-research/SKILL.md` — expect ≥ 1
- `grep -c "cortex-vault-extractor.py" ~/.claude/skills/cortex-spec/SKILL.md` — expect ≥ 1

</specifics>

<deferred>
## Deferred Ideas

- cortex-close vault integration — out of scope; separate slug
- Wiring extractor into GSD execution phases — intelligence phases only per contract

</deferred>

---

*Phase: 02-cortex-vault*
*Context gathered: 2026-04-13 via /cortex-bridge*
