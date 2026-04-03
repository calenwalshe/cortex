# Cortex Research — Deep Multi-Source, Multi-LLM Research

Systematic research pipeline routing all API calls through power-search's unified `search()` interface. Supports multiple providers (Tavily, Jina, Perplexity, Gemini, Firecrawl) with automatic cost tracking and fallback chains. Uses gpt-researcher for deep investigations. Produces structured dossiers written to the target project repo under `docs/cortex/`.

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
| `--autonomy` | Optional | Override autonomy preset for this invocation: `supervised`, `gates-only`, `full-auto` | Current config |
| `--gate` | Optional | Override specific gate: `--gate eval_proposal=false`. Repeatable. | Current config |
| `--dry-run` | Optional | Print resolved autonomy gate table without executing any command logic or writing files | Off |

### --dry-run Mode

If `--dry-run` is passed:
1. Resolve autonomy config using `resolveAutonomyWithSources` from `scripts/cortex/resolve-autonomy.js`
2. Print the resolved gate table showing gate name, value, and source layer for all 13 gates
3. Print which gates this specific command checks (cortex-research checks `eval_proposal`)
4. Do NOT execute any command logic, write any files, or modify any state
5. Exit after printing the table

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
```python
from power_search import search
from power_search.base import Intent

result = search(query, intent=Intent.RESEARCH, provider="perplexity", max_tokens=2000)
```

#### Standard Path (default)

**Step 1: Multi-source search (parallel)**
```python
from power_search import search
from power_search.base import Intent

# Multi-source search
results = search(query, intent=Intent.SEARCH, provider="tavily", depth="advanced", max_results=7)
```

```python
# Extract top 3 source URLs
for url in top_urls[:3]:
    content = search(url, intent=Intent.READ_URL)
```

**Step 2: Analyze and identify gaps**
Read all sources. What's consistent? What conflicts? What's missing?
Generate follow-up queries for gaps.

**Step 3: Fill gaps (iterate)**
```python
# Follow-up searches (max 2 rounds)
for follow_up_query in gap_queries[:2]:
    more = search(follow_up_query, intent=Intent.SEARCH, provider="tavily", max_results=3)
    for url in top_urls:
        content = search(url, intent=Intent.READ_URL)
```

**Step 4: Cross-reference with Gemini**
Send consolidated findings to Gemini for a second-opinion analysis:
```python
# Cross-reference with Gemini (GENERATE, not GROUNDED_SEARCH — analyzing gathered findings)
cross_ref = search(consolidated_findings, intent=Intent.GENERATE, provider="gemini")
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

```python
# Post-hoc cost tracking (gpt-researcher manages its own API calls)
from power_search.tracker import usage
import time

start = time.monotonic()
report = asyncio.run(research())
elapsed = int((time.monotonic() - start) * 1000)

usage.record(
    provider="gpt_researcher",
    intent="research",
    query=query,
    cost=0.0,  # gpt-researcher doesn't expose per-call cost; logged for tracking
    elapsed_ms=elapsed
)
```

#### YouTube Path (YouTube URL detected)
```python
from power_search import search
from power_search.base import Intent

result = search(url, intent=Intent.YOUTUBE_VIDEO, mode="summary")
```

#### URL Path (non-YouTube URL detected)
```python
from power_search import search
from power_search.base import Intent

result = search(url, intent=Intent.READ_URL)
```

For full site crawling:
```python
from power_search import search
from power_search.base import Intent

result = search(url, intent=Intent.CRAWL_SITE)
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

### Phase 3b: Write Eval Plan

**Trigger:** Only run this phase when explicitly asked to write the eval plan (e.g., `/cortex-research --write-plan` or "write the eval plan").

**Autonomy gate check (`eval_proposal`):**
Before checking eval proposal approval status, resolve the autonomy config:
1. Read `.cortex/autonomy.json` (project-level) and `~/.claude/cortex-autonomy.json` (global-level) if they exist.
2. Determine the active preset (default: `supervised` if no config found).
3. Look up `gates.eval_proposal` in the resolved config. If `--autonomy` or `--gate` flags were provided, use them as the invocation layer (highest precedence in the 4-layer resolution). Resolution order: invocation flags > project config > global config > preset defaults. Mandatory gates (`ux_taste_eval`, `human_action`, `reclarify`) are always forced true regardless of config.
4. If `gates.eval_proposal` is `false`: **skip the approval status check** — proceed directly to writing the eval plan as if `Approval Status: approved`.
   When auto-proceeding (gate is false/skipped), append a decision log entry to `docs/cortex/handoffs/decisions.md` under the `## Autonomy Decisions` section:
   ```
   - {ISO8601 timestamp} | gate: eval_proposal | value: false (auto-skipped) | preset: {active_preset} | command: /cortex-research
   ```
   Continue to the "If `approval_required: false` OR `Approval Status: approved`:" branch below.
