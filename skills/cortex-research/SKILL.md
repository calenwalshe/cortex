# Cortex Research — Deep Multi-Source, Multi-LLM Research

Systematic research pipeline using Tavily (search), Jina Reader (extraction), Firecrawl (crawling), Crawl4AI (site crawling), Perplexity (deep research), Gemini (cross-reference), and OpenAI (gpt-researcher backend). Produces structured dossiers written to the target project repo under `docs/cortex/`.

## User-invocable
When the user types `/cortex-research`, run this skill.
Also trigger when: "research this", "deep dive on", "investigate topic", "what do we know about", "intelligence brief on".

## Arguments
- `/cortex-research [<topic>] [--phase concept|implementation|evals] [--depth quick|standard|deep] [--team]`

| Argument / Flag | Required | Description | Default |
|-----------------|----------|-------------|---------|
| `<topic>` | Optional | Focus topic for this research pass | Current slug's clarify brief |
| `--phase` | Optional | Research phase: `concept`, `implementation`, or `evals` | `concept` |
| `--depth` | Optional | Research depth: `quick`, `standard`, or `deep` | `standard` |
| `--team` | Optional flag | Invokes agent team for research (opt-in, adds cost) | Off |

## Instructions

### Phase 0: Resolve slug and input context

1. Read `.cortex/state.json` to get the active slug.
2. Read `docs/cortex/clarify/{slug}/` to find the clarify brief.
   - **If no clarify brief exists for the active slug:** block with:
     > No clarify brief found for active slug. Run `/cortex-clarify` first.
3. If `<topic>` argument is provided, use it as the research focus for this pass.
   If no `<topic>` is provided, use the clarify brief's Open Questions and Next Research Steps as the research agenda.

### Phase 1: Determine Research Depth

| Depth | When | Tools | Time |
|-------|------|-------|------|
| Quick | Simple factual question | Perplexity sonar | ~30s |
| Standard | Most research tasks | Tavily + Jina + Gemini synthesis | ~2-5 min |
| Deep | Complex investigation | gpt-researcher + all sources | ~5-15 min |
| YouTube | Video content needed | Gemini multimodal | ~1 min |

### Phase 2: Execute Research

#### Quick Path (`--depth quick` or simple question)
```bash
curl -s https://api.perplexity.ai/chat/completions \
  -H "Authorization: Bearer $PPLX_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"sonar-pro\",\"messages\":[{\"role\":\"user\",\"content\":\"$QUERY\"}],\"max_tokens\":2000}"
```

#### Standard Path (default)

**Step 1: Multi-source search (parallel)**
```python
# Tavily advanced search
from tavily import TavilyClient
client = TavilyClient()
results = client.search(query, search_depth="advanced", max_results=7, include_raw_content=True)
```

```bash
# Jina Reader on top results
curl -s "https://r.jina.ai/<url>" -H "Accept: text/markdown"
```

**Step 2: Analyze and identify gaps**
Read all sources. What's consistent? What conflicts? What's missing?
Generate follow-up queries for gaps.

**Step 3: Fill gaps (iterate)**
Run 1-2 more Tavily searches on follow-up queries. Extract with Jina.

**Step 4: Cross-reference with Gemini**
Send consolidated findings to Gemini for a second-opinion analysis:
```bash
curl -s "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"contents\":[{\"parts\":[{\"text\":\"Cross-reference and fact-check these research findings: $FINDINGS\"}]}]}"
```

**Step 5: Synthesize into dossier**

#### Deep Path (`--depth deep`)
```python
from gpt_researcher import GPTResearcher
import asyncio

async def research():
    researcher = GPTResearcher(query, "research_report")
    report = await researcher.conduct_research()
    return report

report = asyncio.run(research())
```
Uses OpenAI API + Tavily automatically.

#### YouTube Path (YouTube URL detected)
```python
import google.generativeai as genai
import os

genai.configure(api_key=os.environ['GEMINI_API_KEY'])
model = genai.GenerativeModel('gemini-2.5-flash')

response = model.generate_content([
    f"Provide a detailed transcript and summary of this video: {url}"
])
```

#### URL Path (non-YouTube URL detected)
```bash
# Extract with Jina Reader
curl -s "https://r.jina.ai/$URL" -H "Accept: text/markdown"
```

