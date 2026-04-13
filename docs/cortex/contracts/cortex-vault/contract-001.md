# Contract: cortex-vault — execute

<!-- ART-05: Contract Template — produced by /cortex-spec -->

**ID:** cortex-vault-001
**Slug:** cortex-vault
**Phase:** execute
**Created:** 2026-04-13T14:30:00Z
**Status:** draft
**Repair Budget:** max_repair_contracts: 3, cooldown_between_repairs: 1

---

## Objective

Build `cortex-vault-extractor.py` and wire it into `cortex-session-start.sh` and the three intelligence-phase skill files so that Cortex sessions start with cross-slug vault facts injected into context and gate transitions write typed facts back to the vault.

---

## Deliverables

- `scripts/cortex/cortex-vault-extractor.py` — new Python extractor
- `.claude/hooks/cortex-session-start.sh` — vault injection block modification
- `~/.claude/skills/cortex-clarify/SKILL.md` — Phase 4c insertion
- `~/.claude/skills/cortex-research/SKILL.md` — Phase 2.9 insertion
- `~/.claude/skills/cortex-spec/SKILL.md` — Phase 2c insertion

---

## Scope

### In Scope

- `cortex-vault-extractor.py`: path-based artifact detection, 9 extraction categories, subprocess write to vault, idempotency guard, soft-fail
- `cortex-session-start.sh` vault read injection block (lines 40-43 region only)
- Three skill file insertions at established Phase 4c/2.9/2c hook points

### Out of Scope

- Vault schema changes or modifications to vault scripts
- Autoresearch classification loop
- `.cortex/facts.jsonl` replacement
- GSD execution phases (execute, validate, repair)
- inbox/promotion pipeline integration
- cortex-close vault integration

---

## Write Roots

- `scripts/cortex/cortex-vault-extractor.py`
- `.claude/hooks/cortex-session-start.sh`
- `~/.claude/skills/cortex-clarify/SKILL.md`
- `~/.claude/skills/cortex-research/SKILL.md`
- `~/.claude/skills/cortex-spec/SKILL.md`

---

## Done Criteria

- [ ] `cortex-session-start.sh` calls `recall_query.py` and injects vault facts into `additionalContext` under a distinct `VAULT MEMORY` section header
- [ ] Total `additionalContext` length after vault injection remains under 10,000 characters
- [ ] Vault read uses `--top-k 5 --project cortex` to scope retrieval to Cortex-relevant facts
- [ ] Vault read soft-fails gracefully (empty string, no error) when vault index is absent or query returns nothing
- [ ] `scripts/cortex/cortex-vault-extractor.py` exists and accepts `--artifact <path> --slug <slug>` arguments
- [ ] Extractor correctly identifies artifact type using path-pattern truth table: `clarify/`→brief, `research/`+not `current-understanding.md`→dossier, `specs/spec.md`→spec; any other path→error
- [ ] Extractor calls `add_fact()` for each extracted typed fact with exact per-category field values as specified in spec §2
- [ ] Extraction is idempotent: re-running extractor on same artifact path and slug does not create duplicate facts
- [ ] Vault write soft-fails gracefully (logged warning, no exception) when vault is unavailable
- [ ] `cortex-clarify` Phase 4c calls `cortex-vault-extractor.py` after writing the clarify brief
- [ ] `cortex-research` Phase 2.9 calls `cortex-vault-extractor.py` after writing the research dossier
- [ ] `cortex-spec` Phase 2c calls `cortex-vault-extractor.py` after writing the spec

---

## Validators

- [ ] [external] `test -f scripts/cortex/cortex-vault-extractor.py && echo PASS || echo FAIL`
- [ ] [external] `python3 scripts/cortex/cortex-vault-extractor.py --help 2>&1 | grep -E "\-\-artifact.*\-\-slug" && echo PASS || echo FAIL`
- [ ] [external] `grep -n "VAULT MEMORY" .claude/hooks/cortex-session-start.sh && echo PASS || echo FAIL`
- [ ] [external] `grep -n "recall_query.py" .claude/hooks/cortex-session-start.sh && grep -n "top-k 5" .claude/hooks/cortex-session-start.sh && echo PASS || echo FAIL`
- [ ] [external] `grep -n "9500" .claude/hooks/cortex-session-start.sh && echo PASS || echo FAIL`
- [ ] [external] `grep -n "cortex-vault-extractor" ~/.claude/skills/cortex-clarify/SKILL.md && echo PASS || echo FAIL`
- [ ] [external] `grep -n "cortex-vault-extractor" ~/.claude/skills/cortex-research/SKILL.md && echo PASS || echo FAIL`
- [ ] [external] `grep -n "cortex-vault-extractor" ~/.claude/skills/cortex-spec/SKILL.md && echo PASS || echo FAIL`
- [ ] [external] `python3 -c "import subprocess, json, os; r = subprocess.run(['python3', 'scripts/cortex/cortex-vault-extractor.py', '--artifact', 'docs/cortex/clarify/cortex-vault/20260413T020000Z-clarify-brief.md', '--slug', 'cortex-vault'], cwd='$(pwd)', capture_output=True, text=True); print('PASS' if r.returncode == 0 else 'FAIL: ' + r.stderr[:200])" 2>/dev/null || echo FAIL`
- [ ] [external] `python3 -c "import sqlite3, subprocess, os; db=os.path.expanduser('~/memory/vault/facts.db'); conn=sqlite3.connect(db); c1=conn.execute('SELECT COUNT(*) FROM facts WHERE session_id=?',('cortex-cortex-vault',)).fetchone()[0]; subprocess.run(['python3','scripts/cortex/cortex-vault-extractor.py','--artifact','docs/cortex/clarify/cortex-vault/20260413T020000Z-clarify-brief.md','--slug','cortex-vault'],check=False); c2=conn.execute('SELECT COUNT(*) FROM facts WHERE session_id=?',('cortex-cortex-vault',)).fetchone()[0]; conn.close(); print('PASS' if c2==c1 else f'FAIL: count went from {c1} to {c2}')" 2>/dev/null || echo FAIL`
- [ ] [judgment] Vault injection block in `cortex-session-start.sh` is positioned after the closing `fi` of the outer facts retrieval block (after `if [[ -f "$FACTS_FILE"...` closes) and before the `HEALTH=""` line, with budget truncation guard (`9500 - len(existing_content)`) present in the logic path (not just in a comment)
- [ ] [judgment] The three skill insertions (Phase 4c/2.9/2c) match the style and non-blocking pattern established by the gate-critique slug (soft-fail on extractor error, no pipeline block)

---

## Eval Plan

docs/cortex/evals/cortex-vault/eval-plan.md (pending)

---

## Approvals

- [ ] Contract approval
- [ ] Evals approval

---

## Completion Promise

CORTEX_PROMISE: cortex-vault-001 COMPLETE

---

## Failed Approaches

(none — initial contract)

---

## Why Previous Approach Failed

N/A — initial contract

---

## Rollback Hints

- Delete `scripts/cortex/cortex-vault-extractor.py`
- Revert `.claude/hooks/cortex-session-start.sh` to prior version (remove VAULT_FACTS block)
- Remove Phase 4c from `~/.claude/skills/cortex-clarify/SKILL.md`
- Remove Phase 2.9 from `~/.claude/skills/cortex-research/SKILL.md`
- Remove Phase 2c from `~/.claude/skills/cortex-spec/SKILL.md`

---

## Repair Budget

**max_repair_contracts:** 3
**cooldown_between_repairs:** 1
