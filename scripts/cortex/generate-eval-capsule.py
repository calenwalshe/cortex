#!/usr/bin/env python3
"""
generate-eval-capsule.py — Assemble an eval capsule from an eval-plan.md.

The capsule is piped to codex-eval-executor.sh via stdin for independent evaluation.

Usage:
    python3 generate-eval-capsule.py --eval-plan <path> --output <path> [--slug <slug>]

Validation:
    The eval-plan.md MUST contain a ## Rejection Rules section with ≥3 bullet/numbered items.
    If validation fails, exits non-zero with a descriptive error.
"""
import argparse
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

MAX_LINES_PER_FILE = 200
TRUNCATION_MARKER = "[... truncated at 200 lines — full file omitted for capsule size]"


def parse_args():
    parser = argparse.ArgumentParser(description="Generate eval capsule from eval-plan.md")
    parser.add_argument("--eval-plan", required=True, help="Path to eval-plan.md")
    parser.add_argument("--output", required=True, help="Output path for capsule.md")
    parser.add_argument("--slug", help="Slug override (default: read from eval-plan.md)")
    return parser.parse_args()


def extract_field(text: str, field: str) -> str:
    match = re.search(rf"\*\*{re.escape(field)}:\*\*\s*(.+)", text)
    return match.group(1).strip() if match else ""


def extract_section(text: str, header: str) -> str:
    """Extract content of a ## section (not including the header line itself)."""
    match = re.search(
        rf"^## {re.escape(header)}\s*\n(.*?)(?=^##\s|\Z)",
        text,
        re.DOTALL | re.MULTILINE,
    )
    return match.group(1).strip() if match else ""


def count_list_items(section_text: str) -> int:
    """Count numbered or bulleted list items in a text block."""
    items = re.findall(r"^[\s]*[-*\d]+[.)]\s+\S", section_text, re.MULTILINE)
    return len(items)


def validate_rejection_rules(plan_text: str) -> None:
    """
    Validate that the eval-plan has a ## Rejection Rules section with ≥3 items.
    Raises ValueError if validation fails.
    """
    section = extract_section(plan_text, "Rejection Rules")
    if not section:
        raise ValueError(
            "ValidationError: eval-plan.md is missing the ## Rejection Rules section.\n"
            "Every eval capsule must have ≥3 binary, objective rejection criteria.\n"
            "Add a ## Rejection Rules section with at least 3 numbered or bulleted items."
        )
    item_count = count_list_items(section)
    if item_count < 3:
        raise ValueError(
            f"ValidationError: ## Rejection Rules section has {item_count} item(s), but ≥3 are required.\n"
            "Each rejection rule must be a hard-fail binary criterion, e.g.:\n"
            '  1. If any test exits non-zero, overall_verdict MUST be "fail"\n'
            '  2. If any deliverable file is missing, overall_verdict MUST be "fail"\n'
            '  3. If any import fails, overall_verdict MUST be "fail"'
        )


def is_test_file(path_str: str) -> bool:
    """Test files (test/test_*.py or test/*.test.sh) are included without line cap."""
    p = Path(path_str)
    return re.match(r"test_.*\.py$", p.name) is not None or p.name.endswith(".test.sh")


def embed_file(file_path_str: str, base_dir: Path = None) -> str:
    """
    Read a file and embed its content in the capsule.
    - Test files: included in full
    - Other files: capped at MAX_LINES_PER_FILE lines
    Returns a fenced code block with the file path as header.
    """
    # Resolve path: try absolute, then relative to base_dir
    p = Path(file_path_str)
    if not p.is_absolute() and base_dir:
        candidate = base_dir / p
        if candidate.exists():
            p = candidate
    if not p.exists():
        return f"### `{file_path_str}`\n\n<!-- File not found at: {file_path_str} -->\n"

    try:
        content = p.read_text(errors="replace")
    except OSError as e:
        return f"### `{file_path_str}`\n\n<!-- Could not read file: {e} -->\n"

    lines = content.splitlines(keepends=True)
    truncated = False
    if not is_test_file(file_path_str) and len(lines) > MAX_LINES_PER_FILE:
        lines = lines[:MAX_LINES_PER_FILE]
        truncated = True

    ext = p.suffix.lstrip(".")
    body = "".join(lines)
    block = f"### `{file_path_str}`\n\n```{ext}\n{body}\n```"
    if truncated:
        block += f"\n\n> {TRUNCATION_MARKER}"
    return block


