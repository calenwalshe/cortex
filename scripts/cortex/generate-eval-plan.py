#!/usr/bin/env python3
"""
generate-eval-plan.py — Transform an eval-proposal.md into an eval-plan.md.

Transformation rules:
1. Filter to only approved dimensions (remove EXCLUDED ones).
2. Copy Fixtures and Thresholds verbatim for approved dimensions only.
3. Remove Rubrics and Failure Taxonomy sections.
4. Preserve Run Instructions section if present in proposal.
5. Produce eval-plan.md with Approved Dimensions list + per-dimension sections.

Usage:
    python3 generate-eval-plan.py --proposal <path> --output <path> [--force]
"""
import argparse
import re
import sys
from datetime import datetime, timezone
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(description="Transform eval-proposal.md to eval-plan.md")
    parser.add_argument("--proposal", required=True, help="Path to eval-proposal.md")
    parser.add_argument("--output", required=True, help="Output path for eval-plan.md")
    parser.add_argument("--force", action="store_true", help="Overwrite existing output file")
    return parser.parse_args()


def extract_field(text: str, field: str) -> str:
    """Extract a bold field value from markdown like '**Field:** value'."""
    match = re.search(rf"\*\*{re.escape(field)}:\*\*\s*(.+)", text)
    return match.group(1).strip() if match else ""


def parse_proposed_dimensions(text: str) -> list[dict]:
    """
    Parse the ## Proposed Dimensions section.
    Returns list of dicts with keys: name, applies_because, excluded, approval_required.
    A dimension is EXCLUDED if its 'Applies because:' text starts with 'EXCLUDED'.
    """
    # Find the Proposed Dimensions section
    section_match = re.search(
        r"## Proposed Dimensions\s*\n(.*?)(?=^##\s|\Z)",
        text,
        re.DOTALL | re.MULTILINE,
    )
    if not section_match:
        return []

    section = section_match.group(1)
    # Split by dimension headings: ### N. Name
    dim_blocks = re.split(r"(?=###\s+\d+\.\s+)", section)
    dimensions = []
    for block in dim_blocks:
        block = block.strip()
        if not block:
            continue
        # Extract name from heading: ### N. Dimension Name
        name_match = re.match(r"###\s+\d+\.\s+(.+)", block)
        if not name_match:
            continue
        name = name_match.group(1).strip()
        applies_match = re.search(r"\*\*Applies because:\*\*\s*(.+)", block)
        applies_because = applies_match.group(1).strip() if applies_match else ""
        excluded = applies_because.upper().startswith("EXCLUDED")
        approval_match = re.search(r"\*\*approval_required:\*\*\s*(\w+)", block)
        approval_required = approval_match.group(1).strip() if approval_match else "false"
        dimensions.append(
            {
                "name": name,
                "applies_because": applies_because,
                "excluded": excluded,
                "approval_required": approval_required,
            }
        )
    return dimensions


def extract_subsections_for_dimensions(text: str, section_header: str, approved_names: list[str]) -> str:
    """
    Extract subsections (### Sub: DimName) from a given top-level ## section,
    returning only those whose DimName matches an approved dimension.
    """
    section_match = re.search(
        rf"^## {re.escape(section_header)}\s*\n(.*?)(?=^##\s|\Z)",
        text,
        re.DOTALL | re.MULTILINE,
    )
    if not section_match:
        return ""

    section = section_match.group(1)
    # Split into subsections: ### Header: DimName
    subsection_pattern = re.compile(r"(###\s+[^:]+:\s+.+?)(?=###\s+[^:]+:\s+|\Z)", re.DOTALL)
    result_parts = []
    for match in subsection_pattern.finditer(section):
        block = match.group(1).strip()
        # Check heading: ### Keyword: Dim Name
        heading_match = re.match(r"###\s+\w+:\s+(.+)", block)
        if not heading_match:
            continue
        dim_name = heading_match.group(1).strip()
        # Check if this dimension is approved (case-insensitive match)
        if any(dim_name.lower() == approved.lower() for approved in approved_names):
            result_parts.append(block)

    return "\n\n".join(result_parts)


