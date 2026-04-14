#!/usr/bin/env bash
# cortex-research-guard.sh
# PreToolUse on Agent — blocks research-intent agents that don't use power-search.
# Applies globally, not just within Cortex workflow.
# Forces all web research through power-search providers (Tavily, Perplexity, Jina, Firecrawl).

set -uo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

[[ "$TOOL_NAME" != "Agent" ]] && exit 0

PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // ""' 2>/dev/null)
DESC=$(echo "$INPUT" | jq -r '.tool_input.description // ""' 2>/dev/null)
COMBINED="$PROMPT $DESC"

# Does this look like a web research task?
if echo "$COMBINED" | grep -qiE "search the web|web search|find (papers|sources|articles)|look for.*(research|studies|academic)|investigate.*online|search for.*(data|evidence|literature)"; then
  # Already routing through power-search? Allow.
  if echo "$COMBINED" | grep -qiE "power.search|power_search|from power_search"; then
    exit 0
  fi

  python3 -c "
import json
output = {
    'decision': 'block',
    'reason': 'BLOCKED: Web research agents must use power-search. Add to your agent prompt: from power_search import search — then use search(query, provider=\"tavily\") for search, provider=\"perplexity\" for quick facts, provider=\"jina\" for URL reading, provider=\"firecrawl\" for scraping. Or use /cortex-research which wraps this automatically.'
}
print(json.dumps(output))
"
  exit 0
fi

exit 0
