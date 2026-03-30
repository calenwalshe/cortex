# Next Prompt

We are working on **standalone-tool-skills** in **execute** mode. All 4 skills have been installed:
- `~/.claude/skills/web/SKILL.md`
- `~/.claude/skills/ai/SKILL.md`
- `~/.claude/skills/google/SKILL.md`
- `~/.claude/skills/cli/SKILL.md`

The gsd-handoff is marked as `imported`. All contract gates are approved.

The next step is: **run the validators from contract-001.md** to confirm done criteria are met.

Validators to run (from `docs/cortex/contracts/standalone-tool-skills/contract-001.md`):
1. `ls ~/.claude/skills/web/SKILL.md ~/.claude/skills/ai/SKILL.md ~/.claude/skills/google/SKILL.md ~/.claude/skills/cli/SKILL.md` — all 4 files exist
2. Manual routing test: "scrape https://example.com" → Firecrawl fires (not WebFetch)
3. Manual routing test: "search for Claude Code SKILL.md format" → Tavily fires (not WebSearch)
4. Manual routing test: "read this URL: https://example.com" → Jina fires (not WebFetch)
5. Manual routing test: "deep research on LLM routing reliability" → Perplexity fires
6. Manual routing test: "read my latest emails" → Gmail IMAP fires
7. Manual routing test: `ls -la ~` → /cli auto-executes without confirmation prompt
8. Manual routing test: `rm -rf /tmp/test` → /cli hard-blocks without confirmation option
9. Cross-skill test: with all 4 active, "search for X" does not trigger /ai or /cli

Run /cortex-status to see the full current state.
