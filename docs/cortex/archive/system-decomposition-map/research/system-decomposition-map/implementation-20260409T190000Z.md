# Research Dossier: system-decomposition-map — implementation

**Slug:** system-decomposition-map
**Phase:** implementation
**Timestamp:** 20260409T190000Z
**Depth:** standard
**Provenance:** All web findings via power_search (Tavily search + Jina URL reads + Gemini cross-reference). Codebase findings from direct file reads.

---

## Summary

The system map should be a single Markdown file at `docs/cortex/system-map.md` with a hard 3K token target. **Hook injection is the wrong primary delivery mechanism** — the 10K character `additionalContext` cap is shared with `current-state.md` and facts, leaving only ~2500 tokens for the map. Instead, the session-start hook should inject a **pointer + freshness status line** (~100 tokens), and skills (`cortex-spec`, `cortex-review`, `cortex-research`) should read the full map directly when they need it. The map should use Mermaid's native C4 syntax (`C4Context`, `C4Container`) for diagrams, a markdown table for the component registry, and YAML frontmatter for the freshness envelope. Updates should be **proposed by `/cortex-spec`** after each slug, not auto-committed — the map is too important for unreviewed writes.

---

## Findings

- **The 10K character hook output cap is the binding constraint.** Claude Code's `additionalContext` field is capped at 10K characters. The current session-start hook already injects `current-state.md` (~500-1500 chars), facts (~1000-3000 chars), and coherence warnings. A 3K-token map (~12K chars) would exceed the cap by itself. Full hook injection is not viable. Source: code.claude.com/docs/en/hooks (confirmed via Tavily search).

- **Pointer injection + skill-level reads is the correct pattern.** The session-start hook should inject one line: `SYSTEM MAP: docs/cortex/system-map.md (last_verified: 2026-03-15, confidence: high)` or `SYSTEM MAP: docs/cortex/system-map.md (⚠ stale: last verified 94 days ago)`. This costs ~30-50 tokens. Skills that need the full map read it directly — no cap, no competition for injection space. This matches the CLAUDE.md best practice of keeping loaded context minimal and using separate files for detailed reference. Source: reddit.com/r/ClaudeAI (structuring Claude Code projects); builder.io (CLAUDE.md guide); Gemini cross-reference.

- **CLAUDE.md best practice: keep it minimal, reference separate files.** Multiple practitioners converge: "Keep CLAUDE.md as minimal as possible", "Stable rules go in `.claude/rules/` as separate files", "Move detailed topic-specific guidance to separate files." The system map should NOT be inlined into CLAUDE.md. It should be an independent file that CLAUDE.md optionally references with a one-liner like `System architecture: see docs/cortex/system-map.md`. Source: reddit.com/r/ClaudeAI; hannahstulberg.substack.com; builder.io.

- **Mermaid supports native C4 diagram syntax.** Mermaid has experimental C4 support via `C4Context`, `C4Container`, `C4Component` directives. These are purpose-built for C4 diagrams with proper element types (Person, System, Container, etc.) and relationships. However, the native syntax is less widely supported in renderers than the `flowchart` approach with `classDef` styling. For maximum compatibility, use `flowchart` with C4-style `classDef` declarations. Source: lukemerrett.com (Building C4 Diagrams in Mermaid); lobehub.com (C4 modeling skill).

- **The effective context window is ~60% of advertised capacity.** Multiple sources converge: "Don't let context exceed 60% of the 200K token window." This means the system map's token cost matters even though 200K seems large. A 3K-token map is 1.5% of effective capacity — negligible when read by a skill, but meaningful if injected into every session alongside other context. Source: datacamp.com (Claude Code best practices); cursor.directory (context engineering plugin).

- **Three-phase compression workflow is the right mental model for the map.** Context engineering best practice: (1) Research phase: explore architecture, compress into structured analysis, (2) Planning phase: convert to specification with signatures and data flow — "a 5M-token codebase compresses to ~2,000 words of specification", (3) Implementation phase: execute against the spec. The system map IS the output of phase 1 — compressed architectural exploration. It should feel like "a single research document that replaces raw exploration." Source: cursor.directory (context engineering).

