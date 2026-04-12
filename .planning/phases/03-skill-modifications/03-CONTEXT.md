# Phase 3: Skill Modifications - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning
**Source:** Auto-populated from Cortex artifacts via /cortex-bridge

<domain>
## Phase Boundary

Modify two existing Cortex skills to wire up the new template and the new terminal-recording behavior. Both skills exist in two locations that must remain byte-identical after the change. Also extend the decisions.md Archive Index format comment.

</domain>

<decisions>
## Implementation Decisions

**Change A: `/cortex-clarify` SKILL.md (both copies)** — add Phase 4b after the existing Phase 4 (artifact write). Logic:

```
1. Check if docs/cortex/research/{slug}/current-understanding.md exists
2. If it does NOT exist:
   a. Read templates/cortex/current-understanding.md
   b. Read brief frontmatter `initial_terminal_set:` (default: all six)
   c. Read brief frontmatter `ruled_out:` (default: empty)
   d. Populate Possible Terminals table (live for in-set, ruled-out for in ruled_out)
   e. Write the populated template to docs/cortex/research/{slug}/current-understanding.md
3. If it ALREADY exists: no-op.
   (Updates to existing docs are deferred to a follow-up slug per deferred-gaps.md.)
```

No changes to existing Phases 1-4. Pure addition.

**Change B: `/cortex-close` SKILL.md (both copies)** — add required `--terminal {name}` argument with validation, and extend the decisions.md archive line format.

Validation logic in Phase 1 (after reading state.json):
```
1c. Validate --terminal value:
    - If missing: ERROR "--terminal is required (one of: <list>)"
    - If not in {commit-to-build, kill-with-learning, decompose,
      experiment-required, already-exists, hold-on-dependency, reframe-and-continue}: ERROR
    - Read the active brief's YAML `ruled_out:` field
    - If --terminal value appears in ruled_out: ERROR
      "Terminal '{name}' was ruled out in the brief at {brief_path}"
```

Phase 5 archive line format extension:
```diff
- - {ISO8601} | {slug} | closed | contract: {path} | eval-plan: {path}
+ - {ISO8601} | {slug} | closed | terminal: {name} | contract: {path} | eval-plan: {path}
```

**Change C: `docs/cortex/handoffs/decisions.md`** — update the format comment line above the Archive Index to reflect the new field. Data lines are not touched. Legacy entries lacking `terminal:` remain valid (backward compat).

### Critical: dual SKILL.md sync

Both `~/.claude/skills/cortex-{clarify,close}/SKILL.md` and `skills/cortex-{clarify,close}/SKILL.md` must remain byte-identical after the change. Verify with `diff` after editing.

### Claude's Discretion

Exact prose phrasing of error messages, comment placement within Phase 4b, exact ordering of validation steps. Must preserve existing Phase numbering scheme — no skipped numbers, no out-of-order phases.

</decisions>

<canonical_refs>
## Canonical References

- docs/cortex/specs/clarify-research-loop/spec.md (§4 Interfaces, §7 Sequencing)
- docs/cortex/specs/clarify-research-loop/gsd-handoff.md
- docs/cortex/contracts/clarify-research-loop/contract-001.md (Done Criteria 5, 6, 7)
- ~/.claude/skills/cortex-clarify/SKILL.md (file being modified, primary)
- skills/cortex-clarify/SKILL.md (file being modified, mirror)
- ~/.claude/skills/cortex-close/SKILL.md (file being modified, primary)
- skills/cortex-close/SKILL.md (file being modified, mirror)
- docs/cortex/handoffs/decisions.md (format comment update)

</canonical_refs>

<specifics>
## Specific Ideas

Validation against the seven terminal slugs is a closed enum check. No fuzzy matching, no aliasing. Typos must error out clearly with the full list.

The brief's `ruled_out:` field is read from YAML frontmatter — the modified `/cortex-close` must handle the case where (a) the brief has no frontmatter, (b) the brief has frontmatter but no `ruled_out:` field, (c) the field is an empty list, (d) the field contains the requested terminal. Cases (a)-(c) all permit the close; case (d) errors.

The dual SKILL.md locations are a known fragile point — the executor should write each change to BOTH copies in the same edit pair, not sequentially. Consider adding a final `diff` step at the end of Phase 3 as a self-check.

</specifics>

<deferred>
## Deferred Ideas

- Promoting `--terminal` flag values to specialized commands (e.g., `/cortex-kill`, `/cortex-decompose`) — defer; pilot the polymorphic flag first
- Automated dual-SKILL.md sync via pre-commit hook — defer; add only if drift becomes a recurring pain
- Modifying `/cortex-spec` necessity gate to produce 7 verdicts directly — defer to a follow-up slug after the pilot validates the refinement

</deferred>

---

*Phase: 03-skill-modifications*
*Context gathered: 2026-04-12 via /cortex-bridge*
