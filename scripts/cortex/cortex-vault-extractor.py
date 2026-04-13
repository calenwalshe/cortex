#!/usr/bin/env python3
"""
cortex-vault-extractor.py — Extract typed facts from Cortex artifacts and write to vault.

Usage:
  python3 cortex-vault-extractor.py --artifact <path> --slug <slug>
  python3 cortex-vault-extractor.py --artifact <path> --slug <slug> --dry-run

Supports three artifact types (determined by path):
  clarify/ path → brief
  research/ path (filename ≠ current-understanding.md) → dossier
  specs/ path (filename == spec.md) → spec

Writes typed facts via add_fact() using:
  project_scope="cortex-memory-platform"
  session_id="cortex-{slug}"
  scope="learning"

Soft-fails gracefully if vault is unavailable.
"""

import argparse
import logging
import os
import re
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path

logging.basicConfig(
    level=logging.INFO,
    format="%(levelname)s [cortex-vault-extractor] %(message)s",
)
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

VAULT_SCRIPTS_PATH = os.path.expanduser("~/memory/vault/scripts/")
VAULT_DB_PATH = os.path.expanduser("~/memory/vault/facts.db")
PROJECT_SCOPE = "cortex-memory-platform"
SCOPE = "learning"

# Per-category field values (confidence, importance, memory_type)
CATEGORY_FIELDS = {
    "scope-exclusion":      dict(confidence=0.95, importance=0.6,  memory_type="semantic"),
    "owner-constraint":     dict(confidence=0.95, importance=0.8,  memory_type="semantic"),
    "design-assumption":    dict(confidence=0.75, importance=0.7,  memory_type="semantic"),
    "research-finding":     dict(confidence=0.80, importance=0.7,  memory_type="semantic"),
    "architecture-decision":dict(confidence=0.90, importance=0.8,  memory_type="semantic"),
    "adjacent-finding":     dict(confidence=0.75, importance=0.65, memory_type="semantic"),
    "failed-approach":      dict(confidence=0.85, importance=0.75, memory_type="procedural"),
    "risk-mitigation":      dict(confidence=0.80, importance=0.70, memory_type="semantic"),
}


# ---------------------------------------------------------------------------
# Artifact type detection (path-pattern truth table)
# ---------------------------------------------------------------------------

def detect_artifact_type(path: str) -> str:
    """Return artifact type from path.

    Truth table:
      path contains 'clarify/'                               → 'brief'
      path contains 'research/' and filename ≠ current-understanding.md → 'dossier'
      path contains 'specs/' and filename == 'spec.md'       → 'spec'
      all other paths                                         → ValueError
    """
    p = Path(path)
    parts = path.replace("\\", "/")

    if "clarify/" in parts:
        return "brief"

    if "research/" in parts:
        if p.name == "current-understanding.md":
            raise ValueError(f"unsupported artifact type: {path}")
        return "dossier"

    if "specs/" in parts:
        if p.name == "spec.md":
            return "spec"
        raise ValueError(f"unsupported artifact type: {path}")

    raise ValueError(f"unsupported artifact type: {path}")


# ---------------------------------------------------------------------------
# valid_from extraction
# ---------------------------------------------------------------------------

def extract_valid_from(path: str) -> str:
    """Extract date from artifact filename timestamp (e.g. 20260413T140000Z) or file mtime."""
    p = Path(path)
    # Try to parse ISO compact timestamp from filename: 20260413T140000Z
    m = re.search(r"(\d{4})(\d{2})(\d{2})T\d{6}Z", p.name)
    if m:
        return f"{m.group(1)}-{m.group(2)}-{m.group(3)}"
    # Try to read file mtime
    if p.exists():
        mtime = p.stat().st_mtime
        return datetime.fromtimestamp(mtime, tz=timezone.utc).strftime("%Y-%m-%d")
    # Fall back to today
    return datetime.now(tz=timezone.utc).strftime("%Y-%m-%d")


