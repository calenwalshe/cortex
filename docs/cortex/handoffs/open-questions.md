# Open Questions

<!-- No active slug — run /cortex-clarify to start a work item -->

**slug:** (none)

**timestamp_updated:** (not set)

## Questions

(No active questions — no work item in progress)

---

## Uncertainty Register Schema

Cross-reference: `docs/DISCOVERY_LOOP.md` §3

Structured questions use the following five fields. Flat/legacy entries (plain text only) remain valid — backward-compat defaults apply.

| Field | Type | Valid Values |
|-------|------|-------------|
| `type` | enum | `frame \| knowledge \| design \| evidence \| eval` |
| `severity` | enum | `critical \| noncritical` |
| `resolution_path` | enum | `research \| experiment \| human` |
| `status` | enum | `open \| resolved \| deferred \| accepted-risk` |
| `resolved_by` | pointer | Path to resolving artifact, or `null` |

**Backward-compat defaults for flat/legacy entries:**
- type: `knowledge`
- severity: `noncritical`
- resolution_path: `research`
- status: `open`
- resolved_by: `null`

### Structured Entry Example

```markdown
- **Q:** Does the embed model return deterministic cosine scores for identical inputs?
  - type: evidence
  - severity: critical
  - resolution_path: experiment
  - status: open
  - resolved_by: null
```

```markdown
- **Q:** Which embedding dimension yields best recall@10 on the eval set?
  - type: design
  - severity: noncritical
  - resolution_path: experiment
  - status: resolved
  - resolved_by: docs/cortex/experiments/embed-dim-sweep/result.md
```
