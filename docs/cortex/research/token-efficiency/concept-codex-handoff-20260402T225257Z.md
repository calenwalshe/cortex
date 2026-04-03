# Research Dossier: token-efficiency — concept (Codex Handoff)

**Slug:** token-efficiency
**Phase:** concept (targeted pass — Codex handoff angle)
**Timestamp:** 20260402T225257Z
**Depth:** standard

---

## Summary

Codex CLI (v0.106.0) is well-suited as an autonomous execution layer for GSD tasks. The `codex exec --full-auto --json` mode provides sandboxed workspace-write access, JSONL event streaming with per-turn token counts, and stdin piping for structured plan input. The existing /codex-review and /gsd-codex-verify skills prove the handoff pattern works for reviews — extending to execution requires a context capsule format, a task router that classifies work as Codex-safe vs Claude-required, and a result parser that feeds Codex token usage into the unified ledger. Roughly 60-70% of GSD executor tasks (standard auto, TDD, bug fixes, blocking issues) are Codex-safe with no modification.

---

## Findings

### A. Codex Exec Capabilities

- **Autonomous mode:** `codex exec --full-auto` sets `approval_policy=on-request` + `sandbox_mode=workspace-write` — model handles its own failures, writes confined to workspace + TMPDIR, network disabled in sandbox
- **Structured output:** `--json` streams JSONL events including `turn.completed` with `{input_tokens, output_tokens, cached_input_tokens, reasoning_tokens}` — token tracking comes free
- **Plan input:** Stdin piping works natively: `cat PLAN.md | codex exec --full-auto -` — no need to serialize context into a prompt string
- **Result capture:** `-o /path/to/output.md` writes final message to file; `--output-schema <file>` constrains final response to a JSON Schema for machine-parseable results
- **Directory control:** `-C /path` sets working directory, `--add-dir <path>` extends writable roots
- **Session management:** `codex exec resume --last "follow-up"` enables multi-turn autonomous work
- **AGENTS.md hierarchy:** Auto-discovers instructions from `~/.codex/AGENTS.md` → project root → cwd (32KB max, configurable). Already configured to fall back to `CLAUDE.md`
- **No built-in timeout:** Must wrap with `timeout <seconds>` externally (current skills already do this)
- **Profiles:** `-p <name>` loads named config profiles — can have `review`, `fast`, `thorough` presets

### B. Existing Handoff Pattern (Gaps for Execution)

Current /codex-review and /gsd-codex-verify are **review-focused and unidirectional**: Claude constructs a prompt with diff + requirements, Codex returns CRITICAL/WARNING/INFO findings. For general execution handoff, 5 critical gaps need filling:

1. **No context capsule format** — reviews pass raw diffs and requirements summaries as prompt strings. Execution needs a structured capsule: task definition, file scope, acceptance criteria, deviation rules, commit instructions
2. **No result validation beyond severity parsing** — reviews parse CRITICAL/WARNING/INFO lines. Execution needs: did the task complete? what files changed? did tests pass? what deviations occurred?
3. **No token cost capture** — existing skills don't extract token usage from Codex's JSONL output. The `turn.completed` events contain `usage` fields that go unread
4. **No task routing** — everything goes to Codex or doesn't. Need classification: which tasks are Codex-safe vs which need Claude's interactive context
5. **No rollback on failure** — if Codex produces broken code, there's no automatic revert. Git worktrees would provide isolation

### C. Task Classification (Codex-Safe vs Claude-Required)

**Codex-safe (60-70% of GSD tasks):**

| Task Type | Why Safe | Key Constraint |
|-----------|----------|----------------|
| Standard `type="auto"` tasks | Deterministic, measurable criteria | Must have concrete `<action>` + verifiable criteria |
| TDD plans (RED-GREEN-REFACTOR) | Mechanical cycle, tests prove correctness | Single feature per plan |
| Bug fixes (Deviation Rule 1) | Code is objectively wrong | Must add regression test |
| Missing critical features (Rule 2) | Required for correctness/security | Must add tests |
| Blocking issue fixes (Rule 3) | Can't proceed without fix | Verify fix unblocks task |

**Claude-required (30-40%):**

| Task Type | Why Claude | Pattern |
|-----------|-----------|---------|
| Visual/functional verification | Human judgment ("looks right") | Codex builds, Claude verifies |
| Architecture decisions (Rule 4) | Business/design tradeoffs | Codex presents options, user decides |
| Manual actions (auth gates) | Needs user credentials/browser | Codex detects, Claude handles |
| Exploratory/research work | Requires iterative reasoning | Belongs in planning phase |
| Performance tuning | Benchmarking + decision loops | Not mechanical |

**Hybrid (start Codex, may escalate):**
- Complex multi-file implementations — mostly safe but may hit Rule 4 (new table/schema)
- External service integration — safe implementation, but auth gates require Claude

### D. Codex Token Tracking

- **JSONL events:** `turn.completed` includes `{input_tokens, output_tokens, cached_input_tokens, reasoning_tokens}` — directly parseable
- **Session logs:** `~/.codex/sessions/` stores JSONL with `token_count` events (cumulative totals)
- **State DB:** `~/.codex/state_5.sqlite` (3.4MB) contains session history
- **No native cost command** — must parse JSONL output or use third-party tools (`@ccusage/codex`)
- **Can feed into unified ledger:** Parse `--json` output during execution, extract token counts per task, write to the same SQLite ledger as Claude usage

---

## Trade-offs