For full site crawling:
```python
from crawl4ai import AsyncWebCrawler, CrawlerRunConfig
import asyncio

async def crawl():
    async with AsyncWebCrawler() as crawler:
        result = await crawler.arun(url=url, config=CrawlerRunConfig())
        return result.markdown

content = asyncio.run(crawl())
```

### Phase 3: Store Results

Output routing depends on `--phase`:

#### If `--phase concept` or `--phase implementation` (default)

Write dossier to:
```
docs/cortex/research/{slug}/{phase}-{timestamp}.md
```

Steps:
1. Derive timestamp: current UTC time as `YYYYMMDDTHHMMSSZ` (compact, filesystem-safe)
2. Create directory if it does not exist:
   ```bash
   mkdir -p docs/cortex/research/{slug}/
   ```
3. Read `templates/cortex/research-dossier.md`
4. Populate all fields (SLUG, PHASE, TIMESTAMP, DEPTH, SUMMARY, FINDINGS, TRADE_OFFS, RECOMMENDATIONS, OPEN_QUESTIONS, SOURCES)
5. Write to target path

#### If `--phase evals`

Write eval proposal to:
```
docs/cortex/evals/{slug}/eval-proposal.md
```

Steps:
1. Create directory if it does not exist:
   ```bash
   mkdir -p docs/cortex/evals/{slug}/
   ```
2. Read `templates/cortex/eval-proposal.md` (NOT the research dossier template)

**Step 2.5: Enumerate all 8 eval dimensions for `{PROPOSED_DIMENSIONS}`**

For each dimension below, decide INCLUDE or EXCLUDE. Write the decision inline in the proposal — do not skip any dimension.

1. **Functional correctness** — Always include. `approval_required: false` (outcome is mechanically verifiable).
2. **Regression** — Include if any existing code, data schema, or documented behavior is modified.
3. **Integration** — Include if multiple components, services, or external APIs interact.
4. **Safety/security** — Include for auth, data handling, input validation, secrets management, or privilege escalation paths.
5. **Performance** — Include if the contract specifies latency, throughput, or resource usage thresholds.
6. **Resilience** — Include for networked systems, external dependencies, retries, or failure recovery paths.
7. **Style** — Include for all code and documentation deliverables. `approval_required: false`.
8. **UX/taste** — Include for any user-facing output or generated content. ALWAYS sets `approval_required: true`.

After evaluating all 8: set document-level `approval_required: true` if ANY dimension has `approval_required: true`. Set `Approval Status: pending`.

3. Populate all fields
4. Write to target path

### Phase 4: Update continuity state

**Update `docs/cortex/handoffs/current-state.md`:**

| Field | Value |
|-------|-------|
| `mode` | `research` |
| `recent_artifacts` | Append the artifact path just written |
| `next_action` | If `--phase concept`: `Run /cortex-research --phase implementation for implementation research, or /cortex-spec when all needed research is complete`. If `--phase evals`: `Human must approve eval proposal before /cortex-spec writes eval-plan.md` |

**Update `.cortex/state.json`:**

| Field | Value |
|-------|-------|
| `mode` | `research` |
| `artifacts` | Append artifact path just written |
| `gates.research_complete` | `true` (flip when at least one dossier exists) |

## Rules

- Reads the clarify brief as primary input context. Clarify brief must exist.
- Each `--phase` produces a separate artifact — phases are not combined in a single output.
- `--phase evals` produces an eval proposal (`eval-proposal.md`), not a research dossier.
- Each phase must be explicitly requested by the human — the system does not auto-advance to the next phase.
- `--team` is opt-in only. Agent team mode is never default behavior.
- Output is always a repo-local artifact. Chat-only responses do not count.

## Available APIs

| API | Env Var | Use For |
|-----|---------|---------|
| Tavily | `TAVILY_API_KEY` | Search (primary) |
| Jina Reader | None needed | URL extraction (free) |
| Firecrawl | `FIRECRAWL_API_KEY` | Web scraping |
| Crawl4AI | None needed | Full site crawling |
| Perplexity | `PPLX_API_KEY` | Quick deep research |
| Gemini | `GEMINI_API_KEY` | Cross-reference, YouTube, second opinion |
| OpenAI | `OPENAI_API_KEY` | gpt-researcher backend |
