# Phase 18: Token Ledger Schema - Context

**Gathered:** 2026-04-02
**Status:** Ready for planning
**Source:** Auto-populated from Cortex artifacts via /cortex-bridge

<domain>
## Phase Boundary

Create ~/.cortex/token-ledger.db with 4 tables (claude_turns, codex_tasks, sessions, daily_rollup) and correct indexes. Write a schema migration script.

</domain>

<decisions>
## Implementation Decisions

- Global DB at ~/.cortex/ (not project-scoped) — single query for cross-project totals, no .gitignore pollution
- Separate from power-search usage.db — use ATTACH DATABASE at query time for cross-source joins
- claude_turns: per-turn with session_id, message_id, model, input/output/cache tokens, cost_usd, phase, skill, remaining_pct
- codex_tasks: per-task with task_id, model, input/output/cached/reasoning tokens, cost_usd, phase, task_type, exit_code, elapsed_ms
- sessions: session_id PK with running totals (total_input, total_output, total_cost), compacted flag
- daily_rollup: materialized aggregates by (date, provider, model, project_slug, phase)
- cost_usd computed at insert time using known pricing — avoids needing a pricing table at query time

### Claude's Discretion

- Migration script language (bash + sqlite3 CLI vs Node.js)
- Whether to add SQLite WAL mode pragma at creation time
- Index naming conventions

</decisions>

<canonical_refs>
## Canonical References

- docs/cortex/specs/token-efficiency/spec.md
- docs/cortex/contracts/token-efficiency/contract-001.md
- docs/cortex/research/token-efficiency/implementation-20260402T225932Z.md (Section B: Token Ledger Design)

</canonical_refs>

<specifics>
## Specific Ideas

- Full schema SQL is documented in the implementation research dossier
- Indexes on: session_id, ts, phase, skill, project_slug (claude_turns); session_id, ts, phase (codex_tasks)
- daily_rollup PRIMARY KEY is (date, provider, model, project_slug, phase) — compound key for upsert

</specifics>

<deferred>
## Deferred Ideas

- Extending power-search usage.db directly (rejected — different granularity)
- SQLite triggers for automatic daily_rollup maintenance (decide during implementation)

</deferred>

---

*Phase: 18-token-ledger-schema*
*Context gathered: 2026-04-02 via /cortex-bridge*