### Option: Context capsule via stdin pipe (plan file)
**Pros:** Native Codex support, no serialization overhead, plan files already exist in GSD, human-readable
**Cons:** No schema validation, 32KB AGENTS.md limit doesn't apply to stdin (unlimited), but very large plans may degrade Codex performance
**Verdict:** selected — `cat task-capsule.md | codex exec --full-auto --json -C /project -` is the simplest path

### Option: Context capsule via --output-schema for structured results
**Pros:** Machine-parseable output, enforces response structure, enables automated result validation
**Cons:** Only constrains final message (not intermediate tool use), requires maintaining a JSON Schema, adds complexity
**Verdict:** selected for result capture — define a `task-result.schema.json` that Codex's final message must conform to (status, files_changed, tests_passed, deviations, token_usage)

### Option: Git worktree isolation for Codex execution
**Pros:** Full rollback on failure (delete worktree), no risk to main working tree, parallel execution safe
**Cons:** Adds setup/teardown overhead (~2-5s), merging worktree changes back requires git operations
**Verdict:** selected — GSD already uses worktrees for agent isolation. Codex runs in a worktree, results merged on success, discarded on failure

### Option: Replace GSD executor subagents with Codex for all auto tasks
**Pros:** Massive Claude token savings (executor agents are the biggest single consumer), Codex is cheaper per token, offloads work to a different billing model
**Cons:** Codex can't handle checkpoints or interactive decisions, loses Claude's multi-file reasoning for complex tasks, adds OpenAI API dependency
**Verdict:** selected with routing — use Codex for Codex-safe tasks only, keep Claude executor for checkpoint tasks and complex multi-file work. Router classifies at plan time, not runtime

### Option: Codex for verification (replace /gsd-codex-verify)
**Pros:** Already proven pattern, Codex reviews Claude's work effectively, cheaper than Claude self-review
**Cons:** Current /gsd-codex-verify already works well, refactoring adds risk for marginal gain
**Verdict:** deferred — keep existing verification skills, focus new work on execution handoff which has higher token savings potential

---

## Recommendations

- **Build a task router** that classifies GSD plan tasks as `codex-safe` or `claude-required` based on task type, checkpoint presence, and scope. Router runs at plan-read time, tagging each task. Classification rules: `type="auto"` without checkpoints → Codex-safe. Any `checkpoint:*` → Claude-required. TDD plans → Codex-safe. Tasks touching >5 files or with vague acceptance criteria → Claude-required.

- **Define a context capsule format** (`task-capsule.md`) that contains: task name, action, file scope, acceptance criteria, deviation rules, commit message template, and any relevant file content. Pipe to Codex via stdin. Keep it under 16KB for optimal Codex performance.

- **Define a result schema** (`task-result.schema.json`) for `--output-schema`: `{status: "complete"|"failed"|"checkpoint", files_changed: string[], tests_passed: boolean, deviations: string[], commit_hash: string|null}`. Parse this to determine success/failure and update GSD state.

- **Run Codex in git worktrees** for full isolation. On success: merge worktree branch into main working tree. On failure: delete worktree, log failure, fall back to Claude executor for that task.

- **Extract Codex token usage from JSONL** output during execution. Parse `turn.completed` events for `{input_tokens, output_tokens, cached_input_tokens, reasoning_tokens}`. Write to the token-ledger SQLite alongside Claude usage data. Tag entries with `provider: "codex"` for unified cost analysis.

- **Start with the highest-value handoff:** GSD executor `type="auto"` tasks during `/gsd:execute-phase`. These are the biggest Claude token consumers and the most mechanically Codex-safe. Don't try to hand off research, planning, or verification initially.

---

## Open Questions

- What's the actual token cost comparison? A typical GSD auto task consumes ~X Claude tokens via executor subagent — how does the equivalent Codex execution compare in tokens and wall-clock time?
- Should the task router be a static classifier (rules-based on task XML) or dynamic (inspect file complexity, test suite state)?
- How should Codex failures cascade? If Codex fails a task, does Claude retry it immediately, or does the failure get logged and the user decides?
- Can Codex's AGENTS.md fallback to CLAUDE.md cause conflicts? The config already has `project_doc_fallback_filenames = ["CLAUDE.md"]` — but CLAUDE.md has Claude-specific instructions that may confuse Codex
- What's the right timeout per task type? Current default is 300s — some auto tasks complete in 30s, complex ones may need 600s+
- Should the context capsule include raw file content (so Codex doesn't re-read) or just paths (so Codex reads current state)?

---

## Sources

- Codex CLI v0.106.0 help output (`codex --help`, `codex exec --help`)
- [Non-interactive mode docs](https://developers.openai.com/codex/noninteractive)
- [CLI reference](https://developers.openai.com/codex/cli/reference)
- [Sandboxing docs](https://developers.openai.com/codex/concepts/sandboxing)
- [AGENTS.md guide](https://developers.openai.com/codex/guides/agents-md)
- [Best practices](https://developers.openai.com/codex/learn/best-practices)
- [Config reference](https://developers.openai.com/codex/config-reference)
- `/home/agent/.claude/skills/codex-review/SKILL.md` — existing review handoff pattern
- `/home/agent/.claude/skills/gsd-codex-verify/SKILL.md` — existing dual-tool verification pattern
- `/home/agent/.claude/skills/gsd-drive/drive-workflow.md` — GSD drive state machine and dispatch
- `/home/agent/.codex/config.toml` — local Codex configuration
- GSD executor agent definition and PLAN.md template format