- **Auto-updating the map via LLM is high-risk.** Gemini cross-reference flagged: "Automatic updates of the system map by an LLM are a significant risk. LLMs can hallucinate, misunderstand architectural nuances, or introduce inconsistencies." The map is a canonical context source — if it's wrong, every downstream command that reads it inherits the error. `/cortex-spec` should **propose** map updates (generate a diff or suggestion), not directly overwrite. Updates should be human-reviewed. Source: Gemini cross-reference.

- **`project-context.md` format is a validated schema starting point.** The existing `project-context.md` files (4 instances across slugs) use a proven 4-section structure: Tech Stack, Conventions, Architecture Rules, Write Boundaries. This schema should be absorbed into the system map, not discarded. The map extends it with C4 diagrams and a component registry, but the narrative sections carry over directly. Source: codebase analysis of `docs/cortex/specs/*/project-context.md`.

- **Stale-while-revalidate is the right mental model for freshness.** The SWR pattern from web caching maps perfectly: serve the cached (possibly stale) system map immediately, while noting its age. The LLM uses whatever map exists, with a confidence penalty proportional to staleness. Revalidation happens when the user or a slug explicitly refreshes the map — not automatically. Source: infoq.com (UX Patterns: Stale-While-Revalidate).

---

## Trade-offs

### Option: Hook injection (full map in additionalContext)
**Pros:** Always available in session context. Benefits from prefix caching. Zero skill modifications needed.
**Cons:** 10K char cap makes this infeasible for a 3K-token map. Competes with current-state.md and facts for injection space. Would require aggressive truncation that defeats the purpose.
**Verdict:** rejected — the 10K char cap is a hard constraint. Full injection is not viable.

### Option: Hook pointer + skill-level reads
**Pros:** Pointer costs ~50 tokens. Skills read full map when needed — no cap. Matches CLAUDE.md best practice of minimal injection. Map can be any size without hook constraints.
**Cons:** Skills must be modified to read the file. Map is not in context until a skill explicitly loads it.
**Verdict:** selected — this is the correct architecture. The pointer ensures the LLM knows the map exists; skills load it when they need it.

### Option: Inline the map into CLAUDE.md
**Pros:** CLAUDE.md is always loaded. Zero hook changes needed.
**Cons:** CLAUDE.md is already substantial. Every practitioner warns against bloating it. The map would consume 3K tokens of the ~100 available instruction slots on every session, even when not needed. Updates to the map would pollute CLAUDE.md diffs.
**Verdict:** rejected — violates the "keep CLAUDE.md minimal" consensus.

### Option: Auto-update map after each slug via cortex-spec
**Pros:** Map stays current automatically. Zero human maintenance burden.
**Cons:** High risk of hallucination or inconsistency. Map is a canonical source — errors propagate to every downstream command. LLM-generated C4 diagrams may have syntax errors or misrepresent architecture. Git history gets polluted with auto-commits.
**Verdict:** rejected — updates should be proposed, not auto-committed. cortex-spec Phase 2b should generate a proposed diff that the user reviews.

### Option: Manual-only map maintenance
**Pros:** Human always in the loop. Maximum accuracy.
**Cons:** High friction. Users won't update it. The adoption gap research showed detailed docs that require manual maintenance get abandoned.
**Verdict:** rejected as the sole strategy — use LLM-assisted generation with human confirmation as the hybrid approach.

### Option: LLM-assisted generation with human confirmation
**Pros:** Low friction to create/update. LLM proposes, human reviews. Balances accuracy with maintenance burden.
**Cons:** Still requires human action — may get deferred indefinitely. Slight ceremony overhead.
**Verdict:** selected — this is the right balance. A `/cortex-map` command generates or refreshes the map, presenting the proposed version for user confirmation before writing.

---

## Recommendations

### 1. File Location and Template

**Path:** `docs/cortex/system-map.md`

