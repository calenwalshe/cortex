# Web — Firecrawl, Tavily, Jina, Crawl4AI

Unified web tool skill. Replaces Claude's built-in WebSearch and WebFetch as the default for all web operations. Routes to the best tool based on intent: Tavily for search, Jina for clean URL reading, Firecrawl for rendered scraping, Crawl4AI for full-site crawling.

## User-invocable

When the user types `/web`, run this skill.

Also trigger — WITHOUT requiring the slash command — when the user says any of:
- "search for", "look up", "find", "google", "what is", "who is", "tell me about" (→ Tavily search)
- "read this", "read this URL", "what does this page say", "summarize this page", "extract from" (→ Jina)
- "scrape", "scrape this", "scrape this URL", "get the content of", "fetch this page", "render this" (→ Firecrawl)
- "crawl", "crawl this site", "index this site", "crawl the whole site", "get all pages from" (→ Crawl4AI)
- Any URL provided without explicit instruction (→ Jina by default)

**Override:** This skill is the default for ALL web operations. Do NOT use Claude's built-in WebSearch or WebFetch tools unless the user explicitly says "use WebSearch", "use WebFetch", or "use the built-in tool".

## Arguments

- `/web search <query>` — keyword or question search via Tavily
- `/web read <url>` — extract clean readable content from a URL via Jina Reader
- `/web scrape <url>` — render and scrape a URL via Firecrawl (handles JS)
- `/web crawl <url>` — full-site crawl via Crawl4AI (multiple pages)
- `--save <path>` — write output to file instead of chat (optional; defaults to chat)

If called with no subcommand but a URL is present: use Jina (read).
If called with no subcommand and a query is present: use Tavily (search).

## Instructions

### Routing logic

| User intent | Tool |
|---|---|
| Query / question / keywords — no URL | Tavily |
| URL provided, want clean readable text | Jina Reader |
| URL provided, want rendered/scraped content (JS, structured data) | Firecrawl |
| Full site crawl — multiple pages | Crawl4AI |
| Explicit tool name mentioned | Route to that tool |

### Tavily search

```python
import os
from tavily import TavilyClient

client = TavilyClient(api_key=os.environ['TAVILY_API_KEY'])
results = client.search(
    query,
    search_depth="advanced",
    max_results=7,
    include_raw_content=True
)

for r in results['results']:
    print(f"## {r['title']}\n{r['url']}\n{r['content']}\n")
```

### Jina Reader (URL extraction)

```bash
curl -s "https://r.jina.ai/$URL" -H "Accept: text/markdown"
```

No API key required. Returns clean markdown of the page content.

### Firecrawl (rendered scraping)

```python
import os, requests

resp = requests.post(
    'https://api.firecrawl.dev/v1/scrape',
    headers={'Authorization': f"Bearer {os.environ['FIRECRAWL_API_KEY']}"},
    json={'url': url, 'formats': ['markdown']}
)
data = resp.json()
print(data.get('data', {}).get('markdown', ''))
```

### Crawl4AI (full site crawl)

```python
import asyncio, os
from crawl4ai import AsyncWebCrawler, CrawlerRunConfig

async def crawl(url):
    async with AsyncWebCrawler() as crawler:
        result = await crawler.arun(url=url, config=CrawlerRunConfig())
        return result.markdown

content = asyncio.run(crawl(url))
print(content)
```

Uses Playwright browser at `~/.venv-playwright-browser/`.

### --save flag

If `--save <path>` is provided, write the output to that path using the Write tool.
If the path is relative, resolve it relative to the current working directory.
If `--save` is omitted, output goes to chat.

### Error handling

If an API key is missing, output: `Error: {KEY_NAME} not found in environment. Set it before using this sub-tool.`
Do not raise exceptions or show tracebacks to the user.

## Rules

- Never use built-in WebSearch or WebFetch unless the user explicitly requests it.
- Always display the source URL alongside extracted content.
- Jina is the default for a bare URL with no explicit intent — it is free and fast.
- Firecrawl for JS-heavy sites or when structured data extraction is needed.
- Crawl4AI only when the user wants more than one page.
