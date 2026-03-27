# Cortex Layer 3: Security Audit (/cortex-audit)

> Extracted from: upstream/gstack/cso/SKILL.md.tmpl
> Upstream version: v0.12.12.0 (11695e3)
> Adapted for: Cortex thinking layer
> This is a SUMMARY — the full /cso has 14 phases. See upstream for complete detail.

## Activation

Activates when explicitly requested via `/cortex-audit` or when security
concerns arise during code review. NOT always-on — security auditing is
a deliberate action.

## Audit Phases (Summary)

| Phase | What It Checks |
|-------|---------------|
| 0 | Stack detection + architecture mental model |
| 1 | Attack surface census (endpoints, infra, trust boundaries) |
| 2 | Secrets archaeology (git history, .env files, CI configs) |
| 3 | Dependency supply chain (CVEs, install scripts, lockfiles) |
| 4 | CI/CD pipeline security (workflow permissions, secret access) |
| 5 | Infrastructure config (Docker, IaC, deploy targets) |
| 6 | LLM/AI security (prompt injection, trust boundaries) |
| 7 | Input validation (SQLi, XSS, command injection, path traversal) |
| 8 | Skill/plugin supply chain (Claude Code skills, MCP servers) |
| 9 | OWASP Top 10 (full checklist) |
| 10 | STRIDE threat modeling |
| 11 | Authentication & authorization |
| 12 | Active verification (test findings, not just grep) |
| 13 | Report generation |
| 14 | Trend tracking across audit runs |

## Two Modes

| Mode | Confidence Gate | Use When |
|------|:---:|---|
| **Daily** (default) | 8/10 | Regular check — zero noise, only high-confidence findings |
| **Comprehensive** (`--comprehensive`) | 2/10 | Monthly deep scan — surfaces more, accepts some false positives |

## Key Principles

1. **Think like an attacker, report like a defender.** Find the doors that
   are actually unlocked, not hypothetical threats.

2. **Infrastructure first, code second.** Most real attacks come through:
   - Exposed env vars in CI logs
   - Stale API keys in git history
   - Forgotten staging servers with prod DB access
   - Third-party webhooks that accept anything

3. **8/10 confidence gate (daily mode).** If you're less than 80% confident
   a finding is real, don't report it. Security noise causes alert fatigue,
   which causes real findings to get ignored.

4. **No code changes.** The audit produces a Security Posture Report with
   concrete findings, severity ratings, and remediation plans. It does NOT
   fix anything — that's a separate task.

## Severity Ratings

| Level | Meaning | Example |
|-------|---------|---------|
| CRITICAL | Active exploitation risk | API key in git history, SQL injection |
| HIGH | Significant risk, needs fix this sprint | .env tracked by git, missing auth check |
| MEDIUM | Should fix, not urgent | Abandoned dependency, missing rate limiting |
| LOW | Best practice improvement | Missing security headers, verbose error messages |

## OWASP Top 10 Quick Reference

1. **Broken Access Control** — Can users access resources they shouldn't?
2. **Cryptographic Failures** — Sensitive data in plaintext, weak hashing?
3. **Injection** — SQL, command, LDAP, XSS injection points?
4. **Insecure Design** — Missing threat modeling, abuse case gaps?
5. **Security Misconfiguration** — Default creds, verbose errors, open cloud storage?
6. **Vulnerable Components** — Known CVEs in dependencies?
7. **Authentication Failures** — Weak passwords, missing MFA, session issues?
8. **Data Integrity Failures** — Unverified updates, unsigned data, CI/CD tampering?
9. **Logging Failures** — Missing audit logs, no alerting on suspicious activity?
10. **SSRF** — Server-side request forgery via user-controlled URLs?

## STRIDE Quick Reference

| Threat | Question | Look For |
|--------|----------|----------|
| **S**poofing | Can someone pretend to be someone else? | Auth bypass, token theft |
| **T**ampering | Can someone modify data they shouldn't? | Missing integrity checks |
| **R**epudiation | Can someone deny an action? | Missing audit logs |
| **I**nformation Disclosure | Can someone see data they shouldn't? | Verbose errors, exposed APIs |
| **D**enial of Service | Can someone break availability? | Missing rate limits, resource exhaustion |
| **E**levation of Privilege | Can someone gain higher access? | Role bypass, admin escalation |

## Integration with GSD

No GSD equivalent exists for security auditing. This is purely additive.
Run `/cortex-audit` before shipping, during code review, or on a schedule.
The audit report can feed into GSD's verification gate.
