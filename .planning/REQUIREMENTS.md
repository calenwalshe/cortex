# Requirements: token-efficiency

**Defined:** 2026-04-02
**Core Value:** Every API call and LLM turn is tracked in queryable storage, enabling data-driven infrastructure planning and automatic Codex offloading for suitable tasks.

## Token Efficiency Requirements

- [x] **TE-01**: cortex-research routes all search/extract/synthesis calls through power-search `search()` API
- [x] **TE-02**: cortex-research `--depth deep` backward compatibility preserved via gpt-researcher
- [ ] **TE-03**: Token ledger SQLite database with 4 tables (claude_turns, codex_tasks, sessions, daily_rollup) and indexes
- [ ] **TE-04**: PostToolUse hook extracts per-turn token usage from session JSONL transcripts and writes to ledger
- [ ] **TE-05**: Token tracking hook adds <5ms latency per invocation
- [ ] **TE-06**: CLI query script produces formatted reports (daily cost, phase cost, session ranking, cache hit ratio) with cross-DB power-search joins
- [ ] **TE-07**: Task router classifies GSD plan tasks as codex-safe or claude-required using 9-rule static decision tree
- [ ] **TE-08**: Context capsule template and result JSON Schema enable structured Codex execution handoff
- [ ] **TE-09**: Codex execution wrapper handles full lifecycle (worktree, invoke, parse, validate, merge/cleanup, ledger write)
- [ ] **TE-10**: Codex failure (timeout, test failure, checkpoint) triggers automatic fallback to Claude executor
- [ ] **TE-11**: `codex.enabled: false` in config.json bypasses Codex routing entirely

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| **TE-01** | Phase 17: cortex-research Refactor | Pending |
| **TE-02** | Phase 17: cortex-research Refactor | Pending |
| **TE-03** | Phase 18: Token Ledger Schema | Pending |
| **TE-04** | Phase 19: PostToolUse Hook | Pending |
| **TE-05** | Phase 19: PostToolUse Hook | Pending |
| **TE-06** | Phase 20: Token Report CLI | Pending |
| **TE-07** | Phase 21: Codex Task Router | Pending |
| **TE-08** | Phase 22: Context Capsule + Schema | Pending |
| **TE-09** | Phase 23: Codex Execution Wrapper | Pending |
| **TE-10** | Phase 23: Codex Execution Wrapper | Pending |
| **TE-11** | Phase 24: GSD Execute-Plan Integration | Pending |

**Coverage:**
- Token Efficiency requirements: 11 total — all mapped
- Unmapped: 0
