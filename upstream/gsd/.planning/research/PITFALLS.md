# Pitfalls Research

**Domain:** Autonomous Claude Code orchestration daemon (session lifecycle, context management, human-in-the-loop escalation)
**Researched:** 2026-03-09
**Confidence:** MEDIUM-HIGH (domain-specific patterns verified across multiple sources; some Claude Code CLI behaviors verified against official docs)

## Critical Pitfalls

### Pitfall 1: Context Window Death Spiral

**What goes wrong:**
The runner fails to checkpoint and restart sessions before the context window fills. Claude Code hits "Prompt too long" and the session becomes permanently unusable -- every subsequent input returns the same error. The daemon is stuck with a dead session and no recovery path.

**Why it happens:**
Claude Code's auto-compact triggers at ~78% context usage, but this is unreliable for automation. The auto-compact setting (`autoCompact: false`) is documented as being ignored -- compaction triggers anyway at ~78%. There is no clean programmatic signal for "context is getting full" -- the StatusLine mechanism provides a `remaining_percentage` field but it includes a hidden ~40K token autocompact buffer that is not actually usable. Developers assume the 200K context window is more headroom than it is, but system prompt + CLAUDE.md + tool definitions consume a significant chunk upfront.

**How to avoid:**
- Use `--max-turns` to cap each session invocation (e.g., 50-100 turns), then checkpoint and restart regardless of context usage. Turns are the reliable proxy; percentage monitoring is fragile.
- Design the daemon to treat every session as disposable. Each invocation of `claude -p` should be a fresh session that reads state from disk (STATE.md, PLAN.md), does bounded work, writes state back.
- Never rely on `--resume` or `--continue` for the main automation loop. These are recovery tools, not primary architecture. Fresh sessions with disk-persisted state are the correct pattern.
- Implement a "Ralph loop" pattern: small tasks, fresh agents, write outputs before moving on.

**Warning signs:**
- Sessions running for more than 30-40 minutes without restart
- Increasing latency in Claude Code responses (a sign of context bloat)
- Auto-compact warnings appearing in output
- Any occurrence of "Prompt too long" in stderr/stdout

**Phase to address:**
Phase 1 (Runner Core) -- this is foundational. The session lifecycle model must be designed around bounded, disposable sessions from day one.

---

### Pitfall 2: Infinite Loop / Stuck Agent

**What goes wrong:**
Claude Code enters a loop where it repeatedly attempts the same failing action: running the same test that fails, applying the same fix that does not work, or retrying the same command. The daemon burns API credits and time while making zero progress. In autonomous mode with no human watching, this can run for hours.

**Why it happens:**
LLMs lack failure memory across turns within a conversation -- they do not naturally track "I tried X three times and it failed." When a tool call fails, the model retries with the same or trivially different approach. The agent does not understand the error, or the error is ambiguous (e.g., a flaky test), or the fix requires domain knowledge the model lacks. This is called "Loop Drift" -- the agent misinterprets termination signals or generates repetitive actions.

**How to avoid:**
- Implement turn-based loop detection in the runner: track the last N tool calls and their results. If similarity exceeds a threshold (e.g., same command run 3+ times), force-terminate the session.
- Use `--max-turns` as a hard ceiling per invocation. When max-turns is reached, Claude Code exits with an error -- the runner should treat this as "task not completed in budget" and escalate.
- Design the GSD phase loop so each `claude -p` invocation has a narrow, bounded task ("execute wave 1 of the plan") rather than open-ended work ("implement the feature").
- When a session exits without completing its task, escalate to Telegram rather than blindly retrying.

**Warning signs:**
- Same git diff appearing and being reverted multiple times
- Test output repeating the same failures across turns
- `--max-turns` limit being hit regularly on tasks that should be quick
- API costs spiking for a single phase

**Phase to address:**
Phase 1 (Runner Core) for `--max-turns` ceiling and basic loop detection. Phase 2 (Telegram Integration) for escalation on stuck detection.

---

### Pitfall 3: State Corruption on Session Restart

**What goes wrong:**
The runner checkpoints state (via `/gsd:pause-work`), kills the session, and starts a new one -- but the new session reads stale or partially-written state files. The new Claude Code instance misinterprets where it is in the workflow, re-does completed work, skips incomplete work, or corrupts STATE.md by writing conflicting state.

