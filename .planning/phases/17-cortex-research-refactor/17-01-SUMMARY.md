---
phase: 17-cortex-research-refactor
plan: 01
subsystem: cortex-research
tags: [power-search, api-refactor, cost-tracking]
dependency_graph:
  requires: []
  provides: [unified-search-interface, cost-tracking-integration]
  affects: [skills/cortex-research/SKILL.md]
tech_stack:
  added: [power-search]
  patterns: [search()-based-api-routing, post-hoc-usage-tracking]
key_files:
  created: []
  modified:
    - skills/cortex-research/SKILL.md
decisions:
  - "GENERATE intent used for Gemini cross-reference (not GROUNDED_SEARCH) -- analyzing gathered findings, not new web search"
  - "gpt-researcher preserved for --depth deep with post-hoc usage.record() since it manages its own API calls"
  - "Available APIs section replaced with Search Backend reference to power-search library"
metrics:
  duration: 2min
  completed: "2026-04-03T02:44:00Z"
  tasks: 2
  files: 1
---

# Phase 17 Plan 01: cortex-research Power-Search Refactor Summary

Replaced all 8 raw API call sites in cortex-research SKILL.md with power-search search() calls, routing through unified provider interface with automatic cost tracking in usage.db.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Replace all raw API calls with power-search search() calls | d5305bb | skills/cortex-research/SKILL.md |
| 2 | Update documentation sections and verify complete file | dd7e092 | skills/cortex-research/SKILL.md |

## Changes Made

### Task 1: API Call Replacements
- **Quick Path**: Perplexity curl replaced with `search(query, intent=Intent.RESEARCH, provider="perplexity")`
- **Standard Path Step 1**: TavilyClient + Jina curl replaced with `search(intent=Intent.SEARCH)` + `search(intent=Intent.READ_URL)`
- **Standard Path Step 3**: Gap-fill Tavily+Jina replaced with search() calls in loop
- **Standard Path Step 4**: Gemini curl replaced with `search(intent=Intent.GENERATE, provider="gemini")`
- **Deep Path**: gpt-researcher preserved; added post-hoc `usage.record(provider="gpt_researcher")` for cost tracking
- **YouTube Path**: genai.configure replaced with `search(intent=Intent.YOUTUBE_VIDEO)`
- **URL Path**: Jina curl replaced with `search(intent=Intent.READ_URL)`
- **Site Crawl**: Crawl4AI AsyncWebCrawler replaced with `search(intent=Intent.CRAWL_SITE)`

### Task 2: Documentation Updates
- Deleted "Available APIs" section (7-row table with raw env vars)
- Added "Search Backend" section referencing power-search library
- Documented gpt-researcher exception for --depth deep
- Updated skill description to reflect unified search() interface
- Verified no stale env var references remain (TAVILY_API_KEY, PPLX_API_KEY, FIRECRAWL_API_KEY, GEMINI_API_KEY all removed)

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None - all API calls are wired to real power-search function signatures.

## Verification Results

| Check | Result |
|-------|--------|
| `from power_search import search` present | 5 matches |
| `curl -s` removed | 0 matches |
| `TavilyClient` removed | 0 matches |
| `genai.configure` removed | 0 matches |
| `r.jina.ai` removed | 0 matches |
| `AsyncWebCrawler` removed | 0 matches |
| `## Available APIs` removed | 0 matches |
| `## Search Backend` added | 1 match |
| `GPTResearcher` preserved | 2 matches |
| `usage.record` present | 1 match (code) + 1 match (docs) |
| All 6 Intent enum values used | Confirmed |
