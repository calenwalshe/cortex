# Roadmap: token-efficiency

## Overview

Build token observability and efficiency into Cortex and GSD by: (1) refactoring cortex-research to use power-search for unified API routing and cost tracking, (2) creating a token ledger that records Claude and Codex token consumption per turn/task, and (3) enabling Codex CLI as an autonomous execution layer for suitable GSD tasks — with automatic fallback to Claude for tasks requiring interactive context. Success = every API call and Claude/Codex turn is tracked in queryable storage, and 60-70% of GSD auto tasks can run via Codex with zero human intervention.

## Milestones

- ✅ **v1.4 adaptive-autonomy** — Phases 1-16 (shipped 2026-04-02)
- 🚧 **v1.5 token-efficiency** — Phases 17-24 (in progress)

## Phases

<details>
<summary>✅ v1.4 adaptive-autonomy (Phases 1-16) — SHIPPED 2026-04-02</summary>

See `.planning/milestones/v1.4-ROADMAP.md` for full details.

</details>

### 🚧 v1.5 token-efficiency (In Progress)

### Phase 17: cortex-research Power-Search Refactor

**Goal**: All cortex-research API calls route through power-search, gaining unified provider routing, fallback chains, and automatic cost tracking in usage.db
**Depends on**: Nothing (first phase of v1.5)
**Requirements**: TE-01, TE-02
**Success Criteria** (what must be TRUE):
  1. `cortex-research --phase concept` produces a dossier AND `~/.power-search/usage.db` shows new query entries with cost > 0
  2. `cortex-research --depth deep` still works via gpt-researcher (backward compat)
**Research**: Unlikely
**Plans**: 1 plan

Plans:
- [x] 17-01-PLAN.md — Replace raw API calls with power-search search() and update documentation sections

### Phase 18: Token Ledger Schema

**Goal**: SQLite database at ~/.cortex/token-ledger.db exists with all 4 tables (claude_turns, codex_tasks, sessions, daily_rollup) and correct indexes, ready for data ingestion
**Depends on**: Nothing (independent of Phase 17)
**Requirements**: TE-03
**Success Criteria** (what must be TRUE):
  1. `~/.cortex/token-ledger.db` exists with 4 tables (claude_turns, codex_tasks, sessions, daily_rollup)
**Research**: Unlikely
**Plans**: 0 plans

### Phase 19: PostToolUse Token Tracking Hook

**Goal**: Every Claude tool call automatically records token usage to the ledger — tail-reading session JSONL transcripts with <5ms overhead
**Depends on**: Phase 18
**Requirements**: TE-04, TE-05
**Success Criteria** (what must be TRUE):
  1. After 10+ tool calls, `claude_turns` has entries with non-zero token counts
  2. Token ledger hook adds <5ms latency per PostToolUse invocation
**Research**: Unlikely
**Plans**: 0 plans

### Phase 20: Token Report CLI

**Goal**: A single CLI script queries the token ledger and power-search DB to produce formatted reports on daily cost, phase cost, session ranking, and cache hit ratio
**Depends on**: Phase 19
**Requirements**: TE-06
**Success Criteria** (what must be TRUE):
  1. `token-report.sh` produces formatted output for daily cost, phase cost, session ranking, cache hit ratio
  2. Cross-DB query (`ATTACH power-search usage.db`) works from token-ledger.db
**Research**: Unlikely
**Plans**: 0 plans

### Phase 21: Codex Task Router

**Goal**: A 9-rule static classifier reads GSD PLAN.md task XML and outputs per-task classification (codex-safe vs claude-required) with deterministic, debuggable results
**Depends on**: Nothing (independent)
**Requirements**: TE-07
**Success Criteria** (what must be TRUE):
  1. Task router correctly classifies auto+verify as codex-safe, checkpoint as claude-required, >8 files as claude-required
**Research**: Unlikely
**Plans**: 0 plans

### Phase 22: Context Capsule and Result Schema

**Goal**: The context capsule template and JSON result schema exist and can be used to generate valid Codex execution inputs and parse structured Codex outputs
**Depends on**: Phase 21
**Requirements**: TE-08
**Success Criteria** (what must be TRUE):
  1. Context capsule template generates valid capsules under 16KB from sample plans
  2. Result schema validates against sample Codex --output-schema output
**Research**: Unlikely
**Plans**: 0 plans

### Phase 23: Codex Execution Wrapper

**Goal**: The execution wrapper handles the full lifecycle: worktree creation, capsule generation, Codex invocation with timeout, JSONL parsing for token usage, result validation, worktree merge on success / cleanup on failure, and ledger write
**Depends on**: Phase 18, Phase 22
**Requirements**: TE-09, TE-10
**Success Criteria** (what must be TRUE):
  1. Codex-safe task via wrapper: committed code merged, `codex_tasks` entry in ledger with token counts
  2. Codex failure triggers automatic fallback to Claude executor
**Research**: Unlikely
**Plans**: 0 plans

### Phase 24: GSD Execute-Plan Integration

**Goal**: GSD execute-plan.md routes codex-safe tasks to Codex and claude-required tasks to Claude executor, with a config toggle to disable Codex entirely
**Depends on**: Phase 23
**Requirements**: TE-11
**Success Criteria** (what must be TRUE):
  1. `codex.enabled: false` bypasses Codex entirely
  2. Mixed plans execute codex-safe tasks via Codex and remainder via Claude
**Research**: Unlikely
**Plans**: 0 plans

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|---------------|--------|-----------|
| 17. cortex-research Refactor | 1/1 | Complete    | 2026-04-03 |
| 18. Token Ledger Schema | 0/0 | Not started | - |
| 19. PostToolUse Hook | 0/0 | Not started | - |
| 20. Token Report CLI | 0/0 | Not started | - |
| 21. Codex Task Router | 0/0 | Not started | - |
| 22. Context Capsule + Schema | 0/0 | Not started | - |
| 23. Codex Execution Wrapper | 0/0 | Not started | - |
| 24. GSD Execute-Plan Integration | 0/0 | Not started | - |