**Why it happens:**
The gap between "Claude finished writing to disk" and "the runner reads that output" is a race condition. Claude Code's `-p` mode returns output to stdout, but file writes (STATE.md, PLAN.md) happen via tool calls during the session -- they may or may not have completed before the session exits. Additionally, if a session crashes (exit code 1) mid-task, files may be partially written.

**How to avoid:**
- After each `claude -p` invocation, validate state files before starting the next session. Parse STATE.md and verify it is well-formed and internally consistent.
- Use the JSON output format (`--output-format json`) to get structured results including success/failure status and session ID -- do not rely on text parsing.
- Implement a state validation step in the runner: read STATE.md, verify the current phase/wave matches expectations, verify PLAN.md exists if expected.
- Design state transitions to be idempotent: if the new session re-reads STATE.md and sees "phase 3, wave 2 in progress," it should be safe to restart wave 2 from scratch without side effects.

**Warning signs:**
- STATE.md showing a phase/wave that does not match the runner's expectation
- Git log showing the same files being modified in consecutive sessions without progress
- New sessions starting with "I see we are on phase X" when the runner expected phase Y
- Truncated or malformed STATE.md after a session crash

**Phase to address:**
Phase 1 (Runner Core) -- state validation must be part of the session restart loop.

---

### Pitfall 4: Telegram Approval Deadlock

**What goes wrong:**
The daemon sends an approval request to Telegram and blocks waiting for a response. The user does not respond (asleep, busy, phone off). The daemon sits idle indefinitely, holding no session but also making no progress. Alternatively, the user responds but the Telegram bridge drops the callback, and the daemon never receives the approval.

**Why it happens:**
Human-in-the-loop approval is inherently asynchronous and unreliable. Network issues, Telegram API outages, bot webhook failures, and simple human unavailability all create scenarios where the daemon blocks forever. Most implementations treat approval as a synchronous blocking call, which is fundamentally wrong for a system that should be resilient.

**How to avoid:**
- Implement approval timeouts with configurable duration (e.g., 4 hours default). On timeout, either auto-reject (safe default) or escalate with a reminder.
- Store pending approvals in a persistent file (not just in-memory). If the daemon restarts, it should be able to re-check for pending approvals.
- Implement retry logic for Telegram message delivery: if the approval request fails to send, retry with exponential backoff, then log an error.
- Design the approval flow as: send request -> write "awaiting approval" to state file -> poll for response on an interval -> timeout after threshold. The daemon process itself should not block.
- Include a "re-send" button on Telegram so users can request the approval message again if they missed it.

**Warning signs:**
- Daemon idle for more than the configured timeout without any activity
- Telegram messages showing as "sent" but no callback received
- User reporting they never received the approval request
- Multiple approval requests stacking up without responses

**Phase to address:**
Phase 2 (Telegram Integration) -- approval flow must be designed with timeouts and persistence from the start.

---

### Pitfall 5: Compounding Error Across Phases

**What goes wrong:**
Claude Code completes Phase 1 with a subtle architectural mistake (wrong database schema, incorrect API contract, bad file structure). The autonomous runner advances to Phase 2, which builds on the mistake. By Phase 3, the codebase is deeply committed to the wrong approach. The human only reviews at gate checkpoints and misses the early mistake because verification is superficial.

**Why it happens:**
In autonomous execution, each phase treats the previous phase's output as ground truth. The LLM does not question earlier decisions -- it works within them. GSD's verify-work step can catch obvious issues (tests failing, lint errors) but cannot catch architectural mistakes that only become apparent later. The "Ralph loop" problem: fresh agents start with a clean slate but inherit the codebase as-is.

**How to avoid:**
- Make GSD verification gates meaningful: require the verify-work step to include architectural review, not just "do tests pass."
- Use the `--append-system-prompt` flag to inject phase-specific verification criteria: "Before proceeding, verify that [specific architectural decision] from Phase 1 is correct."
- Design the roadmap so that early phases produce outputs that are independently testable and reversible. Avoid phases that create deep dependencies before human review.
- At each gate, present the human reviewer with a concise diff summary and specific questions, not just "approve/reject."
- Consider requiring human approval after Phase 1 (the foundation) even if other gates are auto-approved.

**Warning signs:**
- Verification passing with only "all tests pass" -- no architectural review
- Phase N making significant refactors to Phase N-1 outputs (sign the foundation was wrong)
- Increasing phase execution time (fighting against earlier mistakes)
- Code review at gates showing patterns the human did not expect

