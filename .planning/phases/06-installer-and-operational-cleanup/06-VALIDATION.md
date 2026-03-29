---
phase: 6
slug: installer-and-operational-cleanup
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-03-29
---

# Phase 6 — Validation Strategy

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash + node (no external test runner) |
| **Quick run command** | `node bin/install.js --dry-run` |
| **Full suite command** | `bash test/installer.test.sh` |
| **Estimated runtime** | ~10 seconds |

---

## Per-Requirement Verification Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? | Status |
|--------|----------|-----------|-------------------|-------------|--------|
| INST-01 | Installer symlinks skills to `~/.claude/skills/` | unit/grep | `grep -q "MANIFEST" bin/install.js && grep -q "cortex-clarify" bin/install.js` | ✅ | pending |
| INST-02 | All 4 agents + 10 hooks deployed and wired in settings | integration | `bash test/installer.test.sh --check-installed` | ❌ Wave 0 | pending |
| INST-03 | `--dry-run` exits 0 when `~/projects/cortex` absent | smoke | `bash test/installer.test.sh --check-dry-run` | ❌ Wave 0 | pending |
| INST-04 | No credential URLs in scripts/configs | audit | `grep -rn 'https://.*:.*@' bin/ hooks/ .claude/ scripts/ --include='*.sh' --include='*.js'` (expect 0 lines) | ✅ | pre-pass |
| INST-05 | `dotfiles-setup.sh --dry-run` exits 0 | smoke | `bash dotfiles-setup.sh --dry-run` | ❌ Wave 0 | pending |
| INST-06 | Running installer twice produces no errors | idempotency | `bash test/installer.test.sh --check-idempotency` | ❌ Wave 0 | pending |

---

## Wave 0 Gaps

- `test/installer.test.sh` — does not exist yet (covers INST-02, INST-03, INST-05, INST-06)
- `dotfiles-setup.sh` — does not exist yet (INST-05)
- `bin/install.js` agent/hook symlink functions — not yet implemented (INST-02)

Pre-passing:
- INST-04: credential audit already clean (confirmed by research)

---

## Phase Gate

All of the following must be true:

- [ ] `grep -q "MANIFEST" bin/install.js` — MANIFEST constant exists
- [ ] `grep -q "cortex-clarify" bin/install.js` — skills listed in MANIFEST
- [ ] `grep -q "installAgents" bin/install.js` — agent deployment function exists
- [ ] `grep -q "installHooks" bin/install.js` — hook deployment function exists
- [ ] `test -f dotfiles-setup.sh && bash dotfiles-setup.sh --dry-run` — exits 0
- [ ] `test -f test/installer.test.sh` — test suite exists
- [ ] `bash test/installer.test.sh` — all assertions pass
- [ ] `grep -rn 'https://.*:.*@' bin/ hooks/ .claude/ scripts/ --include='*.sh' --include='*.js' | wc -l | grep -q "^0$"` — no credential URLs
