# docs/cortex/audits/

**Artifact type:** Security and quality audit — written by `/cortex-audit`

---

## Naming Pattern

```
docs/cortex/audits/<slug>/<timestamp>-audit.md
```

- `<slug>` matches the slug from the corresponding active contract
- `<timestamp>` is ISO 8601 compact format: `YYYYMMDDTHHMMSS`
- Multiple audits for the same slug are allowed; the timestamp disambiguates them

**Example:**
```
docs/cortex/audits/smart-retry-logic/20260329T164000-audit.md
```

---

## Required Lenses

Every audit artifact **must cover all 7 lenses**. No lens may be omitted without an explicit documented note explaining why it is not applicable.

| # | Lens | Focus |
|---|------|-------|
| 1 | Authentication | Correct identity verification — are callers authenticated where required? |
| 2 | Data handling | Correct storage, transmission, and disposal of sensitive data |
| 3 | Secrets exposure | Credentials, tokens, keys — are they exposed in logs, outputs, or error messages? |
| 4 | Unsafe tool usage | Dangerous operations: shell injection, unvalidated `eval`, unsafe deserialization |
| 5 | Input validation | Are external inputs validated and sanitized before use? |
| 6 | Dependency risks | Outdated, vulnerable, or malicious dependencies |
| 7 | Misuse vectors | How could the component be misused or abused by a malicious actor? |

---

## Required Sections per Lens

For each lens, the audit artifact must contain:

| Field | Description |
|-------|-------------|
| `scope` | What was examined for this lens |
| `findings` | Observations — vulnerabilities found, or confirmation of correct practice |
| `severity` | `critical`, `high`, `medium`, `low`, or `info` |
| `remediation` | Specific steps to address findings (or "none required" if finding is clean) |

If a lens is **not applicable** to the target, the artifact must include an explicit note:

```
**[Lens N]: Not applicable**
Reason: [Specific explanation of why this lens does not apply to the audit target]
```

The "not applicable" note cannot be omitted — silence on a lens is not acceptable.

---

## Creating Command

```bash
/cortex-audit [<target>]
```

- The `<target>` can be a file, directory, or component description
- If no argument is provided, audits the current active contract's `write_roots`
- Output is always a repo-local artifact — chat-only audit responses do not count
- Must cover all 7 lenses regardless of target scope

**Example:**
```
/cortex-audit src/
```

---

## Notes

- Audit artifacts are written to the target project repo, not the Cortex framework repo
- Critical or high severity findings should trigger `/cortex-investigate` before proceeding
- See `docs/COMMANDS.md` for the full `/cortex-audit` reference
- Audit results may feed into the `safety/security` dimension of the eval plan
