#!/usr/bin/env python3
"""
format-eval-results.py — Transform eval-result.json into results-{timestamp}.md
and update eval-status.md.

Usage:
    python3 format-eval-results.py \\
        --result-json <path> \\
        --slug <slug> \\
        --output-dir <dir> \\
        [--eval-status <path>]
"""
import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(description="Format eval results into markdown")
    parser.add_argument("--result-json", required=True, help="Path to eval-result.json")
    parser.add_argument("--slug", required=True, help="Slug for this eval run")
    parser.add_argument("--output-dir", required=True, help="Directory for results-{timestamp}.md")
    parser.add_argument("--eval-status", help="Path to eval-status.md to update (optional)")
    return parser.parse_args()


VERDICT_LABEL = {
    "pass": "PASSED",
    "fail": "FAILED",
    "partial": "PARTIAL",
}

OVERALL_LABEL = {
    "pass": "PASSED",
    "fail": "FAILED",
    "partial": "PARTIAL",
}


def build_results_md(data: dict, slug: str, timestamp: str) -> str:
    overall = data.get("overall_verdict", "fail")
    overall_label = OVERALL_LABEL.get(overall.lower(), overall.upper())
    dimensions = data.get("evaluated_dimensions", [])
    deviations = data.get("deviations", [])

    lines = [
        f"# Eval Results: {slug}",
        "",
        f"**Slug:** {slug}",
        f"**Timestamp:** {timestamp}",
        f"**Eval Plan:** docs/cortex/evals/{slug}/eval-plan.md",
        "",
        "---",
        "",
        "## Results Summary",
        "",
        "| Dimension | Result | Notes |",
        "|-----------|--------|-------|",
    ]

    for dim in dimensions:
        name = dim.get("dimension", "Unknown")
        verdict = dim.get("verdict", "fail")
        label = VERDICT_LABEL.get(verdict.lower(), verdict.upper())
        finding = dim.get("finding", "")
        # Truncate finding to fit in table cell
        notes = finding[:120].replace("|", "\\|")
        lines.append(f"| {name} | {label} | {notes} |")

    lines.append("")
    lines.append(f"**Overall: {overall_label}**")
    lines.append("")
    lines.append("---")
    lines.append("")
    lines.append("## Detailed Results")
    lines.append("")

    for dim in dimensions:
        name = dim.get("dimension", "Unknown")
        verdict = dim.get("verdict", "fail")
        label = VERDICT_LABEL.get(verdict.lower(), verdict.upper())
        finding = dim.get("finding", "")
        failures = dim.get("failures", [])
        fixtures = dim.get("fixtures_tested", [])

        lines.append(f"### {name} ({label})")
        lines.append("")
        lines.append(finding)
        lines.append("")

        if fixtures:
            lines.append(f"**Fixtures tested:** {', '.join(fixtures)}")
            lines.append("")

        if failures:
            lines.append("**Failures:**")
            for f in failures:
                criterion = f.get("criterion", "")
                evidence = f.get("evidence", "")
                lines.append(f"- {criterion}: {evidence}")
            lines.append("")

    if deviations:
        lines.append("### Deviations")
        lines.append("")
        for d in deviations:
            lines.append(f"- {d}")
        lines.append("")

    return "\n".join(lines)


def update_eval_status(eval_status_path: Path, slug: str, timestamp: str, data: dict) -> None:
    """Append or update dimension rows in eval-status.md."""
    dimensions = data.get("evaluated_dimensions", [])

    # Read existing content or start fresh
    if eval_status_path.exists():
        content = eval_status_path.read_text()
    else:
        content = f"# Eval Status\n\n**slug:** {slug}\n\n**timestamp_updated:** {timestamp}\n\n## Eval Dimensions\n\n"

    # Build the new dimension table rows for this slug
    new_rows = []
    for dim in dimensions:
        name = dim.get("dimension", "Unknown")
        verdict = dim.get("verdict", "fail")
        status = "PASS" if verdict.lower() == "pass" else ("PARTIAL" if verdict.lower() == "partial" else "FAIL")
        score = "1.0" if verdict.lower() == "pass" else ("0.5" if verdict.lower() == "partial" else "0.0")
        new_rows.append(f"| {name} | {score} | {status} | {slug} | {timestamp} |")

    # If eval-status.md already has a dimension table, update it
    if "## Eval Dimensions" in content:
        # Find the section and append/update rows
        header_end = content.find("## Eval Dimensions") + len("## Eval Dimensions")
        # Look for an existing table for this slug and replace rows
        slug_pattern = f"| {slug} |"
        if slug_pattern in content:
            # Remove existing rows for this slug
            existing_lines = content.splitlines()
            filtered_lines = [l for l in existing_lines if slug_pattern not in l]
            content = "\n".join(filtered_lines) + "\n"

        # Ensure the Eval Dimensions section has a table header
        if "| Dimension |" not in content:
            insert_pos = content.find("## Eval Dimensions") + len("## Eval Dimensions\n")
            table_header = "\n| Dimension | Score | Status | Slug | Timestamp |\n|-----------|-------|--------|------|----------|\n"
            content = content[:insert_pos] + table_header + content[insert_pos:]

        # Append new rows before next section or at end
        content = content.rstrip()
        for row in new_rows:
            content += f"\n{row}"
        content += "\n"
    else:
        # No existing table — create from scratch
        content = (
            f"# Eval Status\n\n"
            f"**slug:** {slug}\n\n"
            f"**timestamp_updated:** {timestamp}\n\n"
            f"**contract_path:** (no active contract)\n\n"
            f"## Eval Dimensions\n\n"
            f"| Dimension | Score | Status | Slug | Timestamp |\n"
            f"|-----------|-------|--------|------|----------|\n"
        )
        for row in new_rows:
            content += f"{row}\n"

    eval_status_path.write_text(content)


def main():
    args = parse_args()
    result_json_path = Path(args.result_json)
    output_dir = Path(args.output_dir)
    slug = args.slug

    if not result_json_path.exists():
        print(f"Error: result-json not found: {result_json_path}", file=sys.stderr)
        sys.exit(1)

    try:
        data = json.loads(result_json_path.read_text())
    except json.JSONDecodeError as e:
        print(f"Error: malformed JSON in {result_json_path}: {e}", file=sys.stderr)
        sys.exit(1)

    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")

    # Write results-{timestamp}.md
    output_dir.mkdir(parents=True, exist_ok=True)
    results_path = output_dir / f"results-{timestamp}.md"
    results_path.write_text(build_results_md(data, slug, timestamp))
    print(f"Written: {results_path}")

    # Update eval-status.md if requested
    if args.eval_status:
        eval_status_path = Path(args.eval_status)
        eval_status_path.parent.mkdir(parents=True, exist_ok=True)
        update_eval_status(eval_status_path, slug, timestamp, data)
        print(f"Updated: {eval_status_path}")


if __name__ == "__main__":
    main()
