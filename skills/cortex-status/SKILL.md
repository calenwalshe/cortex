# Cortex Status

Show the current state of the Cortex system — active layers, upstream versions, API connectivity, and installed tools.

## User-invocable
When the user types `/cortex-status`, run this skill.

## Instructions

Run the following checks and present a formatted status report:

### 1. Layer Status
```bash
# Check each layer file exists
for f in tdd.md debugging.md code-review.md; do
  test -f ~/projects/cortex/layers/discipline/$f && echo "  Layer 2 (Discipline): $f ✓" || echo "  Layer 2 (Discipline): $f ✗"
done
for f in anti-sycophancy.md forcing-questions.md investigate.md security-audit.md; do
  test -f ~/projects/cortex/layers/thinking/$f && echo "  Layer 3 (Thinking): $f ✓" || echo "  Layer 3 (Thinking): $f ✗"
done
```

### 2. Upstream Versions
```bash
cd ~/projects/cortex
echo "Superpowers: $(cd upstream/superpowers && git describe --tags 2>/dev/null || git rev-parse --short HEAD)"
echo "GStack:      $(cd upstream/gstack && git describe --tags 2>/dev/null || git rev-parse --short HEAD)"
echo "GSD:         local copy"
```

### 3. API Connectivity
Test each API key is set and functional:

```bash
# Tavily
[ -n "$TAVILY_API_KEY" ] && echo "Tavily: configured" || echo "Tavily: NOT SET"

# Firecrawl
[ -n "$FIRECRAWL_API_KEY" ] && echo "Firecrawl: configured" || echo "Firecrawl: NOT SET"

# Perplexity
[ -n "$PPLX_API_KEY" ] && echo "Perplexity: configured" || echo "Perplexity: NOT SET"

# Gemini
[ -n "$GEMINI_API_KEY" ] && echo "Gemini: configured" || echo "Gemini: NOT SET"

# OpenAI
[ -n "$OPENAI_API_KEY" ] && echo "OpenAI: configured" || echo "OpenAI: NOT SET"
```

### 4. Research Tools
```bash
source ~/claude-stack-env/bin/activate 2>/dev/null
which yt-dlp && echo "yt-dlp: $(yt-dlp --version)"
which ffmpeg && echo "ffmpeg: installed"
python3 -c "import tavily" 2>/dev/null && echo "tavily-python: installed" || echo "tavily-python: MISSING"
python3 -c "import firecrawl" 2>/dev/null && echo "firecrawl-py: installed" || echo "firecrawl-py: MISSING"
python3 -c "from gpt_researcher import GPTResearcher" 2>/dev/null && echo "gpt-researcher: installed" || echo "gpt-researcher: MISSING"
python3 -c "import crawl4ai" 2>/dev/null && echo "crawl4ai: installed" || echo "crawl4ai: MISSING"
python3 -c "import google.generativeai" 2>/dev/null && echo "google-genai: installed" || echo "google-genai: MISSING"
python3 -c "import openai" 2>/dev/null && echo "openai-sdk: installed" || echo "openai-sdk: MISSING"
```

### 5. GSD Status
```bash
# Check if GSD is active
test -d .planning && echo "GSD: active (.planning/ found)" || echo "GSD: no project in current dir"
test -f .planning/STATE.md && cat .planning/STATE.md | head -5
```

### 6. Output Format

Present as:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 CORTEX STATUS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Layer 1 (Workflow):   GSD [active/inactive]
Layer 2 (Discipline): [N/4] rules loaded
Layer 3 (Thinking):   [N/4] rules loaded

Upstreams:
  Superpowers: [version/hash]
  GStack:      [version/hash]
  GSD:         local copy

APIs:
  Tavily:      [configured/NOT SET]
  Firecrawl:   [configured/NOT SET]
  Perplexity:  [configured/NOT SET]
  Gemini:      [configured/NOT SET]
  OpenAI:      [configured/NOT SET]

Tools: [N] installed, [N] missing

Available skills:
  /cortex-status      — This report
  /cortex-investigate — Systematic debugging (Iron Law)
  /cortex-audit       — Security audit (OWASP + STRIDE)
  /cortex-review      — Multi-lens code review
  /cortex-research    — Deep multi-LLM research

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

<!-- cortex-sync smoke test: 2026-03-28T00:29:39Z -->
