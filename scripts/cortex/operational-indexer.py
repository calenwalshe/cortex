#!/usr/bin/env python3
"""
operational-indexer.py — Cortex operational map layer indexer

Captures Edit/Write PostToolUse events into a rolling JSONL ledger so that
--summary mode can aggregate hotspots and co-change pairs.

Modes:
  --hook      PostToolUse hook mode: filter Edit/Write, read slug, append
              JSONL entry to .cortex/edit-ledger.jsonl, prune to 500
  --summary   Aggregate ledger into hotspots and co_change_pairs JSON;
              outputs valid JSON (exit 0 always, soft-fail when ledger absent)

Flags:
  --ledger      Override ledger path (default: .cortex/edit-ledger.jsonl)
  --state       Override state.json path (default: .cortex/state.json)
  --min-count N Minimum edit_count threshold for hotspots (default: 2)
  --top-files N Max hotspot entries (default: 20; 0 = unlimited)
  --top-pairs N Max co_change_pairs entries (default: 20; 0 = unlimited)

Always exits 0 — never blocks Claude.
"""

import argparse
import collections
import datetime
import itertools
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

    Reads all ledger entries, computes per-file edit counts (hotspots) and
    per-pair session co-occurrence counts (co_change_pairs).
    """
    ledger_path = args.ledger
    min_count: int = args.min_count
    top_files: int = args.top_files
    top_pairs: int = args.top_pairs

    as_of = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    caveat = (
        "co-change pairs are session-scoped; /clear within a task will split "
        "the session and undercount coupling"
    )

    # Soft-fail when ledger is absent
    if not os.path.exists(ledger_path):
        result = {
            "hotspots": [],
            "co_change_pairs": [],
            "entry_count": 0,
            "as_of": as_of,
            "caveat": caveat,
            "ledger_absent": True,
        }
        print(json.dumps(result, indent=2))
        return

    raw_lines = read_ledger(ledger_path)
    entry_count = len(raw_lines)

    # Parse entries — skip malformed lines silently
    file_counter: collections.Counter = collections.Counter()
    session_files: collections.defaultdict = collections.defaultdict(set)

    for line in raw_lines:
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        fp = str(entry.get("file_path", ""))
        sid = str(entry.get("session_id", ""))
        if fp:
            file_counter[fp] += 1
        if fp and sid:
            session_files[sid].add(fp)

    # Build hotspots: filter by min_count, sort desc
    hotspots = [
        {"file_path": fp, "edit_count": cnt}
        for fp, cnt in file_counter.most_common()
        if cnt >= min_count
    ]
    # most_common() already returns desc; slice if top_files > 0
    if top_files > 0:
        hotspots = hotspots[:top_files]

    # Build co_change_pairs: enumerate unordered pairs per session, count sessions
    pair_counter: collections.Counter = collections.Counter()
    for sid, files in session_files.items():
        if len(files) < 2:
            continue
        for a, b in itertools.combinations(sorted(files), 2):
            pair_counter[(a, b)] += 1

    co_change_pairs = [
        {"files": list(pair), "session_count": cnt}
        for pair, cnt in pair_counter.most_common()
    ]
    if top_pairs > 0:
        co_change_pairs = co_change_pairs[:top_pairs]

    result = {
        "hotspots": hotspots,
        "co_change_pairs": co_change_pairs,
        "entry_count": entry_count,
        "as_of": as_of,
        "caveat": caveat,
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
    parser.add_argument(
        "--min-count",
        metavar="N",
        type=int,
        default=2,
        dest="min_count",
        help="Minimum edit_count to include in hotspots (default: 2)",
    )
    parser.add_argument(
        "--top-files",
        metavar="N",
        type=int,
        default=20,
        dest="top_files",
        help="Max hotspot entries (default: 20; 0 = unlimited)",
    )
    parser.add_argument(
        "--top-pairs",
        metavar="N",
        type=int,
        default=20,
        dest="top_pairs",
        help="Max co_change_pairs entries (default: 20; 0 = unlimited)",
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
