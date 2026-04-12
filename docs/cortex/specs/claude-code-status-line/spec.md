# Spec: claude-code-status-line

**Slug:** claude-code-status-line
**Timestamp:** 20260410T012000Z
**Status:** draft

---

## 1. Problem

The user's Claude Code status line displays `agent@agent-stack-dev | ? | ? | ctx: 0%` — three fields are broken because `/home/agent/bin/ccstatusline` uses wrong schema assumptions about Claude Code's stdin JSON. The script expects `model` as a string (but Claude Code sends a dict), `cwd` as a top-level field (but it's `workspace.current_dir`), and `context.used` (but it's `context_window.total_input_tokens`). The user perceived this as "missing info" but it's actually broken rendering. Additionally, Cortex signals (active slug, mode, approval status) that would help the user see work state at a glance are not surfaced at all.

---

## 2. Scope

### In Scope

- Rewrite `/home/agent/bin/ccstatusline` with correct Claude Code schema field access
- Add session cost display from `cost.total_cost_usd`
- Add Cortex state section showing `[slug:mode]` when `.cortex/state.json` exists, omitted otherwise
- Add warning marker `⚠` when `mode=execute` but `approvals.contract=false` (anomaly detection)
- Graceful degradation: missing fields render as `?` instead of crashing
- Test before saving: pipe sample JSON through new script and verify output

### Out of Scope

- Replacing ccstatusline with a community tool (claude-statusline, etc.)
- Multi-line status line layouts
- Theming, colors, or ANSI escape codes
- Modifying `settings.json` statusLine config (command reference stays the same)
- Git branch display (already handled elsewhere or not needed per the user's framing)
- Rate limit display
- Worktree indicator

---

## 3. Architecture Decision

**Chosen approach:** Rewrite the existing bash+python script in-place, keeping the same interface (stdin JSON → stdout text) and the same settings.json reference (`"command": "ccstatusline"`). Fix all three broken field accesses, add cost, add a Cortex state section that reads `$CLAUDE_PROJECT_DIR/.cortex/state.json` with existence guards.

**Rationale:** The current script is broken, not wrong-in-direction. The framework (bash wrapper calling python to parse JSON) is sound. Minimal disruption: one file rewrite, no settings.json change, no new dependencies. The Cortex integration is additive and degrades gracefully when state is absent (works in non-Cortex projects too).

### Alternatives Considered

- **Community tool (claude-statusline by felipeelias):** Rejected — requires install, external dependency, doesn't know about Cortex, changes workflow.
- **Multi-line layout:** Deferred — the user wants fixed fields first, not reorganization.
- **Pure bash (drop python):** Rejected — JSON parsing in pure bash is fragile. Python is already there.

---

## 4. Interfaces

- **`/home/agent/bin/ccstatusline`** — Existing script. Rewritten. Owned by user. Read by Claude Code on each status line refresh (currently every 5 seconds per settings.json `refreshInterval`).
- **stdin: Claude Code status line JSON** — Schema documented in Perplexity research finding. Key fields: `model.display_name`, `workspace.current_dir`, `context_window.{total_input_tokens, total_output_tokens, context_window_size}`, `cost.total_cost_usd`.
- **stdout: formatted status line text** — Single line, pipe-separated sections.
- **`$CLAUDE_PROJECT_DIR/.cortex/state.json`** — Read-only. Extract `slug`, `mode`, `approval_status`, `approvals.contract`. Must tolerate missing file (non-Cortex projects).
- **`$CLAUDE_PROJECT_DIR` environment variable** — Provided by Claude Code; fallback to `os.getcwd()` if unset.

---

## 5. Dependencies

- **bash** — script wrapper
- **python3** — JSON parsing (already used by current script)
- **Claude Code** — invokes the script on status line refresh
- **No new packages required** — stdlib `json`, `os`, `sys` only

---

## 6. Risks

- **Script errors will be visible in status line** — Mitigation: guard every field access with `.get()` + defaults. Wrap the whole Python block in try/except that prints a minimal fallback (`ccstatusline error`) rather than crashing silently.
- **Reading `.cortex/state.json` on every refresh (every 5s) adds filesystem I/O** — Mitigation: the file is small (~300 bytes) and already cached by OS page cache. Negligible cost.
- **Cortex state file could be mid-write when read** — Mitigation: wrap JSON parse in try/except; on decode error, just omit the Cortex section for that refresh cycle. The next refresh will succeed.
- **Breaking the status line for non-Cortex projects** — Mitigation: `.cortex/state.json` existence check before reading. If absent, skip the section entirely.

---

## 7. Sequencing

1. Rewrite `/home/agent/bin/ccstatusline` with correct schema + Cortex integration
2. Test with sample JSON input (simulated Claude Code schema)
3. Test with real state.json (should show `[claude-code-status-line:clarify]`)
4. Test with missing state.json (should omit Cortex section)
5. Visual verification: next session restart should show the new format

---

## 8. Tasks

- [ ] Rewrite `/home/agent/bin/ccstatusline` to use correct Claude Code schema fields (`model.display_name`, `workspace.current_dir`, `context_window.total_input_tokens`, etc.)
- [ ] Add `cost.total_cost_usd` display with `$X.XX` format
- [ ] Add Cortex state reading from `$CLAUDE_PROJECT_DIR/.cortex/state.json` with existence guard
- [ ] Add warning marker `⚠` when `mode=execute` and `approvals.contract=false`
- [ ] Add try/except guards around all field accesses for graceful degradation
- [ ] Test with sample JSON: pipe canonical Claude Code schema through the script and verify output format
- [ ] Test with current project state.json: verify Cortex section renders correctly
- [ ] Test with no state.json (simulate non-Cortex project): verify Cortex section is omitted cleanly

---

## 9. Acceptance Criteria

- [ ] `/home/agent/bin/ccstatusline` reads `model.display_name` correctly and shows model name (e.g., `opus 4.6`)
- [ ] Script reads `workspace.current_dir` and shows truncated path with `~/` prefix for home
- [ ] Script reads `context_window.total_input_tokens` + `total_output_tokens` and shows `ctx:N%` as percentage of `context_window_size`
- [ ] Script reads `cost.total_cost_usd` and shows `$X.XX` session cost
- [ ] Script reads `$CLAUDE_PROJECT_DIR/.cortex/state.json` when present and shows `[slug:mode]` section
- [ ] Script omits the Cortex section entirely when `.cortex/state.json` does not exist
- [ ] Script shows warning marker (⚠) when mode is "execute" and `approvals.contract` is false
- [ ] Script does not crash on missing or malformed input — bad fields render as `?`
- [ ] Piped test: `echo '{...valid schema...}' | ccstatusline` produces expected output without errors
- [ ] Visual verification: restarting Claude Code shows the new format with correct model, cwd, context %, cost, and Cortex state