**Phase to address:**
Phase 1 (Runner Core) for verification gate design. Phase 3 (GSD Integration) for meaningful verification criteria injection.

---

### Pitfall 6: Permission and Safety Bypass in Autonomous Mode

**What goes wrong:**
Running Claude Code with `--dangerously-skip-permissions` (required for autonomous operation) gives it unrestricted access to the filesystem, shell, and network. A coding mistake in a GSD phase could result in destructive operations: `rm -rf`, overwriting critical config files, making unintended API calls, or modifying files outside the project directory.

**Why it happens:**
Autonomous operation requires skipping permission prompts -- there is no human to click "allow." But this means every tool call executes without review. Claude Code's default safety mechanisms (permission prompts) are the primary guardrail, and they are disabled. The runner has no compensating controls.

**How to avoid:**
- Use `--allowedTools` to restrict which tools Claude Code can use per phase. During planning phases, disable `Bash` entirely and allow only `Read`, `Glob`, `Grep`. During execution, allow `Bash` but with restricted patterns.
- Use `--permission-mode plan` with `--allow-dangerously-skip-permissions` as a middle ground where available.
- Run the daemon in a containerized environment or restricted user account so filesystem damage is bounded.
- Implement a pre-commit hook or git worktree (`--worktree` flag) so all changes happen in an isolated branch that can be reviewed before merging.
- Use `--disallowedTools` to block tools that should never be used autonomously (e.g., tools that make external API calls).
- Monitor git diffs between sessions. If a session produces unexpected file changes outside the project directory, halt and escalate.

**Warning signs:**
- Files modified outside the project directory
- Unexpected network calls in process logs
- Git diff showing deletions of files that should not be touched
- Session producing changes to system configuration files

