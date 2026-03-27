---
phase: 1
slug: core-engine
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-09
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | vitest (latest) |
| **Config file** | `gsd-runner/vitest.config.ts` (Wave 0 installs) |
| **Quick run command** | `cd gsd-runner && npx vitest run --reporter=verbose` |
| **Full suite command** | `cd gsd-runner && npx vitest run` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `cd gsd-runner && npx vitest run --reporter=verbose`
- **After every plan wave:** Run `cd gsd-runner && npx vitest run`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 1-01-01 | 01 | 1 | LOOP-01 | unit | `npx vitest run test/state-machine.test.ts` | Wave 0 | ⬜ pending |
| 1-01-02 | 01 | 1 | LOOP-04 | unit | `npx vitest run test/state-machine.test.ts -t "all complete"` | Wave 0 | ⬜ pending |
| 1-02-01 | 02 | 1 | SESS-01 | unit | `npx vitest run test/session-runner.test.ts -t "maxTurns"` | Wave 0 | ⬜ pending |
| 1-02-02 | 02 | 1 | SESS-02 | unit | `npx vitest run test/session-runner.test.ts -t "compaction"` | Wave 0 | ⬜ pending |
| 1-02-03 | 02 | 1 | SESS-03 | unit | `npx vitest run test/session-runner.test.ts -t "fresh session"` | Wave 0 | ⬜ pending |
| 1-02-04 | 02 | 1 | SESS-04 | unit | `npx vitest run test/index.test.ts -t "SIGTERM"` | Wave 0 | ⬜ pending |
| 1-02-05 | 02 | 1 | LOOP-03 | unit | `npx vitest run test/session-runner.test.ts -t "permissions"` | Wave 0 | ⬜ pending |
| 1-03-01 | 03 | 2 | LOOP-02 | integration | `npx vitest run test/daemon-loop.test.ts -t "full cycle"` | Wave 0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `gsd-runner/package.json` — project manifest with dependencies
- [ ] `gsd-runner/tsconfig.json` — TypeScript configuration
- [ ] `gsd-runner/vitest.config.ts` — vitest configuration
- [ ] `gsd-runner/test/state-machine.test.ts` — state machine transition tests
- [ ] `gsd-runner/test/session-runner.test.ts` — session lifecycle tests
- [ ] `gsd-runner/test/index.test.ts` — daemon entry point tests (SIGTERM)
- [ ] `gsd-runner/test/daemon-loop.test.ts` — integration tests for full phase cycle
- [ ] `gsd-runner/test/fixtures/` — sample STATE.md, ROADMAP.md files for various states

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Full phase cycle with real Claude Code | LOOP-02 | Requires live Agent SDK + API key | Run daemon against a test GSD project, observe plan→execute→verify→advance |
| Context exhaustion checkpoint | SESS-02 | Requires long-running session to trigger compaction | Run with low maxTurns, verify pause-work is invoked |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