5. If `gates.eval_proposal` is `true` (or no autonomy config exists): evaluate the approval status check as described below (existing behavior preserved — blocks when approval is pending).

**Prerequisites:**

1. Read `docs/cortex/evals/{slug}/eval-proposal.md`
2. Extract `approval_required:` field value
3. Extract `Approval Status:` field value

**Decision logic:**

If the `eval_proposal` gate is active (per autonomy check above) AND `approval_required: true` AND `Approval Status:` is NOT `approved`:

  Output the following and STOP — do not write eval-plan.md:

  ```
  BLOCKED: Eval Plan Cannot Be Written
  ════════════════════════════════════════
  The eval proposal at docs/cortex/evals/{slug}/eval-proposal.md
  has approval_required: true but Approval Status: {current_status}.

  Required action:
    1. Review the proposal at docs/cortex/evals/{slug}/eval-proposal.md
    2. Edit the file: change "Approval Status: pending" → "Approval Status: approved"
       (or "Approval Status: rejected" if you want to revise the proposal)
    3. Re-run: /cortex-research --write-plan

  The contract will remain in spec state until this approval is recorded.
  ════════════════════════════════════════
  ```

If `Approval Status:` is `rejected`:

  Output and STOP:
  ```
  BLOCKED: Eval proposal was rejected.
  Revise the proposal (re-run /cortex-research --phase evals), then re-run /cortex-research --write-plan.
  ```

If `approval_required: false` OR `Approval Status: approved`:

  Idempotency check: if `docs/cortex/evals/{slug}/eval-plan.md` already exists, output:
  ```
  Eval plan already exists at docs/cortex/evals/{slug}/eval-plan.md — skipping creation.
  ```
  and stop.

  Otherwise:
  1. Read `templates/cortex/eval-plan.md`
  2. Populate all fields from the approved proposal content (slug, approved dimensions, fixtures, thresholds, run instructions)
  3. Write to `docs/cortex/evals/{slug}/eval-plan.md`
  4. Update `.cortex/state.json`: set `approvals.evals = true`
  5. Update `docs/cortex/handoffs/current-state.md`:
     - `approval_status`: `approved`
     - `next_action`: `Eval plan written to docs/cortex/evals/{slug}/eval-plan.md. Update the contract's eval_plan field to point to this path.`
  6. Output confirmation:
     ```
     Eval plan written: docs/cortex/evals/{slug}/eval-plan.md
     Update the contract's eval_plan field to: docs/cortex/evals/{slug}/eval-plan.md
     ```

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
| `reclarify_required` | `true` — **conditional**: write only when research evidence invalidates the current problem frame or core assumptions (see below) |

**Conditional: reclarify_required**

After synthesizing findings, evaluate whether the research evidence contradicts or materially changes the problem frame or core assumptions established in the clarify brief.

If evidence invalidates the frame or assumptions:
1. Write `reclarify_required: true` to `.cortex/state.json`.
2. Emit the following warning in the output (before the normal dossier confirmation):

```
⚠ RECLARIFY REQUIRED
════════════════════════════════════════
Research evidence has changed the problem frame or invalidated core assumptions.

Run /cortex-clarify to reframe before proceeding to /cortex-spec.
(reclarify_required: true has been written to .cortex/state.json)
════════════════════════════════════════
```

If evidence does not invalidate the frame, do not write `reclarify_required` and do not emit the warning.

See `docs/DISCOVERY_LOOP.md` §1 (research → clarify backtrack transition) for full semantics.

## Rules

- Reads the clarify brief as primary input context. Clarify brief must exist.
- Each `--phase` produces a separate artifact — phases are not combined in a single output.
- `--phase evals` produces an eval proposal (`eval-proposal.md`), not a research dossier.
- Each phase must be explicitly requested by the human — the system does not auto-advance to the next phase.
- `--team` is opt-in only. Agent team mode is never default behavior.
- Output is always a repo-local artifact. Chat-only responses do not count.

## Search Backend

All search, extraction, and generation calls route through the **power-search** library (`/search` skill). This provides:
- Unified `search(query, intent=Intent.X)` interface for all providers
- Automatic provider fallback chains (e.g., jina -> firecrawl for READ_URL)
- Cost tracking per query in `~/.power-search/usage.db`
- Budget enforcement via optional `daily_budget` config

See: `/home/agent/projects/claude-power-search/SKILL.md` for full API reference.

Exception: `--depth deep` uses gpt-researcher directly (requires `OPENAI_API_KEY`), with post-hoc cost logging via `usage.record()`.