# ---------------------------------------------------------------------------
# Idempotency guard
# ---------------------------------------------------------------------------

def is_duplicate(db_path: str, session_id: str, topic: str, content: str) -> bool:
    """Return True if a fact with matching (session_id, topic, content[:50]) exists."""
    key = content[:50]
    try:
        conn = sqlite3.connect(db_path)
        row = conn.execute(
            "SELECT id FROM facts WHERE session_id=? AND topic=? AND SUBSTR(content,1,50)=?",
            (session_id, topic, key),
        ).fetchone()
        conn.close()
        return row is not None
    except Exception as e:
        logger.warning("is_duplicate check failed: %s", e)
        return False  # Safe default: try to write (add_fact's own uniqueness will handle it)


# ---------------------------------------------------------------------------
# Single-fact write (with idempotency guard)
# ---------------------------------------------------------------------------

def write_fact(
    *,
    add_fact_fn,
    db_path: str,
    session_id: str,
    topic: str,
    content: str,
    valid_from: str,
    memory_type: str,
    confidence: float,
    importance: float,
    scope: str,
    project_scope: str,
) -> bool:
    """Write a single fact to the vault, skipping if duplicate. Returns True if written."""
    if is_duplicate(db_path, session_id, topic, content):
        logger.debug("Skipping duplicate fact: session=%s topic=%s content_prefix=%r",
                     session_id, topic, content[:50])
        return False

    add_fact_fn(
        content=content,
        session_id=session_id,
        valid_from=valid_from,
        topic=topic,
        memory_type=memory_type,
        confidence=confidence,
        importance=importance,
        scope=scope,
        project_scope=project_scope,
    )
    return True


# ---------------------------------------------------------------------------
# Markdown section extraction helpers
# ---------------------------------------------------------------------------

def _extract_section(text: str, heading: str) -> str:
    """Return the body of a markdown section (## Heading ... until next ##)."""
    # Match heading case-insensitively, handle leading/trailing whitespace
    pattern = rf"^##\s+{re.escape(heading)}\s*$"
    lines = text.splitlines()
    inside = False
    section_lines = []
    for line in lines:
        if re.match(pattern, line, re.IGNORECASE):
            inside = True
            continue
        if inside:
            if re.match(r"^##\s+", line):
                break
            section_lines.append(line)
    return "\n".join(section_lines).strip()


def _bullet_items(text: str) -> list[str]:
    """Extract bullet/list items from a section body (lines starting with -, *, or digit)."""
    items = []
    current = []
    for line in text.splitlines():
        stripped = line.strip()
        if re.match(r"^[-*•]\s+", stripped) or re.match(r"^\d+\.\s+", stripped):
            if current:
                items.append(" ".join(current))
            current = [re.sub(r"^[-*•\d.]\s+", "", stripped)]
        elif stripped and current:
            # Continuation of previous bullet
            current.append(stripped)
        elif not stripped and current:
            items.append(" ".join(current))
            current = []
    if current:
        items.append(" ".join(current))
    return [i for i in items if i.strip()]


def _paragraph_items(text: str, min_len: int = 20) -> list[str]:
    """Split section body into non-empty paragraphs as individual facts."""
    paragraphs = re.split(r"\n{2,}", text)
    return [p.strip() for p in paragraphs if len(p.strip()) >= min_len]


# ---------------------------------------------------------------------------
# Brief extraction (clarify/ artifacts)
# ---------------------------------------------------------------------------

