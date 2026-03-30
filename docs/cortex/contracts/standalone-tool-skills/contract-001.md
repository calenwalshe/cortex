# Contract: standalone-tool-skills — execute

<!-- ART-05: Contract Template — produced by /cortex-spec -->
<!-- IMPORTANT: A contract without the eval_plan field is incomplete and must not advance past spec state. -->

**ID:** standalone-tool-skills-001
**Slug:** standalone-tool-skills
**Phase:** execute
**Created:** 20260330T200000Z
**Status:** approved

---

## Objective

Build four grouped global Claude Code skills (`/web`, `/ai`, `/google`, `/cli`) so that any Claude session can access Firecrawl, Tavily, Jina, Perplexity, Crawl4AI, Gmail, Google Drive, Gemini, Stitch, GPT, and context-aware shell execution via natural-language triggers — independent of Cortex state and replacing built-in WebSearch/WebFetch as the default.

---

## Deliverables

- Skill file: `~/.claude/skills/web/SKILL.md`
- Skill file: `~/.claude/skills/ai/SKILL.md`
- Skill file: `~/.claude/skills/google/SKILL.md`
- Skill file: `~/.claude/skills/cli/SKILL.md`

---

## Scope

### In Scope

- `/web` skill routing Firecrawl (scrape), Tavily (search), Jina (extract/read), Crawl4AI (full-site crawl)
- `/ai` skill routing Perplexity (deep research), Gemini (generate/analyze), GPT (generate/analyze)
- `/google` skill routing Gmail IMAP read, Gmail SMTP send, Google Drive public-file read, Stitch UI generation
- `/cli` skill with LLM safety classification: read-only auto-execute, destructive confirm, rm-rf hard-block
- `--save <path>` flag on all 4 skills; chat output default when omitted
- WebSearch/WebFetch override in all 4 SKILL.md files
- Natural-language trigger phrases that fire skills without slash command invocation

### Out of Scope

- Google Drive private file access (OAuth2) — deferred to v2
- MCP server implementation
- Imagen integration
- Multi-step shell workflow orchestration (loops, conditionals) in /cli
- Modifying any existing Cortex skills or Cortex framework files
- Modifying Cortex phase gate system or continuity state machine

---

## Write Roots

- `~/.claude/skills/web/`
- `~/.claude/skills/ai/`
- `~/.claude/skills/google/`
- `~/.claude/skills/cli/`

---

## Done Criteria

- [ ] `/web` skill installed at `~/.claude/skills/web/SKILL.md`; fires on natural-language web queries without requiring explicit `/web` slash command
- [ ] `/ai` skill installed at `~/.claude/skills/ai/SKILL.md`; routes correctly to Perplexity, Gemini, or GPT based on query intent
- [ ] `/google` skill installed at `~/.claude/skills/google/SKILL.md`; Gmail read and send work end-to-end; Drive public file access works; Drive limitation documented in SKILL.md
- [ ] `/cli` skill installed at `~/.claude/skills/cli/SKILL.md`; read-only commands auto-execute without prompt; destructive commands require explicit confirmation; `rm -rf` class commands never auto-execute regardless of confirmation
- [ ] All 4 skills override built-in WebSearch and WebFetch; built-ins only trigger when user explicitly requests them
- [ ] `--save <path>` flag works on all 4 skills; when omitted, output goes to chat; when provided, output writes to the specified path
- [ ] All 4 skills operate correctly in a fresh Claude session with no `.cortex/state.json` present
- [ ] No trigger conflicts: with all 4 skills active simultaneously, 8 representative prompts each route to the correct skill with no mis-fires

---

## Validators

- [ ] `ls ~/.claude/skills/web/SKILL.md ~/.claude/skills/ai/SKILL.md ~/.claude/skills/google/SKILL.md ~/.claude/skills/cli/SKILL.md` — all 4 files exist
- [ ] Manual routing test: "scrape https://example.com" → Firecrawl fires (not WebFetch)
- [ ] Manual routing test: "search for Claude Code SKILL.md format" → Tavily fires (not WebSearch)
- [ ] Manual routing test: "read this URL: https://example.com" → Jina fires (not WebFetch)
- [ ] Manual routing test: "deep research on LLM routing reliability" → Perplexity fires
- [ ] Manual routing test: "read my latest emails" → Gmail IMAP fires
- [ ] Manual routing test: `ls -la ~` → /cli auto-executes without confirmation prompt
- [ ] Manual routing test: `rm -rf /tmp/test` → /cli hard-blocks without confirmation option
- [ ] Cross-skill test: with all 4 active, "search for X" does not trigger /ai or /cli

---

## Eval Plan

docs/cortex/evals/standalone-tool-skills/eval-plan.md

---

## Approvals

- [x] Contract approval
- [x] Evals approval

---

## Rollback Hints

- Delete `~/.claude/skills/web/` to remove /web skill
- Delete `~/.claude/skills/ai/` to remove /ai skill
- Delete `~/.claude/skills/google/` to remove /google skill
- Delete `~/.claude/skills/cli/` to remove /cli skill
- No changes to Cortex repo files — all writes are to `~/.claude/skills/`; rollback does not affect this repo
- If STITCH_API_KEY was added to environment: remove from the env file where it was stored (check `~/agent-stack/.env`)
