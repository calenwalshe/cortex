# Research Dossier — Implementation

---
slug: canonical-deliverable-distribution-system
phase: implementation
timestamp: 20260331T063000Z
depth: standard
sources: Tavily (3 searches), Jina Reader (1 extract), Gemini (cross-reference), codebase inspection
---

## Summary

The distribution system is a PostToolUse hook (`async: true`) that fires when Cortex writes any artifact under `docs/cortex/`, reads the file path and content from stdin JSON, matches the path against a YAML routing table, and fans out to email (Gmail SMTP) and/or NotebookLM (Python MCP script). No new infrastructure. Slots directly into the existing hook stack alongside `cortex-sync.sh` and `cortex-validator-trigger.sh`. Total new code: one shell dispatcher (~40 lines), one Python distributor (~80 lines), one YAML routing config.

---

## Findings

### 1. PostToolUse stdin JSON schema (confirmed)

```json
{
  "session_id": "abc123",
  "hook_event_name": "PostToolUse",
  "tool_name": "Write",
  "tool_input": {
    "file_path": "/abs/path/to/file.md",
    "content": "full file content as string"
  },
  "tool_response": {
    "filePath": "/abs/path/to/file.md",
    "success": true
  }
}
```

Both `tool_input.file_path` and `tool_input.content` are available inline — no need to re-read the file. This is the same schema used by `cortex-sync.sh` and `cortex-validator-trigger.sh`.

### 2. async: true (confirmed, available now)

PostToolUse hooks support `"async": true` which runs the hook in the background without blocking Claude's execution. Distribution is a pure side-effect — it should always be async to avoid adding latency to every Write/Edit.

```json
{
  "matcher": "Write|Edit",
  "hooks": [{
    "type": "command",
    "command": "/home/agent/.claude/hooks/cortex-distribute.sh",
    "async": true
  }]
}
```

### 3. Routing table design

Gemini recommendation: **external YAML config** mapping path regex patterns to surfaces. Decouples routing from code, auditable, no redeployment needed to add new deliverable types.

Proposed schema at `~/.claude/hooks/cortex-distribute-routes.yaml`:

```yaml
routes:
  - pattern: "docs/cortex/recipes/.*\\.md"
    surfaces: [email, notebooklm]
    email:
      subject_template: "Recipe: {title}"
    notebooklm:
      notebook_title_template: "Recipe — {title}"

  - pattern: "docs/cortex/research/.*/.*\\.md"
    surfaces: [notebooklm]
    notebooklm:
      notebook_title_template: "Research — {slug} / {filename}"
```

Initial v1 can use a hardcoded match table in the Python script (no YAML dependency) and migrate to YAML when a third deliverable type is added. YAGNI until then.

### 4. NotebookLM: per-deliverable notebook (recommended)

