# GSD Handoff: standalone-tool-skills

<!-- ART-04: GSD Handoff Template — produced by /cortex-spec -->
<!-- This is a GSD-ready work order. The human imports this into GSD explicitly. -->
<!-- Cortex NEVER calls GSD commands — that is always a human step. -->

**Slug:** standalone-tool-skills
**Timestamp:** 20260330T200000Z
**Status:** imported

---

## Objective

Build four grouped global Claude Code skills (`/web`, `/ai`, `/google`, `/cli`) that expose Firecrawl, Tavily, Jina, Perplexity, Crawl4AI, Gmail, Google Drive, Gemini, Stitch, GPT, and context-aware shell execution as first-class capabilities in any Claude session — replacing built-in WebSearch/WebFetch as the default and operating independently of Cortex state.

---

## Deliverables

- Skill file: `~/.claude/skills/web/SKILL.md` — web tool routing (Firecrawl, Tavily, Jina, Crawl4AI)
- Skill file: `~/.claude/skills/ai/SKILL.md` — AI tool routing (Perplexity, Gemini, GPT)
- Skill file: `~/.claude/skills/google/SKILL.md` — Google tool routing (Gmail, Drive, Stitch)
- Skill file: `~/.claude/skills/cli/SKILL.md` — context-aware shell execution with safety classification

---

## Requirements

- None formalized

---

## Tasks

- [ ] Create `~/.claude/skills/web/` and write SKILL.md with Firecrawl (scrape), Tavily (search), Jina (extract/read), Crawl4AI (crawl) routing; include `--save` flag and explicit WebSearch/WebFetch override instruction
- [ ] Create `~/.claude/skills/ai/` and write SKILL.md with Perplexity (deep research), Gemini (generate/analyze), GPT (generate/analyze) routing; include `--save` flag and WebSearch/WebFetch override instruction
- [ ] Obtain STITCH_API_KEY from stitch.withgoogle.com and add to environment (prerequisite for Stitch in /google)
- [ ] Create `~/.claude/skills/google/` and write SKILL.md with Gmail IMAP read, Gmail SMTP send, Google Drive public-file read, Stitch UI generation; document Drive v1 public-only limitation inline; include `--save` flag
- [ ] Create `~/.claude/skills/cli/` and write SKILL.md with LLM safety classification: read-only commands auto-execute, destructive commands require explicit confirmation, `rm -rf` class commands hard-block regardless of confirmation; include `--save` flag
- [ ] Test `/web`: scrape a URL (Firecrawl), keyword search (Tavily), read/extract a URL (Jina), full site crawl (Crawl4AI)
- [ ] Test `/ai`: deep research query (Perplexity), generate/analyze request (Gemini), generate/analyze request (GPT)
- [ ] Test `/google`: read inbox (Gmail IMAP), send test email (Gmail SMTP), read a public Drive file, generate a Stitch UI component
- [ ] Test `/cli`: run a read-only command (must auto-execute), run a destructive command (must prompt confirmation), attempt an `rm -rf` class command (must hard-block)
- [ ] Cross-skill conflict test: activate all 4 skills simultaneously; run 8 prompts covering each sub-tool; verify each routes to the correct skill with no mis-fires
- [ ] Verify override: confirm WebSearch and WebFetch do not fire on generic web/search prompts when all 4 skills are active

---

## Acceptance Criteria

- [ ] `/web` skill installed at `~/.claude/skills/web/SKILL.md`; fires on natural-language web queries without requiring explicit `/web` slash command
- [ ] `/ai` skill installed at `~/.claude/skills/ai/SKILL.md`; routes correctly to Perplexity, Gemini, or GPT based on query intent
- [ ] `/google` skill installed at `~/.claude/skills/google/SKILL.md`; Gmail read and send work end-to-end; Drive public file access works; Drive limitation documented in SKILL.md
- [ ] `/cli` skill installed at `~/.claude/skills/cli/SKILL.md`; read-only commands auto-execute without prompt; destructive commands require explicit confirmation; `rm -rf` class commands never auto-execute regardless of confirmation
- [ ] All 4 skills override built-in WebSearch and WebFetch; built-ins only trigger when user explicitly requests them
- [ ] `--save <path>` flag works on all 4 skills; when omitted, output goes to chat; when provided, output writes to the specified path
- [ ] All 4 skills operate correctly in a fresh Claude session with no `.cortex/state.json` present
- [ ] No trigger conflicts: with all 4 skills active simultaneously, 8 representative prompts each route to the correct skill with no mis-fires

---

## Contract Link

docs/cortex/contracts/standalone-tool-skills/contract-001.md