**Template structure (target: under 3K tokens):**

```markdown
---
last_verified: {ISO date}
valid_until: {ISO date, default +90 days}
confidence: high | medium | low
advisory: true
generated_by: /cortex-map
slug_coverage: [list of slugs whose components are reflected]
---

# System Map: {project name}

## System Context (C4 Level 1)

{Mermaid flowchart: external actors, system boundary, key integrations}

## Containers (C4 Level 2)

{Mermaid flowchart: services, databases, major components, tech choices}

## Component Registry

| Component | Responsibility | Tech | Key Interfaces | Dependencies |
|-----------|---------------|------|----------------|--------------|
| ... | ... | ... | ... | ... |

## Crosscutting Conventions

{Terse list: error handling, auth, data formats, naming, testing patterns}

## Key Decisions

{Terse ADR-style entries: decision, rationale, date, slug that established it}
```

### 2. Session-Start Hook Modification

Add to `cortex-session-start.sh` after the facts retrieval block (~line 41):

```bash
# Inject system map pointer with freshness status
SYSTEM_MAP="${CLAUDE_PROJECT_DIR}/docs/cortex/system-map.md"
MAP_STATUS=""
if [[ -f "$SYSTEM_MAP" ]]; then
  # Extract last_verified from YAML frontmatter
  LAST_VERIFIED=$(grep -m1 'last_verified:' "$SYSTEM_MAP" | sed 's/last_verified: *//')
  if [[ -n "$LAST_VERIFIED" ]]; then
    DAYS_AGO=$(python3 -c "
from datetime import datetime, date
try:
    lv = datetime.strptime('$LAST_VERIFIED', '%Y-%m-%d').date()
    print((date.today() - lv).days)
except: print(-1)
" 2>/dev/null)
    if [[ "$DAYS_AGO" -gt 90 ]]; then
      MAP_STATUS="SYSTEM MAP: docs/cortex/system-map.md (⚠ stale: last verified ${DAYS_AGO} days ago — consider running /cortex-map to refresh)"
    elif [[ "$DAYS_AGO" -gt 60 ]]; then
      MAP_STATUS="SYSTEM MAP: docs/cortex/system-map.md (aging: last verified ${DAYS_AGO} days ago)"
    else
      MAP_STATUS="SYSTEM MAP: docs/cortex/system-map.md (fresh: verified ${LAST_VERIFIED})"
    fi
  else
    MAP_STATUS="SYSTEM MAP: docs/cortex/system-map.md (no freshness metadata)"
  fi
fi
```

Then append `$MAP_STATUS` to the `$EXTRA` variable alongside facts.

### 3. Skill Integration Points

**cortex-spec (Phase 2, synthesize):**
- Before synthesizing Section 4 (Interfaces), read `docs/cortex/system-map.md` if it exists
- Use the component registry and C4 diagrams to inform interface definitions
- After writing the spec, generate a **proposed map update** (diff or new sections) — do NOT auto-write

**cortex-review (architecture lens):**
- Read `docs/cortex/system-map.md` at the start of architecture lens evaluation
- Use it as the reference artifact for "does this fit existing patterns?"
- If the map doesn't exist, proceed as today (no error)

**cortex-research (Outside-In queries):**
- Read `docs/cortex/system-map.md` to inform domain angle selection
- Component boundaries and dependencies provide concrete angles for reformulation

### 4. `/cortex-map` Command

A new skill that:
1. **Generate mode** (first run or `--regenerate`): Reads the codebase, existing specs/contracts, and `project-context.md` files. Proposes a complete system map. Presents to user for confirmation.
2. **Refresh mode** (default): Reads the existing map + recent slug artifacts. Proposes updates. Shows diff. User confirms or edits.
3. **Verify mode** (`--verify`): Reads the map + current codebase. Reports which sections are still accurate vs. potentially stale. Updates `last_verified` timestamp if confirmed.

### 5. Migration Path from project-context.md