**Phase to address:**
Phase 1 (Runner Core) -- tool restrictions and safety boundaries must be established before any autonomous execution.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Parsing Claude Code text output instead of using `--output-format json` | Faster to implement, no JSON parsing needed | Breaks on output format changes, unreliable extraction of session IDs and success/failure | Never -- JSON output is trivial to implement and vastly more reliable |
| Using `--continue` instead of explicit `--resume <session-id>` | Simpler code, no session ID tracking | `--continue` picks up the most recent session in the directory, which may not be the right one if multiple sessions exist | Only in v1 single-project mode, but track session IDs from the start |
| Storing state only in GSD files (STATE.md, PLAN.md) without runner-level state | Fewer files to manage, trust GSD primitives | Runner cannot distinguish between "session completed successfully" and "session crashed" -- both leave the same files on disk | Never -- runner needs its own state file (e.g., `RUNNER.json`) tracking session history, last exit code, retry count |
| Hardcoding Telegram chat ID and bot token | Faster initial setup | Cannot change notification target without code change, credentials in source | Only for initial prototype, move to env vars immediately |
| Skipping session ID capture from JSON output | Simpler invocation flow | Cannot resume crashed sessions, cannot fork sessions for debugging, lose traceability | Never -- always capture and log session IDs |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Claude Code CLI (`-p` mode) | Assuming exit code 0 means task was completed successfully. Exit code 0 means the process ran without errors, not that Claude accomplished the goal. | Parse JSON output to check the actual response content. Verify state files reflect expected changes. |
| Claude Code CLI (`--max-turns`) | Setting max-turns too high (500+) hoping to "let it finish." This just delays context overflow. | Set conservative max-turns (50-100), checkpoint, restart. Treat max-turns as a budget, not a limit. |
| Claude Code CLI (`--resume`) | Using `--resume` as the primary session continuation strategy. Resume loads full conversation history, which approaches context limits faster. | Use fresh sessions (`-p`) with disk-persisted state. Reserve `--resume` for crash recovery only. |
| Telegram Bot API | Sending inline keyboard buttons and assuming the callback arrives reliably. Telegram callbacks can be lost, duplicated, or arrive out of order. | Implement idempotent callback handling. Store expected callback ID, deduplicate on receipt, timeout on non-receipt. |
| Telegram Bot API | Not handling `callback_query` acknowledgment. Telegram shows a loading spinner on the button until the bot calls `answerCallbackQuery`. | Always call `answerCallbackQuery` immediately on receipt, then process the approval asynchronously. |
| GSD State Files | Reading STATE.md and assuming it is always in a valid state. Crashed sessions may leave partially written files. | Validate STATE.md structure before trusting its content. If invalid, restore from git (last known good commit). |
| Git operations | Letting Claude Code commit directly to the main branch in autonomous mode. | Use `--worktree` or a dedicated branch. The runner should merge to main only after human approval at gates. |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Resuming sessions instead of starting fresh | Response latency increasing over time, compaction warnings, eventual "Prompt too long" | Fresh sessions with `--max-turns` budget per invocation | After 5-10 resumes, context is dominated by history |
| Not setting `--max-budget-usd` | A stuck loop or complex phase burns $20+ in API calls without producing useful output | Set per-invocation budget limit (e.g., $2-5) alongside max-turns | Any infinite loop or unexpectedly complex task |
| Large file reads filling context | Claude reads a large file (1000+ lines) that consumes significant context, leaving little room for reasoning | Use `--append-system-prompt` to instruct "read only relevant sections, use Grep before Read" | Files over ~500 lines being read in full |
| Polling Telegram too frequently | Unnecessary API calls to Telegram, potential rate limiting | Use webhook-based callbacks (not polling) for approval responses. Poll at reasonable intervals (30s+) only as fallback. | Not a scale issue but an efficiency and rate-limit issue |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Storing Telegram bot token in runner script or config file committed to git | Token exposure enables bot hijacking, sending messages as the bot | Use environment variables or a secrets manager. Add config files to `.gitignore`. |
| Running Claude Code as root or with broad filesystem access | Autonomous agent could modify system files, install packages, or access credentials | Run as a restricted user. Use filesystem sandboxing. Mount only the project directory. |
| Not restricting Claude Code's network access | Autonomous agent could make HTTP requests to external services, exfiltrate code, or interact with APIs | Use `--allowedTools` to restrict `Bash` commands. Consider network-level restrictions (firewall rules). |
| Exposing the Telegram approval flow to the wrong chat/user | Unauthorized users could approve destructive operations | Validate Telegram user ID on every callback, not just chat ID. Implement an allowlist of authorized approvers. |
| Passing sensitive data (API keys, passwords) through Claude Code prompts | Data appears in conversation history, potentially in logs or Anthropic's systems | Never inject secrets into prompts. Use environment variables that Claude Code reads via `Bash(echo $VAR)` at runtime. |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Sending raw Claude Code output to Telegram | User receives walls of text, code blocks, and technical detail they cannot parse on mobile | Summarize: "Phase 3 complete. 4 files changed, all tests pass. [Approve] [Reject]" with a link to the full diff. |
| No progress updates between gates | User has no idea if the daemon is working, stuck, or crashed | Send periodic status updates: "Working on Phase 2, Wave 3/5. Estimated 10 min remaining." |
| Approve/reject with no context | User cannot make an informed decision from a button alone | Include a 3-5 line summary of what was done and what approval means (e.g., "Approving will merge these changes and start Phase 4"). |
| No way to pause or cancel from Telegram | User sees something going wrong but cannot stop it without SSH access | Add [Pause] and [Cancel] buttons alongside [Approve] and [Reject] at every status update. |
| Silent failures -- daemon crashes without notification | User assumes work is progressing, checks hours later to find nothing happened | Implement a heartbeat: if no Telegram message sent for N minutes, send a "still alive" or "daemon stopped" notification. |

## "Looks Done But Isn't" Checklist

