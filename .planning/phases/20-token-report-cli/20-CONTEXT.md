# Phase 20: Token Report CLI - Context

**Gathered:** 2026-04-02
**Status:** Ready for planning
**Source:** Auto-populated from Cortex artifacts via /cortex-bridge

<domain>
## Phase Boundary

Create scripts/cortex/token-report.sh with key SQL queries against the token ledger and power-search DB. Formatted output for offline analysis.

</domain>

<decisions>
## Implementation Decisions

- Shell script wrapping sqlite3 CLI commands (no runtime dependencies beyond sqlite3)
- ATTACH ~/.power-search/usage.db for cross-source queries
- Key queries: daily cost, phase cost, skill cost, cache hit ratio, session ranking
- Formatted output (not raw SQL) for human readability

### Claude's Discretion

- Output formatting (plain text tables vs markdown vs colored terminal output)
- Whether to support flags (--today, --phase X, --session Y) or show all reports
- Whether to include sparkline-style trend indicators

</decisions>

<canonical_refs>
## Canonical References

- docs/cortex/specs/token-efficiency/spec.md
- docs/cortex/contracts/token-efficiency/contract-001.md
- docs/cortex/research/token-efficiency/implementation-20260402T225932Z.md (Section B: Query Interface)

</canonical_refs>

<specifics>
## Specific Ideas

- 7 query examples are fully written in the implementation research dossier (Q1-Q7)
- Cache hit ratio query: SUM(cache_read_tokens) / SUM(all input tokens) * 100
- Context burndown: remaining_pct over time per session (for optimization insights)

</specifics>

<deferred>
## Deferred Ideas

- Interactive TUI dashboard
- Automated report generation on session end
- Cost alerting/notifications

</deferred>

---

*Phase: 20-token-report-cli*
*Context gathered: 2026-04-02 via /cortex-bridge*
