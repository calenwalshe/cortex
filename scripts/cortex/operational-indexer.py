#!/usr/bin/env python3
"""
operational-indexer.py — Cortex operational map layer indexer

Captures Edit/Write PostToolUse events into a rolling JSONL ledger so that
--summary mode can aggregate hotspots and co-change pairs.

Modes:
  --hook      PostToolUse hook mode: filter Edit/Write, read slug, append
              JSONL entry to .cortex/edit-ledger.jsonl, prune to 500
  --summary   Aggregate ledger into hotspots and co_change_pairs JSON
              (stub placeholder — implemented in Plan 02)

Flags:
  --ledger    Override ledger path (default: .cortex/edit-ledger.jsonl)
  --state     Override state.json path (default: .cortex/state.json)

Always exits 0 — never blocks Claude.
"""

import argparse
import datetime
import json
import os
import sys

CORTEX_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DEFAULT_LEDGER = os.path.join(CORTEX_ROOT, ".cortex", "edit-ledger.jsonl")
DEFAULT_STATE = os.path.join(CORTEX_ROOT, ".cortex", "state.json")

MAX_ENTRIES = 500
WRITE_TOOLS = frozenset({"Edit", "Write"})


def read_slug(state_path: str) -> str:
    """Read slug from .cortex/state.json. Returns '' on any failure."""
    try:
        with open(state_path, encoding="utf-8") as f:
            data = json.load(f)
        return str(data.get("slug", ""))
    except Exception:
        return ""


def read_ledger(ledger_path: str) -> list[str]:
    """Read all non-empty lines from the ledger. Returns [] if absent or error."""
    try:
        with open(ledger_path, encoding="utf-8") as f:
            return [line for line in f if line.strip()]
    except FileNotFoundError:
        return []
    except Exception as e:
        print(f"WARNING: could not read ledger {ledger_path}: {e}", file=sys.stderr)
        return []


def write_ledger(ledger_path: str, lines: list[str]) -> None:
    """Write lines to the ledger file. Overwrites the file."""
    ledger_dir = os.path.dirname(ledger_path)
    if ledger_dir:
        os.makedirs(ledger_dir, exist_ok=True)
    with open(ledger_path, "w", encoding="utf-8") as f:
        f.writelines(lines)


def append_and_prune(ledger_path: str, entry: dict) -> None:
    """Append one entry to the ledger and prune to MAX_ENTRIES if needed."""
    new_line = json.dumps(entry) + "\n"
    lines = read_ledger(ledger_path)
    lines.append(new_line)
    if len(lines) > MAX_ENTRIES:
        lines = lines[-MAX_ENTRIES:]
    write_ledger(ledger_path, lines)


def cmd_hook(args: argparse.Namespace) -> None:
    """PostToolUse hook mode — reads JSON from stdin, appends JSONL entry."""
    ledger_path = args.ledger
    state_path = args.state

    # Read payload from stdin (non-blocking with 2s timeout for safety)
    try:
        import select
        payload: dict = {}
        if select.select([sys.stdin], [], [], 2)[0]:
            raw = sys.stdin.read()
            if raw.strip():
                payload = json.loads(raw)
    except Exception as e:
        print(f"WARNING: could not read stdin payload: {e}", file=sys.stderr)
        return

    tool_name = str(payload.get("tool_name", ""))

    # Filter: only proceed for Edit or Write
    if tool_name not in WRITE_TOOLS:
        return

    session_id = str(payload.get("session_id", ""))
    file_path = str((payload.get("tool_input") or {}).get("file_path", ""))
    slug = read_slug(state_path)
    timestamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    entry = {
        "timestamp": timestamp,
        "session_id": session_id,
        "file_path": file_path,
        "tool_name": tool_name,
        "slug": slug,
    }

    try:
        append_and_prune(ledger_path, entry)
    except Exception as e:
        print(f"WARNING: could not write ledger: {e}", file=sys.stderr)


def cmd_summary(args: argparse.Namespace) -> None:
    """Summary mode — aggregate ledger into hotspots and co_change_pairs.

    Plan 02 will implement this fully. For now, output a valid stub so that
    --summary does not crash.
    """
    result = {
        "hotspots": [],
        "co_change_pairs": [],
        "entry_count": 0,
        "as_of": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "caveat": (
            "co-change pairs are session-scoped; /clear within a task will split "
            "the session and undercount coupling"
        ),
    }
    print(json.dumps(result, indent=2))


def main() -> None:
    parser = argparse.ArgumentParser(description="Cortex operational indexer")

    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--hook", action="store_true", help="PostToolUse hook mode (reads stdin JSON)")
    group.add_argument("--summary", action="store_true", help="Aggregate ledger into JSON summary")

    parser.add_argument(
        "--ledger",
        metavar="PATH",
        default=DEFAULT_LEDGER,
        help="Override ledger path (default: .cortex/edit-ledger.jsonl)",
    )
    parser.add_argument(
        "--state",
        metavar="PATH",
        default=DEFAULT_STATE,
        help="Override state.json path (default: .cortex/state.json)",
    )

    args = parser.parse_args()

    try:
        if args.hook:
            cmd_hook(args)
        elif args.summary:
            cmd_summary(args)
    except Exception as e:
        print(f"WARNING: operational-indexer unexpected error: {e}", file=sys.stderr)

    sys.exit(0)


if __name__ == "__main__":
    main()