def extract_brief(text: str, session_id: str, valid_from: str) -> list[dict]:
    """Extract facts from a clarify brief."""
    facts = []

    # Non-Goals → scope-exclusion
    non_goals = _extract_section(text, "Non-Goals")
    for item in _bullet_items(non_goals):
        facts.append(dict(
            session_id=session_id,
            topic="scope-exclusion",
            content=item,
            valid_from=valid_from,
            **CATEGORY_FIELDS["scope-exclusion"],
        ))

    # Constraints → owner-constraint
    constraints = _extract_section(text, "Constraints")
    for item in _bullet_items(constraints):
        facts.append(dict(
            session_id=session_id,
            topic="owner-constraint",
            content=item,
            valid_from=valid_from,
            **CATEGORY_FIELDS["owner-constraint"],
        ))

    # Assumptions → design-assumption
    assumptions = _extract_section(text, "Assumptions")
    for item in _bullet_items(assumptions):
        facts.append(dict(
            session_id=session_id,
            topic="design-assumption",
            content=item,
            valid_from=valid_from,
            **CATEGORY_FIELDS["design-assumption"],
        ))

    return facts


# ---------------------------------------------------------------------------
# Dossier extraction (research/ artifacts)
# ---------------------------------------------------------------------------

def extract_dossier(text: str, session_id: str, valid_from: str) -> list[dict]:
    """Extract facts from a research dossier."""
    facts = []

    # Findings → research-finding (each finding sub-section or bullet)
    findings = _extract_section(text, "Findings")
    if findings:
        # Dossiers use ### sub-sections for each finding (Q1, Q2, etc.)
        # Extract each sub-section body as a single finding
        subsections = re.split(r"^###\s+", findings, flags=re.MULTILINE)
        for sub in subsections[1:]:  # skip text before first ###
            # Take the body after the first line (heading)
            lines = sub.splitlines()
            body = "\n".join(lines[1:]).strip()
            if len(body) >= 20:
                # Summarize to first paragraph (synthesis text)
                first_para = re.split(r"\n{2,}", body)[0].strip()
                if len(first_para) >= 20:
                    facts.append(dict(
                        session_id=session_id,
                        topic="research-finding",
                        content=first_para[:500],  # cap length
                        valid_from=valid_from,
                        **CATEGORY_FIELDS["research-finding"],
                    ))
        # Also extract any bullets from the Findings section (some dossiers use flat bullets)
        for item in _bullet_items(findings):
            if len(item) >= 20:
                facts.append(dict(
                    session_id=session_id,
                    topic="research-finding",
                    content=item[:500],
                    valid_from=valid_from,
                    **CATEGORY_FIELDS["research-finding"],
                ))

    # Adjacent Findings → adjacent-finding
    adj = _extract_section(text, "Adjacent Findings")
    for item in _bullet_items(adj) + _paragraph_items(adj):
        facts.append(dict(
            session_id=session_id,
            topic="adjacent-finding",
            content=item[:500],
            valid_from=valid_from,
            **CATEGORY_FIELDS["adjacent-finding"],
        ))

    return facts


# ---------------------------------------------------------------------------
# Spec extraction (specs/ artifacts)
# ---------------------------------------------------------------------------

def extract_spec(text: str, session_id: str, valid_from: str) -> list[dict]:
    """Extract facts from a spec."""
    facts = []

    # Architecture Decision → architecture-decision
    arch = _extract_section(text, "Architecture Decision")
    if not arch:
        arch = _extract_section(text, "4. Architecture Decision")
    if arch:
        # Extract the rationale paragraph (before "Alternatives Considered")
        rationale = re.split(r"###\s+Alternatives Considered", arch)[0].strip()
        if len(rationale) >= 20:
            facts.append(dict(
                session_id=session_id,
                topic="architecture-decision",
                content=rationale[:600],
                valid_from=valid_from,
                **CATEGORY_FIELDS["architecture-decision"],
            ))

        # Alternatives Considered → failed-approach
        alts_match = re.search(r"###\s+Alternatives Considered\s*\n(.*?)(?=\n###|\Z)",
                                arch, re.DOTALL)
        if alts_match:
            for item in _bullet_items(alts_match.group(1)):
                facts.append(dict(
                    session_id=session_id,
                    topic="failed-approach",
                    content=item[:500],
                    valid_from=valid_from,
                    **CATEGORY_FIELDS["failed-approach"],
                ))

    # Risks → risk-mitigation
    risks = _extract_section(text, "Risks")
    if not risks:
        risks = _extract_section(text, "7. Risks")
    for item in _bullet_items(risks) + _paragraph_items(risks, min_len=30):
        facts.append(dict(
            session_id=session_id,
            topic="risk-mitigation",
            content=item[:500],
            valid_from=valid_from,
            **CATEGORY_FIELDS["risk-mitigation"],
        ))

    return facts


