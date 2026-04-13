# Phase 1: Build extractor and hook injection - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning
**Source:** Auto-populated from Cortex artifacts via /cortex-bridge

<domain>
## Phase Boundary

Write `scripts/cortex/cortex-vault-extractor.py` with full extraction logic and modify `cortex-session-start.sh` to inject vault facts into `additionalContext`. This phase delivers both the write path (extractor) and the read path (hook injection) as an atomic unit — neither is useful without the other.

</domain>

<decisions>
## Implementation Decisions

### Locked — do not revisit without evidence

- **Vault write path:** Direct `add_fact()` via `sys.path.insert(0, os.path.expanduser("~/memory/vault/scripts/"))` + `from fact_store import add_fact`. Do NOT call as subprocess — `fact_store.py` has no CLI interface; its `__main__` block is a test harness. Verified: no relative imports in fact_store.py, safe to import from any working directory.

- **Vault read path:** `python3 ~/memory/vault/recall_query.py "QUERY" --top-k 5 --project cortex-memory-platform` returns synthesized prose. No `--deep` flag (shallow mode targets <3s for session start latency). No `--type episodic` — Cortex-written facts use `memory_type=semantic`, not episodic.

- **Idempotency key:** `(session_id, topic, content[:50])` — check SQLite before every `add_fact()` call. First extraction wins; re-runs are no-ops.

- **Budget guard:** `max(0, 9500 - len(existing_content))` — truncate vault facts to available space. Hard cap: 10,000 chars total `additionalContext`.

- **Hook injection point:** After the outer `if [[ -f "$FACTS_FILE" ... ]]` block closes (after existing `.cortex/facts.jsonl` retrieval), before the `HEALTH=""` line. Do NOT insert inside the fi block.

- **9 extraction categories with field values:**
  - scope-exclusion → `confidence=0.95, importance=0.6, memory_type="semantic"`
  - owner-constraint → `confidence=0.95, importance=0.8, memory_type="semantic"`
  - design-assumption → `confidence=0.75, importance=0.7, memory_type="semantic"`
  - research-finding → `confidence=0.80, importance=0.7, memory_type="semantic"`
  - architecture-decision → `confidence=0.90, importance=0.8, memory_type="semantic"`
  - adjacent-finding → `confidence=0.75, importance=0.65, memory_type="semantic"`
  - failed-approach → `confidence=0.85, importance=0.75, memory_type="procedural"`
  - risk-mitigation → `confidence=0.80, importance=0.70, memory_type="semantic"`
  - Common fields: `project_scope="cortex-memory-platform"`, `session_id="cortex-{slug}"`, `scope="learning"`

- **Path-pattern truth table for artifact type detection:**
  - path contains `clarify/` → `brief`
  - path contains `research/` AND filename ≠ `current-understanding.md` → `dossier`
  - path contains `specs/` AND filename is `spec.md` → `spec`
  - any other path → raise error "unsupported artifact type"

- **`additionalContext` VAULT MEMORY section format:** Append after existing CORTEX STATE / RELEVANT FACTS block:
  ```
  VAULT MEMORY (cross-session):
  {synthesized prose from recall_query.py}
  ```

### Claude's Discretion

- How to extract per-category content from markdown sections (regex vs. AST vs. line-by-line)
- Whether to batch `add_fact()` calls or commit individually (atomicity vs. partial-write recovery)
- Exact query string passed to `recall_query.py` for session-start (use slug or "cortex intelligence" or similar)
- Whether to fallback to unscoped query if `--project cortex` filter returns empty

</decisions>

<canonical_refs>
## Canonical References

- docs/cortex/specs/cortex-vault/spec.md
- docs/cortex/specs/cortex-vault/gsd-handoff.md
- docs/cortex/contracts/cortex-vault/contract-001.md
- docs/cortex/research/cortex-vault/concept-20260413T140000Z.md
- docs/cortex/clarify/cortex-vault/20260413T020000Z-clarify-brief.md

</canonical_refs>

<specifics>
## Specific Ideas

From spec Section 7 (Risks):
- Test `recall_query.py --project cortex` filter semantics during implementation — if filter doesn't match `project_scope = "cortex"` exactly, fall back to unscoped query + post-filter in the hook.
- Run soft-fail tests by temporarily renaming vault to verify hook and extractor complete without crashing.

From spec Section 8 (Sequencing):
- Write and test extractor first (Tasks 1-2), then hook modification (Tasks 3-4) — extractor is needed to verify end-to-end vault write before hook reads back.
- Use the cortex-vault clarify brief itself as the live test artifact for extractor verification.

From research dossier Q2:
- `add_fact()` signature: `add_fact(content, session_id, valid_from, topic, memory_type, project_scope, confidence, importance, scope, entities, ingestion_time)` — `entities` and `ingestion_time` may default; confirm by reading fact_store.py.

</specifics>

<deferred>
## Deferred Ideas

- cortex-close vault integration — out of scope; add as separate slug when close flow is revisited
- inbox/promotion pipeline for Cortex artifacts — overturned by research evidence; document in decisions.md
- Vault reads/writes in GSD execution phases (execute, validate, repair) — intelligence phases only
- Top-k=10 default — use top-k=5; expose as `VAULT_TOP_K` env var for future tuning
- Improving autoresearch classification loop (F1=0.25 → 0.7) — separate slug

</deferred>

---

*Phase: 01-cortex-vault*
*Context gathered: 2026-04-13 via /cortex-bridge*
