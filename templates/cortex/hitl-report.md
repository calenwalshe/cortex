# HITL Report Template — Progressive Disclosure

When presenting output at any HITL gate (research complete, spec ready, build done, verification result), use progressive disclosure with 3 levels. The active level is determined by `report_level` in `.cortex/display.json` (default: 1).

## Level 1: Owner (default)

4 mandatory sections, plain language, no jargon:

```
## {Slug} — {Gate Name}

**What this is:** {One sentence explaining what was done, in terms a non-technical stakeholder would understand.}

**What we found:** (or **What was built:** for build-complete gates)
- {2-4 bullets. Outcomes, not process. "The system can now X" not "We wrote cortex-X.py"}
- {Focus on what changed, what's possible now, what the numbers mean}

**Risks:**
- {1-3 honest risks in plain language. Not "test coverage is 85%" but "we haven't tested X scenario"}

**Your decision:** {What the human needs to decide. "Proceed to build?" / "Approve for execution?" / "Merge?"}
```

### Writing rules for Level 1:
- No file paths, no function names, no API endpoints
- No test counts (say "all tests pass" or "2 tests fail on X")
- No token counts, embedding dimensions, or model names
- Costs only if they matter to the decision (e.g., "$0.003 per use" is relevant; "$0.0001 per Jina call" is not)
- Latency only if it affects the user experience ("under 1 second" not "79ms")
- Risks must be honest, not hedged. "This could break X" not "There is a potential risk of X"

## Level 2: Implementer

Everything from Level 1 plus a technical detail section:

```
{Level 1 content}

---
<details>
<summary>Technical Detail</summary>

**Architecture:** {One-line approach}
**Key files:** {List of files created/modified}
**Dependencies:** {What this needs to work}
**Tests:** {Count and what they cover}
**Performance:** {Latency, throughput, cost per operation}
**Open issues:** {Any remaining concerns}
**External research:** {Sources consulted, with costs}

</details>
```

## Level 3: Auditor

Everything from Level 2 plus full artifact references:

```
{Level 2 content}

---
<details>
<summary>Full Evidence</summary>

**Artifacts:**
- {Link to research dossier}
- {Link to spec}
- {Link to contract}
- {Link to test results}

**Decision log:** {All decisions from decisions.md for this slug}
**Trade-offs:** {Full trade-off matrix from research}
**Search history:** {All external searches with queries, providers, costs, key findings}

</details>
```

## Gate-Specific Guidance

### Research Complete
- "What we found" = key findings and their implications
- Risks = what we still don't know, what could invalidate the findings
- Decision = "Proceed to spec?" or "Need more research on X?"

### Spec / Contract Ready  
- "What this is" = what will be built (not the spec document, the actual thing)
- "What we found" = scope, approach, key trade-offs made
- Risks = what the necessity gate said, what the coherence check found
- Decision = "Approve contract for execution?"

### Build Complete
- "What was built" = what you can do now that you couldn't before
- Show the UX: what command to run, what you'll see
- Risks = what's not covered, edge cases, known limitations
- Decision = "Close this slug?" or "Need fixes?"

### Verification Result
- "What we checked" = validators run, what they tested
- Pass/fail as plain statement, not a table of exit codes
- Risks = what wasn't verified (judgment calls, edge cases)
- Decision = "Accept and close?" or "Open repair contract?"