- [ ] **Session restart:** Often missing state validation -- verify STATE.md is well-formed and phase matches expectations before launching new session
- [ ] **Telegram approval:** Often missing timeout handling -- verify that pending approvals expire and the daemon does not block forever
- [ ] **Loop detection:** Often missing exit-on-stuck -- verify that repeated failures trigger escalation, not infinite retry
- [ ] **GSD verify-work:** Often missing architectural review -- verify that verification checks more than "tests pass" (e.g., file structure, API contracts)
- [ ] **Error handling:** Often missing crash notification -- verify that daemon crash sends a Telegram message before exiting
- [ ] **Context management:** Often missing per-invocation turn limits -- verify `--max-turns` is set on every `claude -p` call
- [ ] **Git safety:** Often missing branch isolation -- verify autonomous changes happen on a branch, not main
- [ ] **Cost control:** Often missing budget limits -- verify `--max-budget-usd` is set on every `claude -p` call

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Context window death (Prompt too long) | LOW | Kill session, start fresh. State is on disk. No data lost if checkpointing is working. |
| Infinite loop (stuck agent) | LOW-MEDIUM | Kill session, inspect git log for what was attempted. Escalate to human with context of what failed. Human unblocks, daemon resumes. |
| State corruption | MEDIUM | Restore STATE.md and PLAN.md from last git commit. Re-run the interrupted phase from the last known good state. |
| Telegram approval deadlock | LOW | Timeout fires, daemon logs the timeout and either auto-rejects or sends a reminder. Human approves when available. |
| Compounding architectural error | HIGH | Revert to the phase where the mistake was introduced. Re-plan from that phase. All subsequent phases are wasted work. This is the most expensive failure mode. |
| Permission bypass damage | HIGH | Restore from git. If damage is outside git (system files), restore from backup. Audit what was modified. |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Context window death spiral | Phase 1: Runner Core | Every `claude -p` call uses `--max-turns`. No session runs unbounded. |
| Infinite loop / stuck agent | Phase 1: Runner Core + Phase 2: Telegram | Runner detects repeated failures. Telegram receives escalation on stuck detection. |
| State corruption on restart | Phase 1: Runner Core | Runner validates STATE.md between sessions. Invalid state triggers recovery, not blind continuation. |
| Telegram approval deadlock | Phase 2: Telegram Integration | Approval requests have timeouts. Pending approvals persist across daemon restarts. |
| Compounding error across phases | Phase 3: GSD Integration | Verification gates include architectural criteria, not just test results. Phase 1 outputs require human review. |
| Permission/safety bypass | Phase 1: Runner Core | `--allowedTools` and `--disallowedTools` configured per phase type. Changes isolated to branch. |

## Sources

- [Claude Code CLI Reference (official)](https://code.claude.com/docs/en/cli-reference) -- HIGH confidence, verified flags and behaviors
- [Claude Code Best Practices (official)](https://code.claude.com/docs/en/best-practices) -- HIGH confidence
- [Context Windows (Anthropic API docs)](https://platform.claude.com/docs/en/build-with-claude/context-windows) -- HIGH confidence
- [Context Loss Session Manager (DEV Community)](https://dev.to/kaz123/how-i-solved-claude-codes-context-loss-problem-with-a-lightweight-session-manager-265d) -- MEDIUM confidence
- [Persistent Session Context Issue #12990 (GitHub)](https://github.com/anthropics/claude-code/issues/12990) -- MEDIUM confidence, documents real user pain
- [Prompt Too Long Issue #22013 (GitHub)](https://github.com/anthropics/claude-code/issues/22013) -- MEDIUM confidence, documents session death behavior
- [AutoCompact Ignored Issue #18264 (GitHub)](https://github.com/anthropics/claude-code/issues/18264) -- MEDIUM confidence, documents unreliable auto-compact
- [Why Agents Get Stuck in Loops (gantz.ai)](https://gantz.ai/blog/post/agent-loops/) -- MEDIUM confidence, pattern analysis
- [Agent Stuck Detection from 220 Loops (DEV Community)](https://dev.to/boucle2026/how-to-tell-if-your-ai-agent-is-stuck-with-real-data-from-220-loops-4d4h) -- MEDIUM confidence
- [Ralph Loop Autonomous Agents (wisdomai.com)](https://www.wisdomai.com/insights/matthew_berman/ralph-loop-autonomous-agents-ai-coding-context-window-ffdd1834) -- MEDIUM confidence, architecture pattern
- [Building AI Agents That Wait for Humans (Microsoft)](https://techcommunity.microsoft.com/blog/azure-ai-foundry-blog/building-ai-agents-that-wait-for-humans/4496310) -- MEDIUM confidence, approval patterns
- [Human-in-the-Loop (Temporal)](https://docs.temporal.io/ai-cookbook/human-in-the-loop-python) -- MEDIUM confidence, timeout and persistence patterns
- [AI Agent Orchestration Patterns (Azure)](https://learn.microsoft.com/en-us/azure/architecture/ai-ml/guide/ai-agent-design-patterns) -- MEDIUM confidence

---
*Pitfalls research for: GSD Autonomous Runner (Claude Code orchestration daemon)*
*Researched: 2026-03-09*
