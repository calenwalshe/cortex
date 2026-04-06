# External Research: AI Coding Tools + GitHub Platform Integration

**Slug:** github-platform  
**Date:** 2026-04-07  
**Scope:** How production AI coding tools integrate with GitHub for autonomous PR creation, CI management, review feedback, and merge safety  

---

## Track 1: Tool-by-Tool Analysis

### 1.1 Devin AI (Cognition)

**Source:** [Devin GitHub Docs](https://docs.devin.ai/integrations/gh), [Devin Autofix Blog](https://cognition.ai/blog/closing-the-agent-loop-devin-autofixes-review-comments), [DataCamp Tutorial](https://www.datacamp.com/tutorial/devin-ai)

**PR Creation:**
- Installs as a GitHub App with read/write on contents, PRs, issues, checks, commit statuses, workflows
- Permissions are organization-level, not per-user
- Uses repository PR templates, searching in order: `PULL_REQUEST_TEMPLATE/devin_pr_template.md`, `docs/PULL_REQUEST_TEMPLATE/`, `.github/PULL_REQUEST_TEMPLATE/`, then standard locations
- Falls back to "default PR description format" if no template found
- No documented branch naming convention (Devin chooses its own)

**CI Handling:**
- Has read/write access to checks and commit statuses
- Can "view the actions configured for a repository"
- Autofix feature: when GitHub bots, linters, CI pipelines, or security scanners leave PR comments, Devin automatically resolves them and pushes fixes
- The loop: "The agent writes. The reviewer catches. Bot triggers fire. Fixes get applied automatically. CI runs clean. The PR is ready for human review."
- Configurable via Settings > Customization > Autofix — select which bots trigger auto-response

**Merge / Safety:**
- Docs recommend "enabling branch protection rules on your main branch"
- Human retains merge authority — nothing reaches production without explicit approval
- PR merge rate improved from 34% to 67% over 2025 — one-third still need significant rework
- Automatically responds to PR review comments as long as session is not archived

**What Cortex can steal:**
- PR template hierarchy search (Devin-specific → repo standard → default)
- Autofix loop concept: ship → CI/review bot catches → auto-fix → re-push → CI passes → human reviews
- Organization-level permissions (not per-user) simplifies auth model

---

### 1.2 GitHub Copilot Coding Agent

**Source:** [GitHub Docs — Asking Copilot to Create PR](https://docs.github.com/copilot/using-github-copilot/coding-agent/asking-copilot-to-create-a-pull-request), [VS Code Docs](https://code.visualstudio.com/docs/copilot/copilot-coding-agent), [GitHub Risks & Mitigations](https://docs.github.com/en/copilot/concepts/agents/coding-agent/risks-and-mitigations), [Branch Naming Changelog](https://github.blog/changelog/2025-10-16-copilot-coding-agent-uses-better-branch-names-and-pull-request-titles/), [Firewall Settings](https://docs.github.com/copilot/customizing-copilot/customizing-or-disabling-the-firewall-for-copilot-coding-agent), [PR Templates Changelog](https://github.blog/changelog/2025-11-05-copilot-coding-agent-now-supports-pull-request-templates/)

**PR Creation:**
- Creates an **initial empty commit** immediately to establish the PR and working branch — this is by design
- Pushes subsequent commits with actual code as it works
- Branch naming: `copilot/` prefix mandatory (e.g., `copilot/fix-bb8a875d-...`); improved in Oct 2025 to use descriptive names
- Agent can ONLY push to branches beginning with `copilot/`
- Creates exactly one PR per assigned task
- Cannot work on PRs it didn't create
- Supports PR templates as of Nov 2025
- PR body includes "detailed description explaining the implementation" plus screenshots for UI changes

**CI Handling:**
- Runs in GitHub Actions environment (GitHub's cloud infrastructure)
- Can run builds, tests, linters, and other automated checks
- CodeQL security analysis runs automatically on generated code
- Dependencies checked against GitHub Advisory Database (malware, CVSS High/Critical)
- Secret scanning detects API keys and tokens in generated code
- **Known issue:** Pre-commit verification scripts >3-6 minutes cause agent timeout → infinite retry loop

**Merge / Safety:**
- **Cannot** mark PRs ready for review, approve, or merge — hard restriction
- Draft PRs must be reviewed and merged by a human
- Commits authored by Copilot with developer as co-author (traceability)
- Commits are cryptographically signed (show "Verified" on GitHub)
- Commit messages include links to agent session logs
- GitHub Actions workflows blocked by default until human approval via "Approve and run workflows"
- Requester cannot approve their own PRs

**Firewall / Network Safety:**
- Built-in agent firewall enabled by default
- Recommended allowlist restricts internet access
- Org admins can turn firewall on/off, customize allowlist per-repo
- **Limitation:** Firewall only applies to Bash tool processes, NOT to MCP servers or setup steps
- "Sophisticated attacks may bypass the firewall" — not a comprehensive security solution
- Hidden characters filtered from user input before passing to agent (prompt injection mitigation)

**What Cortex can steal:**
- Empty commit → PR → push pattern (establishes workspace instantly, humans can watch progress)
- `copilot/` prefix restriction (agent can only write to its own namespace)
- Signed commits for traceability
- Firewall concept — restrict agent network access during execution
- CodeQL + Advisory Database + secret scanning as automated validation layers
- Session log links in commit messages (audit trail)

---

### 1.3 OpenAI Codex

**Source:** [Codex GitHub Integration](https://developers.openai.com/codex/integrations/github), [Codex GitHub Action](https://developers.openai.com/codex/github-action), [Introducing Codex](https://openai.com/index/introducing-codex/)

**PR Creation:**
- Each task runs in its own cloud sandbox, preloaded with the repository
- Can propose pull requests for review
- `openai/codex-action@v1` GitHub Action for CI/CD integration
- Comment `@codex review` on PRs to trigger code review
- Automatic review mode available (triggers on all new PRs)

**CI Handling:**
- Reacts with emoji (eyes) when review triggered
- Posts reviews as standard GitHub code review comments
- Flags P0 and P1 severity issues by default
- Reads `AGENTS.md` files for repository-specific review guidelines (searches directory hierarchy)
- Supports `@codex fix the CI failures` comments to trigger cloud tasks using PR as context

**Merge / Safety:**
- No auto-merge documented
- AGENTS.md hierarchy for per-directory customization (like Cursor's `.cursorrules`)

**What Cortex can steal:**
- `AGENTS.md` hierarchy concept — per-directory instructions for the AI agent
- Review severity classification (P0/P1 only by default — focus on critical issues)
- `@codex fix the CI failures` pattern — comments that trigger specific agent actions

---

### 1.4 Claude Code + claude-code-action

**Source:** [claude-code-action GitHub](https://github.com/anthropics/claude-code-action), [Claude Code GitHub Actions Docs](https://code.claude.com/docs/en/github-actions), [commit-push-pr command](https://github.com/anthropics/claude-code/blob/main/.claude/commands/commit-push-pr.md), [Anthropic — Effective Harnesses](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)

**PR Creation:**
- `/commit-push-pr` command: creates branch (if on main), stages, commits, pushes, opens PR via `gh pr create`
- Branch convention: `claude/[feature]-[session-id]` with `claude/` prefix
- PR description uses HEREDOC for formatting: Summary (1-3 bullets) + Test Plan checklist
- Customizable via CLAUDE.md instructions (define what a good PR looks like for your project)
- `anthropics/claude-code-action@v1` for GitHub Actions integration (launched Sep 2025 with Claude Code 2.0)

**CI Handling:**
- **Known issue:** Agent loops endlessly watching CI checks on already-merged PRs (GitHub issue #17416)
- `gh pr checks --watch` with repeated 5-minute timeouts observed
- Uses `gh` CLI for all GitHub operations
- Structured JSON outputs become GitHub Action outputs for downstream automation

**Merge / Safety:**
- No automatic merging — all changes are reviewable
- Intelligent mode detection: Interactive (@claude mentions), Assignment (issue assignment), Automation (explicit prompts)
- Commit signing support
- Network restrictions (experimental)
- Required permissions: PR/Issue read, repository read, write for commits/PR updates

**Long-Running Agent Harness (Anthropic Engineering):**
- Two-agent system: Initializer (setup) + Coding Agent (incremental work)
- `claude-progress.txt` for state tracking across context windows
- `feature_list.json` (JSON preferred over Markdown — model less likely to corrupt structured data)
- One feature at a time → commit → update progress
- Browser automation (Puppeteer MCP) for end-to-end verification
- "It is unacceptable to remove or edit tests" as a hard constraint
- Git revert for recovery from bad changes

**What Cortex can steal:**
- HEREDOC for PR body formatting (already in cortex-ship design)
- Progress file pattern — JSON over Markdown for machine-readable state
- Two-agent harness: initializer sets up environment, coding agent does incremental work
- "Unacceptable to remove tests" as a hard constraint — similar to cortex validator protection
- Known `gh pr checks --watch` issues validate the manual poll fallback in cortex-ship design

---

### 1.5 Aider

**Source:** [Aider Git Docs](https://aider.chat/docs/git.html), [Aider GitHub](https://github.com/Aider-AI/aider)

**PR Creation:**
- Aider itself does NOT create PRs — it commits locally
- GitHub Actions workflow (`aider` label on issue → automated PR) is a community integration
- Every AI edit gets an automatic commit with descriptive message
- Conventional Commits format by default
- Uses `--weak-model` to generate commit messages from diffs + chat history
- Customizable via `--commit-prompt`

**Git Integration (Deep):**
- Pre-commits dirty files before editing (separates human edits from AI edits)
- `/undo` command instantly reverts any AI change
- `/diff` shows changes since last message
- `/commit` creates sensible commit messages for dirty changes
- Attribution: "(aider)" appended to author/committer names
- Options: `--no-attribute-author`, `--no-attribute-committer`, prefix commit messages, Co-authored-by trailers
- Architect/editor workflow: architect model designs, editor model implements

**What Cortex can steal:**
- Pre-commit dirty files before AI edits (protect human work from AI changes)
- Commit attribution model — mark which commits are AI-authored vs human-authored
- Architect/editor split maps well to Cortex's spec → contract → execute pipeline
- Weak model for commit messages — use cheaper model for mechanical tasks

---

### 1.6 Cursor Background Agents

**Source:** [Cursor GitHub Docs](https://cursor.com/docs/integrations/github), [Cursor Background Agents Blog](https://madewithlove.com/blog/using-cursor-background-agents/), [Linear Changelog](https://linear.app/changelog/2025-08-21-cursor-agent)

**PR Creation:**
- Background agents require Cursor GitHub App (read-write privileges for clone + push)
- Works on separate branch → pushes to repo → generates PR with summary
- Branch prefix: `cursor/` (not customizable as of search date)
- Bugbot: searches codebase → identifies problems → generates fix → creates PR linked to issues, "all in under 60 seconds"
- @cursor [prompt] on any PR or issue triggers agent from GitHub

**CI Handling:**
- Agent autonomously handles iterations, testing, linting, formatting
- Can make file changes, run commands, search web for resources
- No documented CI polling pattern

**Merge / Safety:**
- Human reviews PR, tests changes, makes adjustments
- Pre-filled PR redirects to GitHub ready for review
- Linear issue references automatically added to commits and PR descriptions

**What Cortex can steal:**
- Bugbot pattern: scan → identify → fix → PR in one flow (maps to cortex-investigate → repair → ship)
- Linear integration pattern (auto-reference issue trackers in commits)
- `@cursor [prompt]` comment-triggered agent activation

---

### 1.7 LangChain Open SWE

**Source:** [Open SWE GitHub](https://github.com/langchain-ai/open-swe), [Open SWE Blog](https://blog.langchain.com/introducing-open-swe-an-open-source-asynchronous-coding-agent/), [DeepWiki Analysis](https://deepwiki.com/langchain-ai/open-swe/2.3-github-integration), [PR Tagging Docs](https://docs.langchain.com/labs/swe/usage/pr-tagging)

**PR Creation:**
- Four-agent architecture: Manager → Planner → Programmer → Reviewer
- Label-based trigger: `open-swe-auto` label on GitHub issue starts the flow
- Branch naming: `openswe-{thread_id}` — thread ID in branch name enables review feedback routing
- Status updates streamed to issue comments as agent works
- PR opens once quality gates pass (reviewer agent validates first)
- Human approval or auto-approval available for plans

**Review Feedback:**
- `@openswe` in PR comments → routes feedback to existing agent thread (via thread ID extracted from branch name)
- Works on line-by-line review comments AND review body comments
- Pushes fixes to the same branch

**Safety:**
- Daytona sandbox: isolated, disposable VM-like environment per task
- Minimal GitHub OAuth scopes
- Branch protections and required checks prevent unvalidated merges
- LangSmith for behavior auditing and prompt improvement

**What Cortex can steal:**
- Thread ID in branch name for feedback routing — elegant solution for connecting PR comments back to agent state
- Four-agent pipeline with explicit reviewer stage before PR creation
- Sandbox-per-task isolation model
- Label-based trigger mechanism (issue label → agent starts → PR created)
- Plan approval gate between planning and execution

---

### 1.8 Amazon Q Developer

**Source:** [Amazon Q GitHub Docs](https://docs.aws.amazon.com/amazonq/latest/qdeveloper-ug/amazon-q-for-github.html), [AWS Blog](https://aws.amazon.com/blogs/aws/amazon-q-developer-in-github-now-in-preview-with-code-generation-review-and-legacy-transformation-capabilities/)

**PR Creation:**
- Feature development label on issue triggers agent → creates PR with changes and summary
- Agents automatically run PR workflows during code generation
- Iterates on failures until build pipeline passes
- Developers collaborate via PR comments; Q responds with improvements

**CI Handling:**
- January 2025 enhancement: agent iterates on CI failures until build passes
- GitHub workflows trigger agent using pull-request labels
- Enables "unattended fixes overnight"

**Merge / Safety:**
- Automatic code review on PR creation / reopen
- Generates fixes for identified issues (reviewable before commit)
- Free tier with limited invocations

**What Cortex can steal:**
- "Iterate on CI failures until build passes" — aggressive auto-repair pattern (contrast with cortex-ship's conservative 1-retry default)
- Label-triggered workflows for unattended operation
- Overnight/batch processing model

---

## Track 2: CI Status Polling Patterns

### 2.1 `gh pr checks --watch` (Native)

**Source:** [gh CLI Manual](https://cli.github.com/manual/gh_pr_checks), [gh-observer](https://www.chicks.net/posts/2026-03-08-announce-gh-observer/), [cli/cli Issue #7401](https://github.com/cli/cli/issues/7401)

| Flag | Behavior |
|------|----------|
| `--watch` | Continuous monitoring until all checks complete |
| `--fail-fast` | Exit immediately on first failure |
| `--interval N` | Polling refresh rate, default 10 seconds |
| `--required` | Show only mandatory checks |
| `--json fields` | Structured output with `bucket` field: `pass`, `fail`, `pending`, `skipping`, `cancel` |
| Exit code 8 | Checks still pending |

**Known Issues:**
- GitHub Actions takes 30-90 seconds to queue jobs after PR push — `--watch` during this window sees "no checks reported" and exits with error (exit code 1)
- Race condition: no checks exist yet when polling starts (Issue #7401)
- Claude Code agents observed in infinite retry loops with repeated 5-minute timeouts
- Copilot coding agent timeouts on pre-commit checks >3-6 minutes

**Mitigation strategies:**
1. Sleep 60-90 seconds before first poll (crude but effective)
2. Manual poll loop with explicit "no checks yet" handling
3. Use `gh-observer` CLI extension (polls every 5 seconds, full TUI, queue latency metrics)
4. Use GitHub marketplace action `wait-for-status-checks` for Actions-based polling

**Cortex-ship implication:** The design's manual poll fallback is validated by real-world `--watch` failures across multiple tools. The 30-second interval in the design is reasonable. Adding a 60-second initial delay before first poll would avoid the "no checks yet" race condition.

---

### 2.2 Good To Go (Deterministic PR Readiness)

**Source:** [Good To Go](https://dsifry.github.io/goodtogo/)

Purpose-built tool for AI coding agents that can't reliably determine when a PR is ready to merge.

**Three-dimensional analysis:**
1. **CI Status Aggregation** — Combines check runs + commit statuses into unified pass/fail/pending
2. **Intelligent Comment Classification** — ACTIONABLE / NON_ACTIONABLE / AMBIGUOUS categories; recognizes patterns from CodeRabbit, Greptile, Claude Code, Cursor
3. **Thread Resolution Tracking** — Distinguishes genuinely unresolved discussions from threads addressed in subsequent commits

**Five deterministic statuses:**
- `READY` — merge-safe
- `ACTION_REQUIRED` — comments need fixes
- `UNRESOLVED` — open discussions pending
- `CI_FAILING` — build checks failing
- `ERROR` — data fetch failure

**Agent integration pattern:**
```python
result = subprocess.run(["gtg", pr_number, "--format", "json"], ...)
data = json.loads(result.stdout)
if data["status"] == "READY": merge_pr()
```

**What Cortex can steal:**
- The entire concept. `gtg` solves exactly the problem cortex-ship faces: "is this PR ready?"
- Comment classification model (ACTIONABLE vs NON_ACTIONABLE) for future review-comment ingestion
- State persistence for dismissed comments
- `--refresh` flag for force-recheck
- Consider making `gtg` an optional dependency or building equivalent logic into cortex-ship

---

## Track 3: Autonomous PR Patterns (Cross-Tool Synthesis)

### 3.1 Branch Strategy Consensus

| Tool | Branch Prefix | Naming Convention | Customizable? |
|------|--------------|-------------------|---------------|
| Copilot | `copilot/` | `copilot/fix-{uuid}` → descriptive (Oct 2025) | No |
| Claude Code | `claude/` | `claude/[feature]-[session-id]` | Via CLAUDE.md |
| Cursor | `cursor/` | `cursor/...` | No (requested) |
| Open SWE | `openswe-` | `openswe-{thread_id}` | Via config |
| Devin | (undocumented) | Agent-chosen | Unknown |
| Cortex (proposed) | `cortex/` | `cortex/{slug}` | Via slug naming |

**Pattern:** Every tool uses a tool-specific prefix. This prevents branch collisions and makes it immediately clear which branches are agent-created. Cortex's `cortex/{slug}` aligns perfectly.

### 3.2 PR Description Patterns

| Tool | Description Source | Structured Sections |
|------|-------------------|-------------------|
| Copilot | Agent-generated from task context | Implementation summary + screenshots |
| Claude Code | Commits + CLAUDE.md template | Summary + Test Plan |
| Devin | Repo PR template (searched hierarchy) | Template-driven |
| Open SWE | Agent + quality gates | Plan summary + changes |
| Cortex (proposed) | Spec + contract + commits + eval | Summary + Changes + Test Plan + Metadata |

**Cortex advantage:** Cortex's proposed PR template is the most information-dense. No other tool pulls from a spec, contract, validator results, AND eval scores. This is a genuine differentiator.

### 3.3 The Empty Commit Pattern

Copilot creates an **initial empty commit** to establish the PR immediately. This means:
- Humans can watch progress in real-time (subsequent commits appear on the PR)
- The PR URL exists before any code is written
- Enables early feedback before the agent finishes

**Cortex consideration:** Cortex-ship creates the PR after all code is committed (post-validator). The empty commit pattern doesn't apply because Cortex's execution is complete before shipping. This is a fundamentally different model (batch-ship vs. streaming-ship).

### 3.4 Review Feedback Loops

| Tool | Feedback Mechanism | Auto-Fix? |
|------|-------------------|-----------|
| Devin | Auto-responds to PR comments while session active | Yes (autofix feature) |
| Copilot | `@copilot` in PR comments | Yes (pushes commits) |
| Claude Code | `@claude` in PR comments (via Action) | Yes (implements changes) |
| Cursor | `@cursor` in PR comments | Yes (pushes commits) |
| Open SWE | `@openswe` in PR comments | Yes (same branch) |
| Amazon Q | Direct PR comment collaboration | Yes (iterate until CI passes) |
| Cortex (proposed) | Deferred to v2 | No (v1 stops at PR creation) |

**Every production tool supports review feedback ingestion.** Cortex's v2 plan for this is correct in scope but should be prioritized early — it's a competitive necessity, not a nice-to-have.

---

## Track 4: Safety and Governance

### 4.1 Defense-in-Depth Layers (Synthesized)

Layer 1: **Branch Isolation** — Agent can only push to its own prefixed branches (Copilot enforces this technically; others by convention)

Layer 2: **Draft PR Default** — Several tools open PRs as drafts. Cortex's `--draft` flag supports this.

Layer 3: **Automated Validation** — CodeQL, Advisory Database, secret scanning, linting (Copilot); validator contracts (Cortex); quality gates (Open SWE)

Layer 4: **Human Review Gate** — Universal. Every tool requires human approval before merge. No exceptions found in any production tool.

Layer 5: **Network Restriction** — Copilot's firewall (allowlist-based, org-configurable). Claude Code has experimental network restrictions. Most other tools rely on sandbox isolation.

Layer 6: **Audit Trail** — Signed commits (Copilot), session log links in commits (Copilot), co-author attribution (Claude Code, Aider), ship logs (Cortex)

Layer 7: **Merge Protection** — Branch protection rules, required status checks, required reviews. No tool bypasses these GitHub-native protections.

### 4.2 What No Tool Does (Gaps)

- **No tool auto-merges by default.** Even aggressive tools like Devin and Amazon Q stop at PR creation.
- **No tool detects "this change is too risky for autonomous operation."** Risk classification of generated changes is an open problem.
- **No tool validates architectural consistency** — they check syntax/tests/security but not whether the change fits the system's architecture. Cortex's spec+contract model partially addresses this.
- **No tool implements rollback-on-merge-failure.** If a merged PR causes production issues, manual intervention is required everywhere.

### 4.3 Risk-Tiered Autonomy

**Source:** [Swarmia — Five Levels of AI Agent Autonomy](https://www.swarmia.com/blog/five-levels-ai-agent-autonomy/), [Bunnyshell — Agentic Development](https://www.bunnyshell.com/guides/agentic-development/)

The industry is converging on risk-tiered approaches:
- **Low risk (docs, tests, refactoring):** High autonomy, auto-ship
- **Medium risk (feature implementation):** Auto-ship with review gate
- **High risk (security, infrastructure, data migrations):** Human approval before execution, not just before merge

Cortex's current model is uniformly "auto-ship, human merge." Future consideration: slug complexity classification could gate whether cortex-drive auto-ships or pauses for human approval before PR creation.

---

## Track 5: GitHub Agentic Workflows (Native Platform)

**Source:** [GitHub Blog — Automate Repository Tasks](https://github.blog/ai-and-ml/automate-repository-tasks-with-github-agentic-workflows/), [GitHub — Continuous AI in Practice](https://github.blog/ai-and-ml/generative-ai/continuous-ai-in-practice-what-developers-can-automate-today-with-agentic-ci/), [Awesome Continuous AI](https://github.com/githubnext/awesome-continuous-ai)

**Architecture:**
- Workflow files: `.github/workflows/[name].md` (Markdown instructions) + `.github/workflows/[name].lock.yml` (generated Actions YAML)
- Frontmatter specifies triggers, permissions, tools, safe outputs
- Body is natural language describing desired outcome

**Key Design Principles:**
- Read-only by default; write operations require explicit "safe outputs" approval
- "Pull requests are never merged automatically, and humans must always review and approve"
- Sandboxed execution, tool allowlisting, network isolation
- Designed to augment CI/CD, not replace it
- "The PR is the existing noun where developers expect to review work"

**Six Continuous AI Categories:**
1. Continuous triage (labeling, routing)
2. Continuous documentation
3. Continuous code simplification
4. Continuous test improvement
5. Continuous quality hygiene (CI failure investigation)
6. Continuous reporting

**What Cortex can steal:**
- "Safe outputs" concept — explicitly declare what an agent can produce (issues, PRs, comments)
- "Augment CI/CD, don't replace it" — cortex-ship follows this already
- The six categories as inspiration for future cortex-drive autonomous tasks beyond shipping
- Markdown workflow definition — cortex-drive's decision table is conceptually similar
- Tool allowlisting for execution safety

---

## Track 6: PR Description Generation Best Practices

**Source:** [Graphite — AI-Generated PR Descriptions](https://graphite.com/guides/ai-generated-pr-descriptions), [Hey Sopa — PR Best Practices](https://www.heysopa.com/post/pull-request-best-practices), [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)

**Essential sections (industry consensus):**
1. **Purpose** — Why this change exists
2. **Changes** — What was modified (files, functions)
3. **Impact** — Effects on existing codebase
4. **Testing** — How to verify the changes

**Conventional Commits in PR titles:**
- Format: `type(scope): description`
- Types: feat, fix, docs, style, refactor, test, chore
- Enables automated changelog generation, semantic versioning

**Generation approaches:**
- Analyze diffs + commit messages + PR metadata
- Context from linked issues/tickets
- Per-project customization via templates
- Human review as final step (AI output is starting point)

**Cortex advantage confirmed:** The cortex-ship PR template pulls from spec, contract, validators, and eval scores — richer context than any documented approach. Conventional Commits for the PR title (e.g., `feat(add-retry-logic): exponential backoff for webhook delivery`) would add discoverability.

---

## Summary: What Cortex Should Steal

### High Priority (v1 / cortex-ship)

| Pattern | Source | Application |
|---------|--------|-------------|
| 60-second initial delay before CI poll | `gh pr checks --watch` race condition (cross-tool) | Add sleep before first poll in cortex-ship |
| Manual poll fallback | Claude Code infinite loop bugs, Copilot timeout issues | Already in cortex-ship design — validated |
| `cortex/` branch prefix | Industry consensus (copilot/, claude/, cursor/) | Already in cortex-ship design — validated |
| Conventional Commit PR titles | Industry best practice | Add `type(slug): objective_summary` format |
| Signed commits | Copilot traceability model | `git commit --gpg-sign` if key available |
| Ship log links in commits | Copilot session log pattern | Add ship-log path to PR metadata |
| PR template hierarchy search | Devin template resolution | Check repo's `.github/PULL_REQUEST_TEMPLATE.md` and merge with cortex template |

### Medium Priority (v1.1 / early iteration)

| Pattern | Source | Application |
|---------|--------|-------------|
| Review comment ingestion | Every production tool supports this | `@cortex` in PR comments → route to cortex-investigate |
| Good To Go integration | `gtg` tool | Use `gtg` (or equivalent logic) for PR readiness detection beyond CI |
| Comment classification | Good To Go ACTIONABLE/NON_ACTIONABLE model | Classify review comments before feeding to repair |
| CI autofix loop | Devin, Amazon Q | Increase `ci_repair_count` max if success rate >50% |

### Lower Priority (v2+)

| Pattern | Source | Application |
|---------|--------|-------------|
| Risk-tiered autonomy | Industry convergence | Slug complexity → auto-ship vs human-approval-before-ship |
| Empty commit streaming | Copilot | Real-time PR progress during execution (requires GSD integration) |
| Thread ID in branch | Open SWE | Route PR feedback to correct agent session |
| Safe outputs declaration | GitHub Agentic Workflows | Explicit allow-list of what cortex-ship can produce |
| Network restriction / firewall | Copilot | Restrict execution environment network access |

### Validated Design Decisions

The cortex-ship design (from `design-research-20260407.md`) aligns with industry practice on:

1. **No auto-merge** — Universal across all tools
2. **Human merge gate** — Universal across all tools
3. **`cortex/{slug}` branch naming** — Matches industry pattern
4. **`gh pr create` with HEREDOC** — Same as Claude Code's approach
5. **CI polling with timeout** — Standard approach, but add initial delay
6. **Idempotent re-entry** — Not documented in other tools but is a quality differentiator
7. **Structured PR description from artifacts** — Richer than any competitor
8. **Separate ship phase from close** — Matches the "PR is the checkpoint" philosophy

### Evidence That Would Change Recommendations

- If `gtg` proves unreliable → build equivalent CI+comment aggregation into cortex-ship natively
- If review comment ingestion success rate <30% → deprioritize automated feedback loops
- If signed commits cause friction (GPG key management) → drop to Co-authored-by attribution only
- If Copilot's firewall model proves effective at scale → adopt network restrictions for cortex execution environments
