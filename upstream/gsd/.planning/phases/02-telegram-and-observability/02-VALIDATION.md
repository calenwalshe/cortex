---
phase: 2
slug: telegram-and-observability
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-09
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | vitest 3.x |
| **Config file** | `gsd-runner/vitest.config.ts` (exists from Phase 1) |
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
| 2-01-01 | 01 | 1 | OBSV-01 | unit | `npx vitest run test/logger.test.ts` | Wave 0 | ⬜ pending |
| 2-01-02 | 01 | 1 | OBSV-02 | unit | `npx vitest run test/stuck-detector.test.ts` | Wave 0 | ⬜ pending |
| 2-02-01 | 02 | 2 | TELE-01 | unit | `npx vitest run test/telegram.test.ts -t "sends gate notification"` | Wave 0 | ⬜ pending |
| 2-02-02 | 02 | 2 | TELE-02 | unit | `npx vitest run test/telegram.test.ts -t "resolves gate"` | Wave 0 | ⬜ pending |
| 2-02-03 | 02 | 2 | TELE-03 | unit | `npx vitest run test/telegram.test.ts -t "progress"` | Wave 0 | ⬜ pending |
| 2-02-04 | 02 | 2 | TELE-04 | unit | `npx vitest run test/telegram.test.ts -t "heartbeat"` | Wave 0 | ⬜ pending |
| 2-03-01 | 03 | 3 | TELE-01, TELE-02 | integration | `npx vitest run test/daemon-loop.test.ts -t "gate"` | Wave 0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `gsd-runner/test/logger.test.ts` — child logger creation, structured output
- [ ] `gsd-runner/test/stuck-detector.test.ts` — sliding window, threshold detection
- [ ] `gsd-runner/test/telegram.test.ts` — gate controller, progress, heartbeat (mock grammY Bot)
- [ ] grammY + pino installation: `cd gsd-runner && npm install grammy pino`

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Telegram message actually appears in chat | TELE-01 | Requires live bot token + Telegram account | Set BOT_TOKEN + CHAT_ID, run daemon, trigger gate, check phone |
| Heartbeat pings arrive on schedule | TELE-04 | Requires live bot running for extended period | Run daemon for 1+ hours, verify heartbeat interval |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
