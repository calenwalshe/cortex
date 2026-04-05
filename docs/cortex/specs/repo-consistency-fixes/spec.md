# Spec: repo-consistency-fixes

**Slug:** repo-consistency-fixes
**Timestamp:** 20260405T055000Z
**Status:** approved

---

## 1. Problem

Cortex's documentation, manifest, and implementation disagree on command count (7/8/8/12), hook count (12/14/19), .planning/ ownership, and eval gate semantics. This undermines the repo's credibility and blocks autonomous operation.

---

## 2. Scope

### In Scope
- Fix command surface across README.md, CORTEX.md, runtime-manifest.json
- Add 4 missing skills to manifest (close, experiment, stash, fit)
- Add 3 distribution hooks to manifest
- Fix .planning/ ownership language in CORTEX.md
- Fix eval gate language in EVALS.md
- Remove stale cortex-postcompact.sh wiring from settings.json
- Update hook count in CORTEX.md
- Document --verbose and --dry-run installer flags

### Out of Scope
- Redesigning commands or lifecycle
- Building self-healing docs pipeline
- Changing eval system behavior

---

## 3. Architecture Decision

**Chosen approach:** Documentation-only fixes. Make docs match reality. No behavioral changes.

---

## 4. Interfaces
- README.md, CORTEX.md, docs/EVALS.md, docs/COMMANDS.md — documentation
- runtime-manifest.json — installable components
- .claude/settings.json — hook wiring

---

## 5. Dependencies
- None

---

## 6. Risks
- **Breaking existing installs** — Mitigation: only adding to manifest, not removing. Settings.json change removes duplicate wiring.

---

## 7. Sequencing
1. Fix runtime-manifest.json (add skills + hooks)
2. Fix CORTEX.md (command count, hook count, .planning/ language)
3. Fix README.md (command count, installer flags)
4. Fix EVALS.md (eval gate language)
5. Fix settings.json (remove stale .sh wiring)
6. Verify with grep-based consistency checks

---

## 8. Tasks
- [ ] Add cortex-close, cortex-experiment, cortex-stash, cortex-fit to manifest skills
- [ ] Add cortex-distribute.sh, cortex-distribute.py, nlm-refresh.py to manifest hooks
- [ ] Update CORTEX.md command count and list
- [ ] Update CORTEX.md .planning/ ownership language
- [ ] Update CORTEX.md hook count
- [ ] Update README.md command count and list
- [ ] Update README.md installer flags
- [ ] Fix EVALS.md eval gate language
- [ ] Remove cortex-postcompact.sh from settings.json PostCompact wiring
- [ ] Run consistency verification

---

## 9. Acceptance Criteria
- [ ] runtime-manifest.json skills count matches actual cortex skill directories
- [ ] README.md and CORTEX.md agree on command count and list
- [ ] CORTEX.md .planning/ section acknowledges bridge exception
- [ ] EVALS.md says pending eval_plan is OK during spec, required for done
- [ ] settings.json PostCompact only wires .js, not .sh
- [ ] CORTEX.md hook count matches manifest hook count
