# Phase 2: Wire critique into existing skills - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning
**Source:** Auto-populated from Cortex artifacts via /cortex-bridge

<domain>
## Phase Boundary

Edit three existing skill files to invoke cortex-critique at the correct gate transition point. All three edits are additive — they insert a new phase step without replacing existing logic.

- `skills/cortex-clarify/SKILL.md` — add Phase 4c after Phase 4 (write artifact), before Phase 5 (update continuity state)
- `skills/cortex-research/SKILL.md` — add Phase 2.9 after dossier write, before setting `research_complete: true`
- `skills/cortex-spec/SKILL.md` — add Phase 1c after spec is written, before the contract approval gate

This phase is complete when the 5 Phase 2 success criteria pass and all external validators (`grep -q "cortex-critique"`) return exit 0.

</domain>

<decisions>
## Implementation Decisions

### Insertion points (locked per spec §8 Sequencing)
- **cortex-clarify**: Phase 4c — after writing clarify brief to disk, before updating continuity state. The brief is on disk at this point and can be passed to cortex-critique as the artifact path.
- **cortex-research**: Phase 2.9 — after each dossier is written, before the skill sets `research_complete: true`. Each dossier invocation gets its own timestamped critique artifact.
- **cortex-spec**: Phase 1c — after spec.md is written, before the contract approval gate (`contract_approval`). The spec is on disk and the owner has not yet been asked to approve.

### Invocation pattern (consistent across all three skills)
```
/cortex-critique --artifact <path-to-artifact> --gate <gate-name> --slug <slug>
```
Or equivalent inline instruction to invoke the cortex-critique skill with those three arguments.

### Failure handling (non-zero exit = proceed with warning, not block)
If cortex-critique returns non-zero exit or fails to produce the critique artifact:
- Record `CRITIQUE_FAILED` in `.cortex/state.json` gate receipt
- Proceed with the gate — critique failure must not block the pipeline
- Log: "cortex-critique failed for gate <gate> — proceeding without critique receipt"

### full-auto vs supervised behavior (per spec §2 AC)
In full-auto mode: critique runs, artifact is persisted, `human_critique` gate is skipped, gate advances automatically.
In supervised mode: after critique artifact is written, show the AI findings in plain language (not raw JSON), then present AskUserQuestion before the gate advances.

### Claude's Discretion
- Exact phrasing of the Phase 4c/2.9/1c section headings in each skill
- Whether to show full findings list or just severity + finding count in supervised mode
- Exact AskUserQuestion options for the human_critique gate (e.g., "Proceed", "Flag concern", "Block")

</decisions>

<canonical_refs>
## Canonical References

- docs/cortex/specs/gate-critique/spec.md (§8 Sequencing — steps 3, 4, 5)
- docs/cortex/specs/gate-critique/gsd-handoff.md
- docs/cortex/contracts/gate-critique/contract-001.md
- docs/cortex/clarify/gate-critique/20260412T082000Z-clarify-brief.md
- skills/cortex-clarify/SKILL.md (existing — edit target)
- skills/cortex-research/SKILL.md (existing — edit target)
- skills/cortex-spec/SKILL.md (existing — edit target)

</canonical_refs>

<specifics>
## Specific Ideas

From spec §5 (Interfaces):
- `skills/cortex-clarify/SKILL.md` — existing file (edit); Phase 4c addition
- `skills/cortex-research/SKILL.md` — existing file (edit); Phase 2.9 addition
- `skills/cortex-spec/SKILL.md` — existing file (edit); Phase 1c addition

From spec §7 (Risks):
- **Skill edits break existing gate flow**: cortex-critique invocation is additive only — does not replace any existing gate logic; if cortex-critique fails (non-zero exit), gate proceeds with CRITIQUE_FAILED warning

From clarify brief constraints:
- Human critique must be lightweight — owner sees AI findings in plain language first, not raw JSON
- AI critique always runs — it is not gated by autonomy preset; only human_critique is autonomy-conditional

</specifics>

<deferred>
## Deferred Ideas

- cortex-drive gate critique wiring (out of scope — follow-on slug after Phase 1 validates)
- Retroactive critique of prior closed slugs (out of scope)

</deferred>

---

*Phase: 02-gate-critique*
*Context gathered: 2026-04-12 via /cortex-bridge*
