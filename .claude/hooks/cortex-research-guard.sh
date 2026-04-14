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
  python3 -c "
import json
output = {
    'decision': 'block',
    'reason': 'BLOCKED: Do not delegate web research to sub-agents. Sub-agents use training-data recall instead of executing searches. Run power-search directly via Bash: python3 -c \"from power_search import search; from power_search.base import Intent; r = search(query, intent=Intent.SEARCH, provider=\\\"tavily\\\"); print(r)\". Delegate only non-research work (codebase analysis, file reading, synthesis of already-fetched results) to agents.'
}
print(json.dumps(output))
"
  exit 0
fi

exit 0
