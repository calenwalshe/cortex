---
phase: 4
slug: subagents-and-hooks
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-03-29
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash assertions + file existence checks |
| **Config file** | none — direct shell commands |
| **Quick run command** | `test -f .claude/agents/cortex-specifier.md && test -f .claude/hooks/cortex-session-start.sh && echo "core files exist"` |
| **Full suite command** | See per-task verification map below |
| **Estimated runtime** | ~5 seconds (grep/test only) |

---

## Sampling Rate

- **After every task commit:** File-existence + content-grep for that task's output
- **After each plan wave:** Run all automated commands for completed tasks
- **Before `/gsd:verify-work`:** All 22 phase gate checks must pass
- **Max feedback latency:** ~5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| T1 | 04-01 | 1 | AGNT-01 | grep | `grep -q "name: cortex-specifier" .claude/agents/cortex-specifier.md && grep -q "^tools:" .claude/agents/cortex-specifier.md` | ❌ | pending |
| T2 | 04-01 | 1 | AGNT-02 | grep | `grep -q "name: cortex-critic" .claude/agents/cortex-critic.md && ! grep -q "Write" .claude/agents/cortex-critic.md` | ❌ | pending |
| T3 | 04-01 | 1 | AGNT-03 | grep | `grep -q "name: cortex-scribe" .claude/agents/cortex-scribe.md` | ❌ | pending |
| T4 | 04-01 | 1 | AGNT-04 | grep | `grep -q "name: cortex-eval-designer" .claude/agents/cortex-eval-designer.md` | ❌ | pending |
| T1 | 04-02 | 1 | HOOK-01 | file+grep | `test -f .claude/hooks/cortex-session-start.sh && grep -q "current-state.md" .claude/hooks/cortex-session-start.sh` | ❌ | pending |
| T2 | 04-02 | 1 | HOOK-07 | grep | `test -f .claude/hooks/cortex-precompact.sh && grep -q "precompact-" .claude/hooks/cortex-precompact.sh` | ❌ | pending |
| T3 | 04-02 | 1 | HOOK-08 | grep | `test -f .claude/hooks/cortex-postcompact.sh && grep -q "last-compact-summary" .claude/hooks/cortex-postcompact.sh` | ❌ | pending |
| T4 | 04-02 | 1 | HOOK-09 | grep | `test -f .claude/hooks/cortex-session-end.sh && grep -q "Stop" .claude/settings.json` | ❌ | pending |
| T1 | 04-03 | 1 | HOOK-02 | unit | `echo '{"tool_name":"Write","tool_input":{"file_path":"/project/src/foo.ts"}}' | MODE=spec bash .claude/hooks/cortex-phase-guard.sh | grep -q "deny"` | ❌ | pending |
| T2 | 04-03 | 1 | HOOK-03 | grep | `test -f .claude/hooks/cortex-validator-trigger.sh && grep -q "dirty-files.json" .claude/hooks/cortex-validator-trigger.sh` | ❌ | pending |
| T3 | 04-03 | 1 | HOOK-04 | unit | `echo '{"task_subject":"thing","task_description":"no validator"}' | bash .claude/hooks/cortex-task-created.sh | grep -q "continue.*false"` | ❌ | pending |
| T4 | 04-03 | 1 | HOOK-05 | grep | `test -f .claude/hooks/cortex-task-completed.sh && grep -q "validator" .claude/hooks/cortex-task-completed.sh` | ❌ | pending |
| T5 | 04-03 | 1 | HOOK-06 | file | `test -f .claude/hooks/cortex-teammate-idle.sh` | ❌ | pending |
| T1 | 04-04 | 1 | HOOK-10 | grep | `! grep -q "@github.com" .claude/hooks/cortex-sync.sh` | ❌ | pending |
| T2 | 04-04 | 1 | CONT-01,CONT-02 | grep | `grep -q "mode:" docs/cortex/handoffs/current-state.md && grep -q "slug:" docs/cortex/handoffs/current-state.md` | ✅ | pending |
| T3 | 04-04 | 1 | CONT-02 | grep | `for f in slug mode approval_status active_contract_path recent_artifacts open_questions blockers next_action; do grep -q "$f" docs/cortex/handoffs/current-state.md || exit 1; done && echo OK` | ✅ | pending |
| T4 | 04-04 | 1 | CONT-03 | file | `test -f docs/cortex/handoffs/next-prompt.md && test $(wc -l < docs/cortex/handoffs/next-prompt.md) -ge 3` | ✅ | pending |
| T5 | 04-04 | 1 | LOOP-02 | grep | `grep -q "repair" docs/CONTINUITY.md` | ✅ | pending |
| T6 | 04-04 | 1 | LOOP-04 | file | `jq -e '.mode' .cortex/state.json > /dev/null` | ✅ | pending |

