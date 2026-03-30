# Spec: standalone-tool-skills

<!-- ART-03: Spec Template — produced by /cortex-spec -->

**Slug:** standalone-tool-skills
**Timestamp:** 20260330T200000Z
**Status:** approved

---

## 1. Problem

Claude Code sessions default to built-in WebSearch and WebFetch for web operations and have no first-class access to the richer tool ecosystem already configured in the environment — Firecrawl, Tavily, Jina, Perplexity, Crawl4AI, Gmail, Google Drive, Gemini, Stitch, and GPT. These tools are only available inside `/cortex-research`, which requires an active Cortex slug and a clarify brief. Every general-purpose Claude session starts without access to these capabilities, forcing users to either invoke `/cortex-research` for tasks that don't warrant a full research pipeline, or fall back to the weaker built-in tools. The goal is to expose all of these as four grouped global skills — `/web`, `/ai`, `/google`, `/cli` — that are available in any session, independent of Cortex state.

---

## 2. Scope

### In Scope

- `/web` skill: Firecrawl (scrape URLs), Tavily (keyword search), Jina Reader (URL extraction/read), Crawl4AI (full site crawl)
- `/ai` skill: Perplexity (deep research via sonar-pro), Gemini (generation and analysis), OpenAI/GPT (generation and analysis)
- `/google` skill: Gmail read/send (via IMAP/SMTP using `~/.gmail_creds.json`), Google Drive read (public files via API key), Stitch UI generation (via STITCH_API_KEY)
- `/cli` skill: context-aware shell execution with LLM-mediated safety classification (read-only auto-executes, destructive requires confirmation)
- All 4 skills installed as global skills in `~/.claude/skills/`
- `--save <path>` flag on all skills; defaults to CWD when invoked; chat output when flag omitted
- Override of Claude's built-in WebSearch and WebFetch — built-ins only trigger on explicit user request
- Natural-language triggers (e.g., "scrape this URL", "search for X", "send an email to Y")

### Out of Scope

- Modifying `/cortex-research`, `/cortex-spec`, or any other existing Cortex skills
- Google Drive private file access — OAuth2 service account setup deferred to v2
- MCP server implementation — skills invoke APIs via Bash/Python, not MCP protocol
- Imagen integration — not confirmed available in environment
- Multi-step shell workflow orchestration (pipes, loops, conditionals) in `/cli` — single commands and simple piped commands only
- Adding new tool integrations not already in the environment
- Modifying Cortex phase gate system or continuity state machine

---

## 3. Architecture Decision

**Chosen approach:** Four grouped skills (`/web`, `/ai`, `/google`, `/cli`) with LLM-internal routing defined entirely in SKILL.md trigger phrases and routing instructions.

**Rationale:** Claude Code's skill system routes to a skill using the LLM's forward pass over all loaded SKILL.md descriptions. No regex, embeddings, or classifiers are involved. This means routing reliability is purely a function of description quality and trigger phrase coverage. A grouped approach (4 commands vs. 12) reduces user cognitive load while keeping each SKILL.md manageable. The implementation is thin SKILL.md wrapper files — no new Python packages, no new infrastructure.

### Alternatives Considered

- **12 individual skills (one per tool):** Rejected — too many slash commands; user cognitive load unacceptable; duplicate boilerplate across files; no reduction in routing complexity since the LLM still must pick between 12 options
- **MCP server:** Rejected explicitly in clarify brief non-goals — skills invoke APIs via Bash/Python; MCP protocol overhead not warranted
- **Single `/tools` skill covering everything:** Rejected — one SKILL.md covering 11 tools would be unwieldy; trigger surface too broad; routing quality would degrade
- **Modifying `/cortex-research` to be callable standalone:** Rejected — cortex-research requires an active slug and clarify brief; making it stateless would break its design contract

---

## 4. Interfaces

