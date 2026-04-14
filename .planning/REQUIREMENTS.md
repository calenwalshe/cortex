# Requirements: operational-map-layer

**Defined:** 2026-04-14
**Core Value:** Intelligence phases know which files are volatile and which are coupled before making scope decisions — so write roots, risk sections, and clarify briefs reflect actual development patterns, not just structural intent.

## Operational Map Requirements

- [ ] **REQ-OML-1**: Edit/Write calls append one JSONL entry to `.cortex/edit-ledger.jsonl` with `{timestamp, session_id, file_path, tool_name, slug}`
- [ ] **REQ-OML-2**: Non-edit tools (Bash, Read, Glob, Grep) do not produce ledger entries
- [ ] **REQ-OML-3**: Hook always exits 0 for any valid PostToolUse payload
- [ ] **REQ-OML-4**: Ledger is pruned to 500 entries when overflow occurs
- [ ] **REQ-OML-5**: `--summary` mode outputs valid JSON with `hotspots` and `co_change_pairs` fields
- [ ] **REQ-OML-6**: `--summary` applies `--min-count` noise filter (default 2)
- [ ] **REQ-OML-7**: cortex-clarify and cortex-spec skills have soft-fail operational-context read steps
- [ ] **REQ-OML-8**: cortex-session-start.sh emits OP-LEDGER staleness anchor (≤50 chars)

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| **REQ-OML-1** | Phase 1: Core Script and Hook Registration | Pending |
| **REQ-OML-2** | Phase 1: Core Script and Hook Registration | Pending |
| **REQ-OML-3** | Phase 1: Core Script and Hook Registration | Pending |
| **REQ-OML-4** | Phase 1: Core Script and Hook Registration | Pending |
| **REQ-OML-5** | Phase 1: Core Script and Hook Registration | Pending |
| **REQ-OML-6** | Phase 1: Core Script and Hook Registration | Pending |
| **REQ-OML-7** | Phase 2: Skill Integration and Session-Start Anchor | Pending |
| **REQ-OML-8** | Phase 2: Skill Integration and Session-Start Anchor | Pending |

**Coverage:**
- Operational Map requirements: 8 total -- all mapped
- Unmapped: 0