Gemini recommendation: one notebook per deliverable, not one aggregated notebook per type. Rationale: granular context produces better NLM responses, lifecycle is simpler (delete the notebook when done, don't prune sources from a shared notebook), and cross-notebook query via MCP works across notebooks anyway.

Implementation: `notebook_create(title=...)` → `source_add(source_type="text", text=content, document_id=notebook_id)`.

Notebook title convention: `"{type} — {human-readable title from filename}"` e.g. `"Recipe — Soul Food Sous Vide Oxtail"`.

### 5. MCP integration method: Python script (not nlm CLI)

Gemini recommendation confirmed by existing stack: the current session already calls NotebookLM MCP tools inline. The hook should spawn a Python script that calls the MCP server directly via its installed path, same pattern as existing SMTP script. Shell CLIs are fragile for structured payloads.

The Python script receives file_path + content + surfaces as arguments, calls:
- Gmail SMTP (already proven: `~/.gmail_creds.json` → `app_password` key)
- NotebookLM MCP: `notebook_create()` then `source_add(source_type="text", text=content)`

### 6. Existing hook infrastructure (no conflicts)

Current `PostToolUse` Write|Edit hooks:
1. `cortex-sync.sh` — filters to `~/.claude/skills/cortex-*/SKILL.md` only, exits 0 for all other paths
2. `cortex-validator-trigger.sh` — reads dirty-files, only active in `execute|repair` mode

Neither conflicts with a new distribution hook. The new hook filters to `docs/cortex/recipes/` and `docs/cortex/research/` paths — orthogonal to both.

### 7. Content transformation per surface

| Surface | Format | Transformation |
|---------|--------|----------------|
| Email | Plain text | Strip markdown: remove `#` headers → ALL CAPS section titles, preserve body text, tables stay as-is |
| NotebookLM | Markdown | Pass raw content — NLM parses markdown natively as a text source |

No complex transformation library needed. A 15-line regex pass handles email markdown stripping.

---

## Trade-offs

| Decision | Chosen | Rejected | Reason |
|----------|--------|----------|--------|
| Notebook strategy | Per-deliverable | Aggregated by type | Granular context, simpler lifecycle, cross-notebook query still works |
| MCP call method | Python script | nlm CLI | Shell escaping brittle for large content; Python gives structured error handling |
| Routing config | Hardcoded v1 → YAML v2 | Full YAML from day 1 | YAGNI — only 2 deliverable types, add YAML when a 3rd appears |
| Hook timing | async: true | Synchronous | Distribution is a side effect; should never block Claude's execution |
| Email trigger | All Cortex artifacts | Only recipes | Research docs are also useful in email for cross-device access |

---

## Recommendations

**Recommended implementation sequence:**

1. **Shell dispatcher** (`~/.claude/hooks/cortex-distribute.sh`):
   - Read stdin, extract `file_path` and `content` via jq
   - Match against 2 hardcoded path patterns (recipes, research)
   - If match: pass file_path + content to Python distributor via tmpfile
   - Exit 0 always (async — no blocking behavior)

2. **Python distributor** (`~/.claude/hooks/cortex-distribute.py`):
   - Accept args: `--file-path`, `--surfaces` (comma-sep), `--title`
   - `email` surface: read `~/.gmail_creds.json`, send via SMTP_SSL, subject = title
   - `notebooklm` surface: call MCP `notebook_create` → `source_add(source_type="text")`
   - Log success/failure to `~/.claude/hooks/logs/cortex-distribute.log`

3. **Hook registration** in `~/.claude/settings.json`:
   ```json
   {
     "matcher": "Write|Edit",
     "hooks": [{
       "type": "command",
       "command": "/home/agent/.claude/hooks/cortex-distribute.sh",
       "async": true
     }]
   }
   ```
   Add to existing PostToolUse array alongside cortex-validator-trigger.sh.

4. **NotebookLM call pattern** (confirmed from this session's MCP usage):
   ```python
   # Create notebook
   notebook = mcp.notebook_create(title=title)
   notebook_id = notebook['name'].replace('notebooks/', '')
   # Add content as text source
   mcp.source_add(
     source_type="text",
     text=content,
     document_id=notebook_id
   )
   ```

**Known risk:** MCP calls from a hook subprocess may not have the active MCP session context. Mitigation: use the `nlm` CLI as a fallback if MCP subprocess fails. The CLI path is `nlm source add --notebook <id> --text <content>`.

---

## Open Questions

- Does a PostToolUse hook subprocess inherit the active MCP session, or does it need to re-auth? This is the highest implementation risk. Needs a live test before building.
- For the email surface: should research docs go to email or only recipes? The user indicated email is good for cross-device — but research docs are longer and may be noise in the inbox.
- Trigger scope: should the hook fire on ALL writes to `docs/cortex/` or only specific subdirectories? Current recommendation is recipes + research only, but future deliverable types (specs, audits) might also warrant distribution.

---

## Sources

1. https://code.claude.com/docs/en/hooks — PostToolUse stdin schema, async flag documentation
2. https://www.datacamp.com/tutorial/claude-code-hooks — PostToolUse stdin JSON example (confirmed schema)
3. https://github.com/ruvnet/ruflo/issues/1017 — async: true behavior, non-blocking PostToolUse
4. https://agentnativedev.medium.com/automate-google-notebooklm-from-your-ai-agent-with-notebooklm-mcp-3c513a37396a — NotebookLM MCP source_add patterns
5. `/home/agent/.claude/hooks/cortex-sync.sh` — reference implementation for PostToolUse path-filter + action pattern
6. `/home/agent/.claude/hooks/cortex-validator-trigger.sh` — reference for stdin parsing in existing stack
7. Gemini 2.5 Flash — cross-reference on notebook strategy, MCP method, routing table design