- **Firecrawl API** — external, `FIRECRAWL_API_KEY` env var; `/web` skill reads (scrape/crawl), writes nothing
- **Tavily API** — external, `TAVILY_API_KEY` env var; `/web` skill reads (search), writes nothing
- **Jina Reader** (`r.jina.ai`) — external, no API key required; `/web` skill reads (URL extraction), writes nothing
- **Crawl4AI** — local install (`crawl4ai` Python package, Playwright venv at `~/.venv-playwright-browser/`); `/web` skill invokes async crawl, writes nothing
- **Perplexity API** — external, `PPLX_API_KEY` env var; `/ai` skill reads (deep research), writes nothing
- **Gemini API** — external, `GEMINI_API_KEY` env var; `/ai` skill reads (generation/analysis), writes nothing
- **OpenAI API** — external, `OPENAI_API_KEY` env var; `/ai` skill reads (generation/analysis), writes nothing
- **Gmail IMAP/SMTP** — external, credentials at `~/.gmail_creds.json`; `/google` skill reads (IMAP) and writes (SMTP send)
- **Google Drive API** — external, `GOOGLE_API_KEY` env var (public files only); `/google` skill reads, writes nothing
- **Stitch SDK** (`@google/stitch-sdk` npm) — external, `STITCH_API_KEY` env var; `/google` skill reads (generate UI), writes HTML/image to chat or `--save` path
- **`~/.claude/skills/`** — local filesystem; write root for skill installation (4 new directories)
- **`cli-anything` plugin** — installed global Claude Code plugin; `/cli` skill trigger phrases must not overlap

---

## 5. Dependencies

- **crawl4ai** — installed in `claude-stack-env`; used by `/web` for full-site crawl; Playwright browser at `~/.venv-playwright-browser/`
- **Python stdlib: `imaplib`, `smtplib`, `email`** — no install needed; used by `/google` for Gmail
- **`@google/stitch-sdk` npm** — used by `/google` for Stitch UI generation; requires `STITCH_API_KEY`
- **Environment variables** — `FIRECRAWL_API_KEY`, `TAVILY_API_KEY`, `PPLX_API_KEY`, `GEMINI_API_KEY`, `OPENAI_API_KEY` confirmed present; `STITCH_API_KEY` must be obtained before `/google` ships Stitch support
- **`~/.gmail_creds.json`** — confirmed present; used by `/google` for Gmail auth

---

## 6. Risks

- **SKILL.md routing mis-fires if trigger descriptions are ambiguous** — Mitigation: write exhaustive trigger phrase lists per sub-tool; prototype `/web` first and validate routing before building remaining skills
- **STITCH_API_KEY not in environment** — Mitigation: obtain from stitch.withgoogle.com before building `/google`; ship `/google` without Stitch if key is unavailable at build time, with a clear error message in the skill
- **`/cli` safety layer over-blocks legitimate commands** — Mitigation: default to auto-execute for read-only classification; require confirmation only for destructive class; never auto-execute `rm -rf`, `drop`, `delete` class; user can override with explicit confirmation
- **Trigger conflicts between the 4 active skills** — Mitigation: test all 4 skills active simultaneously with ambiguous prompts before declaring done; adjust trigger phrases until no cross-fires
- **Google Drive limited to public files in v1** — Mitigation: document limitation explicitly in `/google` SKILL.md; OAuth2 path noted as v2 work
- **`cli-anything` plugin conflicts with `/cli` skill** — Mitigation: `/cli` trigger phrases must be semantically distinct from cli-anything's passthrough triggers; test both active simultaneously

---

## 7. Sequencing