1. First `/cortex-map` run generates the system map from existing `project-context.md` files across all slugs
2. `/cortex-spec` Phase 2b is modified: instead of writing a per-slug `project-context.md`, it reads the system map and proposes updates
3. Existing `project-context.md` files remain on disk (no breaking change) but are no longer generated for new slugs

---

## Adjacent Findings

- **`additionalContext` has a hard 10K character cap:** Claude Code documentation confirms that hook output injected into context is "capped at 10,000 characters. Output that exceeds this limit is saved to a file and replaced with a preview and file path." This means the system map CANNOT be fully injected via the session-start hook — it would be truncated or replaced with a file pointer anyway. This is not a soft limit; it's enforced by the harness. This eliminates full hook injection as a viable delivery mechanism and forces the pointer + skill-read architecture. Source: code.claude.com/docs/en/hooks.

- **Context engineering treats context as "a finite attention budget, not a storage bin":** The cursor.directory context engineering plugin formalizes three constraints: hard token limit, effective-capacity ceiling (60-70%), and the U-shaped attention curve. The principle "informativity over exhaustiveness — include only what matters for the current decision" directly supports injecting a pointer (informative) rather than the full map (exhaustive). Skills that need the map load it when making a decision that requires it. Source: cursor.directory/plugins/context-engineering.

---

## Open Questions

- What should the `/cortex-map` skill look like in detail? (Generate mode, refresh mode, verify mode — needs its own spec)
- How should proposed map updates from `/cortex-spec` be presented? (Inline diff, separate file, git branch?)
- Should the component registry include a `slug_origin` column to trace which slug established each component? (Helps with understanding evolution but adds maintenance burden)
- How should the map handle components that are removed or deprecated? (Strikethrough, archive section, or just delete?)
- Should the memory system store a pointer to the system map, or should they remain independent? (Memory is cross-session learnings; the map is structural truth — likely independent)

---

## Sources

### Web sources (via power_search)
- code.claude.com/docs/en/hooks — Hook reference, `additionalContext` 10K char cap, SessionStart semantics (Tavily search)
- reddit.com/r/ClaudeAI (1r66oo0) — "How I structure Claude Code projects" — minimalist CLAUDE.md, separate rules files (Tavily search)
- hannahstulberg.substack.com — "Claude Code for Everything" — CLAUDE.md deep dive, context loading costs (Tavily search)
- builder.io/blog/claude-md-guide — "How to Write a Good CLAUDE.md File" — separate files for detailed guidance (Tavily search)
- datacamp.com/tutorial/claude-code-best-practices — 60% context capacity threshold, Document & Clear pattern (Tavily search)
- lukemerrett.com/building-c4-diagrams-in-mermaid/ — Mermaid C4 syntax (flowchart + classDef), native C4 directives note (Jina read)
- lobehub.com/skills/hack23-homepage-c4-modeling — C4 modeling skill with Mermaid syntax examples (Tavily search)
- cursor.directory/plugins/context-engineering — Context as finite attention budget, three-phase compression workflow (Tavily search)
- blog.bytebytego.com — Context engineering guide, conversation summarization patterns (Tavily search)
- ksred.com — Claude Code hooks guide, SessionStart stdout becomes context (Tavily search)
- codesignal.com — Smart context injection patterns, UserPromptSubmit context libraries (Tavily search)
- infoq.com/news/2020/11/ux-stale-while-revalidate/ — Stale-while-revalidate UX pattern (Tavily search)

### Cross-reference
- Gemini GENERATE — challenged hook injection (10K cap bottleneck), auto-update risk, proposed pointer + skill-read architecture

### Codebase sources (direct file reads)
- `.claude/hooks/cortex-session-start.sh` — current hook implementation, injection path, facts retrieval
- `.claude/skills/cortex-spec/SKILL.md` lines 229-259 — Phase 2b project-context.md generation
- `docs/cortex/specs/kalshi-adaptive-loop/project-context.md` — existing project-context format (4 sections)
- `docs/cortex/research/system-decomposition-map/concept-20260409T183000Z.md` — concept dossier recommendations
