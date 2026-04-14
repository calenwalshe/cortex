# operational-map-layer — Operational Map Layer

## What This Is

Cortex intelligence phases (clarify, research, spec) make scope decisions blind to operational reality. The structural map layer surfaces symbol graphs; the distilled layer surfaces architectural intent — but neither answers: which files are edited frequently, and which files change together? Without edit-frequency and co-change data, clarify briefs under-weight volatile files, specs pick write roots without knowing which paths are coupled, and risk sections miss the highest-churn areas. This work adds a PostToolUse hook that records Edit/Write events to a rolling JSONL ledger, a summary CLI that aggregates hotspot and co-change data, and injection steps in the clarify and spec skills.

## Core Value

Intelligence phases know which files are volatile and which are coupled before making scope decisions — so write roots, risk sections, and clarify briefs reflect actual development patterns, not just structural intent.

## Requirements

### Active

- [ ] **REQ-OML-1**: Edit/Write calls append one JSONL entry to `.cortex/edit-ledger.jsonl` with `{timestamp, session_id, file_path, tool_name, slug}`
- [ ] **REQ-OML-2**: Non-edit tools (Bash, Read, Glob, Grep) do not produce ledger entries
- [ ] **REQ-OML-3**: Hook always exits 0 for any valid PostToolUse payload
- [ ] **REQ-OML-4**: Ledger is pruned to 500 entries when overflow occurs
- [ ] **REQ-OML-5**: `--summary` mode outputs valid JSON with `hotspots` and `co_change_pairs` fields
- [ ] **REQ-OML-6**: `--summary` applies `--min-count` noise filter (default 2)
- [ ] **REQ-OML-7**: cortex-clarify and cortex-spec skills have soft-fail operational-context read steps
- [ ] **REQ-OML-8**: cortex-session-start.sh emits OP-LEDGER staleness anchor (≤50 chars)

### Out of Scope

- Modifications to `~/.claude/skills/cortex-research/SKILL.md`
- Modifications to `dirty-files.json`, `token-ledger.db`, or `token-ledger.js`
- Stop, TaskCompleted, PreToolUse hooks
- Git log-based co-change analysis
- Cross-session analysis beyond the 500-entry rolling window
- Multi-project ledger tracking

## Context

**Slug:** operational-map-layer
**Contract:** docs/cortex/contracts/operational-map-layer/contract-001.md
**Spec:** docs/cortex/specs/operational-map-layer/spec.md
**Handoff:** docs/cortex/specs/operational-map-layer/gsd-handoff.md

## Constraints

- Python stdlib only (`json`, `os`, `datetime`, `collections`, `argparse`) — no pip dependencies
- Hook must exit 0 always — never block tool execution
- PostToolUse hook registration is additive — does not replace existing entries in `.claude/settings.json`
- SKILL.md injection is additive-only — no existing steps removed
- `.cortex/edit-ledger.jsonl` is written by `--hook` mode; created on first fire (does not pre-exist)
- Ledger hard cap: 500 entries (enforced at append time, not via cron)
- Session_id from PostToolUse payload is the co-change grouping key

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| PostToolUse hook (not Stop/TaskCompleted) | Only hook with both `session_id` and `tool_input.file_path` in payload — confirmed from `token-ledger.js:39` | PostToolUse async hook selected |
| JSONL append (not per-session JSON files) | Matches `facts.jsonl` pattern; 230 bytes/entry; simpler read path; no directory proliferation | `.cortex/edit-ledger.jsonl` rolling ledger |
| Per-skill inline reads (not additionalContext) | Bypasses 1,604-char additionalContext budget constraint; 200K context window used instead | `--summary` called inline in clarify/spec skills |
| `session_id` as co-change key | `/clear` fragments session_id — documented limitation; caveat field in `--summary` JSON output | session_id grouping with explicit caveat |
