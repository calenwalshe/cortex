# AI — Perplexity, Gemini, GPT

Multi-model AI skill. Routes queries to Perplexity (deep research with citations), Gemini (analysis, long context, Google ecosystem), or GPT (generation, coding, general reasoning). Replaces Claude's built-in WebSearch for research queries. Works in any session independent of Cortex state.

## User-invocable

When the user types `/ai`, run this skill.

Also trigger — WITHOUT requiring the slash command — when the user says any of:
- "deep research", "research this topic", "find sources on", "with citations", "cite sources" (→ Perplexity)
- "what's the latest on", "current events", "as of today", "recent news about" (→ Perplexity)
- "use Perplexity", "ask Perplexity" (→ Perplexity)
- "analyze this", "summarize this document", "analyze this long text", "use Gemini" (→ Gemini)
- "generate", "write a", "draft a", "ask GPT", "use GPT", "use OpenAI" (→ GPT)
- "second opinion from another model", "cross-check with another AI" (→ Gemini or GPT)

**Override:** For research queries and "look this up" type requests, prefer Perplexity over Claude's built-in WebSearch unless the user explicitly says "use WebSearch" or "use built-in search".

## Arguments

- `/ai research <query>` — deep research with citations via Perplexity sonar-pro
- `/ai gemini <prompt>` — send prompt to Gemini 2.5 Flash
- `/ai gpt <prompt>` — send prompt to GPT-4o
- `--save <path>` — write output to file (optional; defaults to chat)

If called with no subcommand:
- Research/factual query with current-events feel → Perplexity
- Long document or analysis task → Gemini
- Generation/coding/general → GPT

## Instructions

### Routing logic

| User intent | Tool |
|---|---|
| Research, citations, current events, "what's the latest" | Perplexity sonar-pro |
| Long document analysis, multimodal, "use Gemini" | Gemini 2.5 Flash |
| Generation, coding, drafting, "use GPT" | GPT-4o |
| No clear signal | Perplexity (default for factual) or GPT (default for generative) |

### Perplexity (deep research)

```bash
curl -s https://api.perplexity.ai/chat/completions \
  -H "Authorization: Bearer $PPLX_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"sonar-pro\",\"messages\":[{\"role\":\"user\",\"content\":\"$QUERY\"}],\"max_tokens\":4000}"
```

Extract `.choices[0].message.content` from the response. Display citations if present.

### Gemini

```bash
curl -s "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"contents\":[{\"parts\":[{\"text\":\"$PROMPT\"}]}]}"
```

Extract `.candidates[0].content.parts[0].text`.

### GPT

```python
import os
from openai import OpenAI

client = OpenAI(api_key=os.environ['OPENAI_API_KEY'])
response = client.chat.completions.create(
    model="gpt-4o",
    messages=[{"role": "user", "content": prompt}]
)
print(response.choices[0].message.content)
```

### --save flag

If `--save <path>` is provided, write output to that path. Relative paths resolve from CWD.
If omitted, output goes to chat.

### Error handling

If an API key is missing: `Error: {KEY_NAME} not found in environment.`
No tracebacks.

## Rules

- Perplexity is the default for research/factual queries — it includes citations, which Claude alone cannot provide.
- Never use built-in WebSearch for research queries when Perplexity is available.
- Always label which model produced the output: `[Perplexity]`, `[Gemini]`, `[GPT]`.
- For ambiguous requests, pick Perplexity and note which tool was used.