def extract_file_references(fixtures_section: str) -> list[str]:
    """
    Extract file path references from a Fixtures section.
    Looks for lines starting with '- ' that contain a path-like string.
    Path-like: contains '/' or ends in a known code/config extension.
    """
    paths = []
    code_extensions = {".py", ".sh", ".js", ".ts", ".yaml", ".yml", ".json", ".md", ".toml"}
    for line in fixtures_section.splitlines():
        line = line.strip()
        if not line.startswith("- "):
            continue
        # Extract potential path: first token after '- ' that looks like a path
        tokens = line[2:].split()
        if not tokens:
            continue
        candidate = tokens[0].strip("`'\"")
        p = Path(candidate)
        # Accept if it has a known extension or contains a directory separator
        if p.suffix in code_extensions or "/" in candidate:
            paths.append(candidate)
    return paths


def build_capsule(plan_text: str, slug: str, eval_plan_path: str, base_dir: Path) -> str:
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")

    approved_section = extract_section(plan_text, "Approved Dimensions")
    fixtures_section = extract_section(plan_text, "Fixtures Per Dimension")
    thresholds_section = extract_section(plan_text, "Thresholds Per Dimension")
    rejection_rules_section = extract_section(plan_text, "Rejection Rules")

    # Collect all file references from fixtures
    file_refs = extract_file_references(fixtures_section)
    deliverable_blocks = []
    for ref in file_refs:
        deliverable_blocks.append(embed_file(ref, base_dir))

    deliverable_files_content = "\n\n".join(deliverable_blocks) if deliverable_blocks else "<!-- No file references found in Fixtures sections -->"

    lines = [
        f"# Eval Capsule: {slug}",
        "",
        f"**Slug:** {slug}",
        f"**Eval Plan:** {eval_plan_path}",
        f"**Generated At:** {timestamp}",
        "",
        "---",
        "",
        "## Approved Dimensions",
        "",
        approved_section,
        "",
        "---",
        "",
        "## Fixtures Per Dimension",
        "",
        fixtures_section,
        "",
        "---",
        "",
        "## Thresholds Per Dimension",
        "",
        thresholds_section,
        "",
        "---",
        "",
        "## Rejection Rules",
        "",
        rejection_rules_section,
        "",
        "---",
        "",
        "## Deliverable Files",
        "",
        deliverable_files_content,
        "",
    ]
    return "\n".join(lines)


def main():
    args = parse_args()
    eval_plan_path = Path(args.eval_plan)
    output_path = Path(args.output)

    if not eval_plan_path.exists():
        print(f"Error: eval-plan file not found: {eval_plan_path}", file=sys.stderr)
        sys.exit(1)

    plan_text = eval_plan_path.read_text()

    slug = args.slug or extract_field(plan_text, "Slug") or eval_plan_path.parent.name

    # Validation: Rejection Rules
    try:
        validate_rejection_rules(plan_text)
    except ValueError as e:
        print(str(e), file=sys.stderr)
        sys.exit(1)

    # Base dir for resolving relative file paths: project root (parent of the eval-plan dir's parent)
    # eval-plan is at docs/cortex/evals/{slug}/eval-plan.md → project root is 4 levels up
    base_dir = eval_plan_path.parent
    # Try to find project root by looking for .cortex/state.json
    candidate = eval_plan_path.parent
    for _ in range(6):
        if (candidate / ".cortex" / "state.json").exists():
            base_dir = candidate
            break
        candidate = candidate.parent

    capsule_text = build_capsule(plan_text, slug, str(eval_plan_path), base_dir)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(capsule_text)
    print(f"Written: {output_path}")
    print(f"Slug: {slug}")


if __name__ == "__main__":
    main()