1. **Scaffold `/web` skill** — create `~/.claude/skills/web/SKILL.md` with Firecrawl/Tavily/Jina/Crawl4AI routing and WebSearch/WebFetch override instruction
2. **Validate `/web` routing** — test with 5 natural-language prompts covering each sub-tool and verify correct sub-tool fires each time
3. **Scaffold `/ai` skill** — create `~/.claude/skills/ai/SKILL.md` with Perplexity/Gemini/GPT routing
4. **Validate `/ai` routing** — test with queries that should route to each of the 3 sub-tools
5. **Obtain `STITCH_API_KEY`; scaffold `/google` skill** — Gmail + Drive + Stitch; document Drive public-only limitation inline
6. **Validate `/google` routing** — test read email, send email, Drive public file read, Stitch generate
7. **Scaffold `/cli` skill** — LLM safety classification: read-only → auto-execute; destructive → confirm; rm-rf class → hard block
8. **Validate `/cli` safety layer** — test with read-only commands, destructive commands, and rm-rf class commands
9. **Cross-skill conflict test** — run all 4 skills active simultaneously; verify no trigger mis-fires
10. **Verify WebSearch/WebFetch override** — confirm built-ins do not fire on generic web queries when all 4 skills are active

---

## 8. Tasks

- [ ] Create `~/.claude/skills/web/` and write SKILL.md with Firecrawl (scrape), Tavily (search), Jina (extract/read), Crawl4AI (crawl) routing, `--save` flag, and WebSearch/WebFetch override instruction
- [ ] Create `~/.claude/skills/ai/` and write SKILL.md with Perplexity (deep research), Gemini (generate/analyze), GPT (generate/analyze) routing, `--save` flag, and WebSearch/WebFetch override instruction
- [ ] Obtain STITCH_API_KEY from stitch.withgoogle.com and add to environment
- [ ] Create `~/.claude/skills/google/` and write SKILL.md with Gmail read/send, Drive public-read, Stitch routing; document Drive v1 limitation inline; add `--save` flag
- [ ] Create `~/.claude/skills/cli/` and write SKILL.md with LLM safety classification (read-only auto-execute, destructive confirm, rm-rf class hard-block); add `--save` flag
- [ ] Test `/web`: URL scrape (Firecrawl), keyword search (Tavily), URL read (Jina), full site crawl (Crawl4AI)
- [ ] Test `/ai`: deep research query (Perplexity), generate/analyze (Gemini), generate/analyze (GPT)
- [ ] Test `/google`: read inbox (Gmail IMAP), send email (Gmail SMTP), read public Drive file, Stitch generate UI
- [ ] Test `/cli`: read-only command auto-executes without prompt; destructive command requires confirmation; `rm -rf` class hard-blocks
- [ ] Test cross-skill: activate all 4 simultaneously, run 8 ambiguous prompts, verify each routes to the correct skill with no cross-fires
- [ ] Verify override: confirm WebSearch and WebFetch do not fire on generic "search for X" or "read this URL" prompts when skills are active

---

## 9. Acceptance Criteria

- [ ] `/web` skill installed at `~/.claude/skills/web/SKILL.md`; fires on natural-language web queries without requiring explicit `/web` slash command
- [ ] `/ai` skill installed at `~/.claude/skills/ai/SKILL.md`; routes correctly to Perplexity, Gemini, or GPT based on query intent
- [ ] `/google` skill installed at `~/.claude/skills/google/SKILL.md`; Gmail read and send work end-to-end; Drive public file access works; Drive limitation documented in SKILL.md
- [ ] `/cli` skill installed at `~/.claude/skills/cli/SKILL.md`; read-only commands auto-execute without prompt; destructive commands (e.g., file deletion, git reset --hard) require explicit confirmation; `rm -rf` class commands never auto-execute regardless of confirmation
- [ ] All 4 skills override built-in WebSearch and WebFetch; built-ins only trigger when user explicitly requests them (e.g., "use WebFetch", "use built-in search")
- [ ] `--save <path>` flag works on all 4 skills; when omitted, output goes to chat; when provided, output writes to the specified path (defaulting to CWD-relative path if relative)
- [ ] All 4 skills operate correctly in a fresh Claude session with no `.cortex/state.json` present
- [ ] No trigger conflicts: with all 4 skills active simultaneously, 8 representative prompts each route to the correct skill with no mis-fires
