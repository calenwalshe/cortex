# Phase 2: Skill Integration and Session-Start Anchor - Context

**Gathered:** 2026-04-14
**Status:** Ready for planning (depends on Phase 1 completion)
**Source:** Auto-populated from Cortex artifacts via /cortex-bridge

<domain>
## Phase Boundary

Inject operational-context read steps into `~/.claude/skills/cortex-clarify/SKILL.md` (Phase 2d) and `~/.claude/skills/cortex-spec/SKILL.md` (Phase 1e), add the OP-LEDGER staleness anchor to `.claude/hooks/cortex-session-start.sh`, and verify soft-fail behavior by temporarily renaming the ledger and running throwaway slugs.

</domain>

<decisions>
## Implementation Decisions

### Injection pattern — per-skill inline reads

Do NOT add the operational context to `additionalContext` in the session-start hook. The 1,604-char additionalContext budget is tight. Instead, add a read step directly inside each skill so it calls `--summary` inline using the 200K context window. This is the proven pattern from structural-map-layer.

### Soft-fail guard is mandatory

Each injected skill step must be wrapped so it completes gracefully when `.cortex/edit-ledger.jsonl` is absent. The soft-fail pattern: `python3 scripts/cortex/operational-indexer.py --summary 2>/dev/null || echo '{"hotspots":[],"co_change_pairs":[],"caveat":"ledger absent"}'`. Clarify and spec must never block on a missing ledger.

### Session-start staleness anchor

Follow the existing structural-graph anchor pattern (lines 84–93 of `cortex-session-start.sh`). Add a block that reads entry count and last-entry date from the ledger and emits: `OP-LEDGER: {N} entries, {YYYY-MM-DD}`. The anchor must be ≤50 chars. Soft-fail: if ledger absent, emit `OP-LEDGER: absent` (14 chars).

### Injection location in cortex-clarify

Insert as Phase 2d — after the system-map read (Phase 2b) and before brief population (Phase 3). Present as: `### Operational Context (auto-indexed):` followed by hotspots and co-change pairs from `--summary` output.

### Injection location in cortex-spec

Insert as Phase 1e — after system-map read (Phase 1c) and before spec synthesis (Phase 2). Same `### Operational Context (auto-indexed):` heading.

### AC7/AC8 soft-fail verification

After injecting each SKILL.md step: (1) rename `.cortex/edit-ledger.jsonl` to `.cortex/edit-ledger.jsonl.bak`, (2) run a throwaway clarify or spec, (3) confirm it completes without error, (4) restore the ledger. Both skills must complete — ledger absence must not block execution.

### Claude's Discretion

- Exact markdown formatting of the injected steps within SKILL.md
- Whether to show top-N or all hotspots/pairs (recommended: top-10 by edit_count to keep context bounded)
- Line placement within the session-start hook (follow structural-graph anchor pattern)

</decisions>

<canonical_refs>
## Canonical References

- docs/cortex/specs/operational-map-layer/spec.md (Section 5 Interfaces — SKILL.md injection spec)
- docs/cortex/specs/operational-map-layer/gsd-handoff.md
- docs/cortex/contracts/operational-map-layer/contract-001.md
- docs/cortex/research/operational-map-layer/concept-20260413T193000Z.md
- docs/cortex/clarify/operational-map-layer/20260413T200000Z-clarify-brief.md

</canonical_refs>

<specifics>
## Specific Ideas

- cortex-clarify injection grep check: `grep -c "operational-indexer\|edit-ledger" ~/.claude/skills/cortex-clarify/SKILL.md` must return ≥ 1
- cortex-spec injection grep check: `grep -c "operational-indexer\|edit-ledger" ~/.claude/skills/cortex-spec/SKILL.md` must return ≥ 1
- OP-LEDGER anchor grep check: `grep -c "OP-LEDGER" .claude/hooks/cortex-session-start.sh` must return ≥ 1
- Anchor character budget: "OP-LEDGER: 500 entries, 2026-04-14" = 34 chars (well within 50)

</specifics>

<deferred>
## Deferred Ideas

- Injection into `~/.claude/skills/cortex-research/SKILL.md` (explicitly out of scope — research questions are pre-classified; operational context is less relevant to question routing than scope decisions)
- Hotspot threshold empirical calibration (deferred to post-deployment observation)

</deferred>

---

*Phase: 02-operational-map-layer*
*Context gathered: 2026-04-14 via /cortex-bridge*