def extract_run_instructions(text: str) -> str:
    """Extract the ## Run Instructions section if present."""
    match = re.search(
        r"^## Run Instructions\s*\n(.*?)(?=^##\s|\Z)",
        text,
        re.DOTALL | re.MULTILINE,
    )
    if not match:
        return ""
    return match.group(1).rstrip()


def build_plan(proposal_text: str, slug: str, timestamp: str, approved_dims: list[dict]) -> str:
    """Build the eval-plan.md content."""
    approved_names = [d["name"] for d in approved_dims]

    # Approved By line
    any_approval_required = any(
        d["approval_required"].lower() == "true" for d in approved_dims
    )
    if any_approval_required:
        approved_by = "project lead"
    else:
        approved_by = "auto-approved (no approval_required dimensions)"

    lines = [
        f"# Eval Plan: {slug}",
        "",
        f"**Slug:** {slug}",
        f"**Timestamp:** {timestamp}",
        f"**Approved By:** {approved_by}",
        f"**Approved At:** {timestamp}",
        "",
        "---",
        "",
        "## Approved Dimensions",
        "",
    ]
    for name in approved_names:
        lines.append(f"- {name}")
    lines.append("")
    lines.append("---")
    lines.append("")

    # Fixtures per Dimension
    fixtures = extract_subsections_for_dimensions(proposal_text, "Fixtures", approved_names)
    if fixtures:
        lines.append("## Fixtures Per Dimension")
        lines.append("")
        lines.append(fixtures)
        lines.append("")
        lines.append("---")
        lines.append("")

    # Thresholds per Dimension
    thresholds = extract_subsections_for_dimensions(proposal_text, "Thresholds", approved_names)
    if thresholds:
        lines.append("## Thresholds Per Dimension")
        lines.append("")
        lines.append(thresholds)
        lines.append("")
        lines.append("---")
        lines.append("")

    # Run Instructions (preserved verbatim if present)
    run_instructions = extract_run_instructions(proposal_text)
    if run_instructions:
        lines.append("## Run Instructions")
        lines.append("")
        lines.append(run_instructions)
        lines.append("")
        lines.append("---")
        lines.append("")

    # Results placeholder
    lines.append("## Results")
    lines.append("")
    lines.append(f"<!-- Results written to docs/cortex/evals/{slug}/results-<timestamp>.md -->")
    lines.append("")

    return "\n".join(lines)


def main():
    args = parse_args()
    proposal_path = Path(args.proposal)
    output_path = Path(args.output)

    if not proposal_path.exists():
        print(f"Error: proposal file not found: {proposal_path}", file=sys.stderr)
        sys.exit(1)

    # Overwrite guard: refuse to overwrite existing plan without --force
    if output_path.exists() and not args.force:
        print(
            f"Error: output file already exists: {output_path}\n"
            "Use --force to overwrite an existing eval plan.",
            file=sys.stderr,
        )
        sys.exit(1)

    proposal_text = proposal_path.read_text()

    slug = extract_field(proposal_text, "Slug")
    if not slug:
        # Try to derive from filename
        slug = proposal_path.parent.name

    timestamp = extract_field(proposal_text, "Timestamp")
    if not timestamp:
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")

    dimensions = parse_proposed_dimensions(proposal_text)
    if not dimensions:
        print("Error: no dimensions found in ## Proposed Dimensions section", file=sys.stderr)
        sys.exit(1)

    approved = [d for d in dimensions if not d["excluded"]]
    if not approved:
        print("Error: no approved dimensions found (all excluded)", file=sys.stderr)
        sys.exit(1)

    plan_text = build_plan(proposal_text, slug, timestamp, approved)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(plan_text)
    print(f"Written: {output_path}")
    print(f"Approved dimensions ({len(approved)}): {', '.join(d['name'] for d in approved)}")


if __name__ == "__main__":
    main()