# ---------------------------------------------------------------------------
# Main extraction + write
# ---------------------------------------------------------------------------

def extract_and_write(
    artifact_path: str,
    slug: str,
    dry_run: bool = False,
    vault_scripts_path: str = None,
    db_path: str = None,
) -> int:
    """Extract facts from artifact and write to vault. Returns count of facts written."""
    vault_scripts = vault_scripts_path or VAULT_SCRIPTS_PATH
    db = db_path or VAULT_DB_PATH

    # Detect artifact type (raises ValueError for unsupported paths)
    artifact_type = detect_artifact_type(artifact_path)

    # Read the artifact
    p = Path(artifact_path)
    if not p.exists():
        logger.warning("Artifact not found: %s — skipping", artifact_path)
        return 0

    text = p.read_text(encoding="utf-8")
    valid_from = extract_valid_from(artifact_path)
    session_id = f"cortex-{slug}"

    # Extract facts from the artifact
    if artifact_type == "brief":
        facts = extract_brief(text, session_id, valid_from)
    elif artifact_type == "dossier":
        facts = extract_dossier(text, session_id, valid_from)
    elif artifact_type == "spec":
        facts = extract_spec(text, session_id, valid_from)
    else:
        raise ValueError(f"Unknown artifact type: {artifact_type}")

    if dry_run:
        logger.info("Dry-run: would write %d facts for %s/%s", len(facts), session_id, artifact_type)
        for f in facts:
            logger.info("  [%s] %s: %s", f["topic"], f["valid_from"], f["content"][:80])
        return len(facts)

    # Import add_fact from vault (soft-fail if unavailable)
    try:
        if vault_scripts not in sys.path:
            sys.path.insert(0, vault_scripts)
        from fact_store import add_fact  # type: ignore
    except Exception as e:
        logger.warning("Vault unavailable (fact_store import failed: %s) — skipping write", e)
        return 0

    written = 0
    for f in facts:
        try:
            result = write_fact(
                add_fact_fn=add_fact,
                db_path=db,
                session_id=f["session_id"],
                topic=f["topic"],
                content=f["content"],
                valid_from=f["valid_from"],
                memory_type=f["memory_type"],
                confidence=f["confidence"],
                importance=f["importance"],
                scope=SCOPE,
                project_scope=PROJECT_SCOPE,
            )
            if result:
                written += 1
        except Exception as e:
            logger.warning("Failed to write fact (topic=%s): %s", f.get("topic"), e)

    logger.info("Wrote %d/%d facts for session=%s artifact=%s",
                written, len(facts), session_id, artifact_path)
    return written


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Extract typed facts from Cortex artifacts and write to vault."
    )
    parser.add_argument(
        "--artifact",
        required=True,
        metavar="PATH",
        help="Path to the Cortex artifact (clarify brief, research dossier, or spec)",
    )
    parser.add_argument(
        "--slug",
        required=True,
        metavar="SLUG",
        help="Cortex slug (used as session_id suffix: cortex-{slug})",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Log what would be written without calling add_fact()",
    )
    args = parser.parse_args()

    try:
        count = extract_and_write(
            artifact_path=args.artifact,
            slug=args.slug,
            dry_run=args.dry_run,
        )
        print(f"Facts written: {count}")
        sys.exit(0)
    except ValueError as e:
        logger.error("%s", e)
        sys.exit(1)
    except Exception as e:
        logger.error("Unexpected error: %s", e)
        sys.exit(1)


if __name__ == "__main__":
    main()
