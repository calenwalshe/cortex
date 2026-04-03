# Phase 17: cortex-research Power-Search Refactor - Context

**Gathered:** 2026-04-02
**Status:** Ready for planning
**Source:** Auto-populated from Cortex artifacts via /cortex-bridge

<domain>
## Phase Boundary

Replace all 8 raw API calls in cortex-research SKILL.md with power-search `search()` calls. Keep gpt-researcher for --depth deep with post-hoc cost logging. Delete "Available APIs" section and add "Search Backend" reference.

</domain>

<decisions>
## Implementation Decisions

- Quick Path: `search(q, intent=RESEARCH, provider="perplexity", max_tokens=2000)`
- Standard Step 1: `search(q, intent=SEARCH, provider="tavily", depth="advanced", max_results=7)` + `search(url, intent=READ_URL)`
- Standard Step 4: `search(findings, intent=GENERATE, provider="gemini")`
- YouTube: `search(url, intent=YOUTUBE_VIDEO, mode="summary")`
- URL/Crawl: `search(url, intent=READ_URL)` / `search(url, intent=CRAWL_SITE)`
- Deep Path: Keep gpt-researcher as-is + `usage.record(provider="gpt_researcher", ...)` post-hoc
- Gemini cross-reference uses GENERATE (not GROUNDED_SEARCH) — we want analysis of gathered findings, not new web search

### Claude's Discretion

- Exact wording of the "Search Backend" reference section
- Whether to add inline comments explaining intent choices
- How to handle the orchestration loop variable names

</decisions>

<canonical_refs>
## Canonical References

- docs/cortex/specs/token-efficiency/spec.md
- docs/cortex/specs/token-efficiency/gsd-handoff.md
- docs/cortex/contracts/token-efficiency/contract-001.md
- docs/cortex/research/token-efficiency/implementation-20260402T225932Z.md (Section A: cortex-research refactor)
- docs/cortex/research/token-efficiency/concept-20260402T222718Z.md (Section A: migration mapping)

</canonical_refs>

<specifics>
## Specific Ideas

- The Standard Path orchestration loop chains multiple `search()` calls: tavily search → jina extract top 3 → analyze gaps → follow-up searches (max 2) → gemini cross-reference
- `include_raw_content=True` is already hardcoded in TavilyProvider — no need to pass it
- No need to force `provider="jina"` for READ_URL — Jina is first in the chain and always available
- power-search auto-tracks cost via SQLite on every `search()` call — no manual tracking needed

</specifics>

<deferred>
## Deferred Ideas

- Replacing gpt-researcher with Perplexity (rejected — capability downgrade)
- Using GROUNDED_SEARCH for cross-reference step (not needed — analyzing internal findings)
- Adding a "multi-step research" intent to power-search (future consideration)

</deferred>

---

*Phase: 17-cortex-research-refactor*
*Context gathered: 2026-04-02 via /cortex-bridge*