---

## Wave 0 Gaps

All hook scripts (`.claude/hooks/cortex-*.sh`) and agent files (`.claude/agents/cortex-*.md`) are Phase 4 deliverables — none exist yet. All "File Exists" entries showing ❌ are expected in Wave 0.

The following pre-existing files are already present (✅) and require no creation:
- `docs/cortex/handoffs/current-state.md` — seeded in Phase 2
- `docs/cortex/handoffs/next-prompt.md` — seeded in Phase 2
- `docs/CONTINUITY.md` — written in Phase 1
- `.cortex/state.json` — created in Phase 2

---

## Phase Gate

All of the following must be true before phase is considered complete:

- [ ] `grep -q "name: cortex-specifier" .claude/agents/cortex-specifier.md && grep -q "^tools:" .claude/agents/cortex-specifier.md` → pass
- [ ] `grep -q "name: cortex-critic" .claude/agents/cortex-critic.md && ! grep -q "Write" .claude/agents/cortex-critic.md` → pass (read-only enforced)
- [ ] `grep -q "name: cortex-scribe" .claude/agents/cortex-scribe.md` → pass
- [ ] `grep -q "name: cortex-eval-designer" .claude/agents/cortex-eval-designer.md` → pass
- [ ] `test -f .claude/hooks/cortex-session-start.sh && grep -q "current-state.md" .claude/hooks/cortex-session-start.sh` → pass
- [ ] `test -f .claude/hooks/cortex-phase-guard.sh` → pass
- [ ] `test -f .claude/hooks/cortex-validator-trigger.sh && grep -q "dirty-files.json" .claude/hooks/cortex-validator-trigger.sh` → pass
- [ ] `test -f .claude/hooks/cortex-task-created.sh` → pass
- [ ] `test -f .claude/hooks/cortex-task-completed.sh && grep -q "validator" .claude/hooks/cortex-task-completed.sh` → pass
- [ ] `test -f .claude/hooks/cortex-teammate-idle.sh` → pass
- [ ] `test -f .claude/hooks/cortex-precompact.sh && grep -q "precompact-" .claude/hooks/cortex-precompact.sh` → pass
- [ ] `test -f .claude/hooks/cortex-postcompact.sh && grep -q "last-compact-summary" .claude/hooks/cortex-postcompact.sh` → pass
- [ ] `test -f .claude/hooks/cortex-session-end.sh` → pass
- [ ] `! grep -q "@github.com" .claude/hooks/cortex-sync.sh` → pass (no credential URL)
- [ ] `grep -q "mode:" docs/cortex/handoffs/current-state.md && grep -q "slug:" docs/cortex/handoffs/current-state.md` → pass
- [ ] `for f in slug mode approval_status active_contract_path recent_artifacts open_questions blockers next_action; do grep -q "$f" docs/cortex/handoffs/current-state.md || exit 1; done` → pass
- [ ] `test -f docs/cortex/handoffs/next-prompt.md` → pass
- [ ] `grep -q "repair" docs/CONTINUITY.md` → pass
- [ ] `jq -e '.mode' .cortex/state.json > /dev/null` → pass
- [ ] `grep -q "SessionStart" .claude/settings.json` → pass (hooks registered)
- [ ] `grep -q "PreCompact" .claude/settings.json` → pass
- [ ] `grep -q "PostCompact" .claude/settings.json` → pass
