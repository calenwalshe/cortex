"""Bet record JSONL writer, reader, and validator.

Schema matches spec AD-2: full lifecycle from market selection through post-mortem.
Storage: append-only JSONL at data/bets/bets.jsonl (one JSON object per line).
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Any, Optional


class ValidationError(Exception):
    """Raised when a bet record fails schema validation."""


# ---------------------------------------------------------------------------
# Required fields — must always be present and non-None
# ---------------------------------------------------------------------------
REQUIRED_FIELDS = {
    "bet_id",
    "market_ticker",
    "market_question",
    "entry_timestamp",
    "research_artifact",
    "your_probability",
    "market_price_at_entry",
    "edge",
    "position_side",
    "stake_cents",
    "order_type",
}

# All fields in the schema (required + optional/nullable)
ALL_FIELDS = REQUIRED_FIELDS | {
    "fill_price",
    "fill_timestamp",
    "resolution_outcome",
    "resolution_timestamp",
    "pnl_cents",
    "brier_contribution",
    "log_loss_contribution",
    "failure_codes",
    "postmortem_path",
    "monitoring_updates",
}

VALID_SIDES = {"yes", "no"}
VALID_ORDER_TYPES = {"limit", "market"}


# ---------------------------------------------------------------------------
# BetRecord dataclass
# ---------------------------------------------------------------------------
@dataclass
class BetRecord:
    """A single prediction market bet record matching spec AD-2."""

    bet_id: str
    market_ticker: str
    market_question: str
    entry_timestamp: str
    research_artifact: str
    your_probability: float
    market_price_at_entry: float
    edge: float
    position_side: str
    stake_cents: int
    order_type: str
    fill_price: Optional[float] = None
    fill_timestamp: Optional[str] = None
    resolution_outcome: Optional[str] = None
    resolution_timestamp: Optional[str] = None
    pnl_cents: Optional[int] = None
    brier_contribution: Optional[float] = None
    log_loss_contribution: Optional[float] = None
    failure_codes: list = field(default_factory=list)
    postmortem_path: Optional[str] = None
    monitoring_updates: list = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        """Serialize to a plain dict suitable for JSON encoding."""
        return asdict(self)


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
def validate_record(data: dict[str, Any]) -> None:
    """Validate a bet record dict against the AD-2 schema.

    Raises ValidationError with a message identifying the offending field.
    """
    # Check required fields present
    for f in REQUIRED_FIELDS:
        if f not in data:
            raise ValidationError(f"Missing required field: {f}")
        if data[f] is None:
            raise ValidationError(f"Required field cannot be None: {f}")

    # Check no unknown fields
    for f in data:
        if f not in ALL_FIELDS:
            raise ValidationError(f"Unknown field: {f}")

    # Probability range [0, 1]
    _check_probability_range(data, "your_probability")
    _check_probability_range(data, "market_price_at_entry")
    if data.get("fill_price") is not None:
        _check_probability_range(data, "fill_price")

    # Stake must be positive
    if data["stake_cents"] <= 0:
        raise ValidationError(
            f"stake_cents must be positive, got {data['stake_cents']}"
        )

    # Enum checks
    if data["position_side"] not in VALID_SIDES:
        raise ValidationError(
            f"position_side must be one of {VALID_SIDES}, got '{data['position_side']}'"
        )
    if data["order_type"] not in VALID_ORDER_TYPES:
        raise ValidationError(
            f"order_type must be one of {VALID_ORDER_TYPES}, got '{data['order_type']}'"
        )

    # List fields
    if not isinstance(data.get("failure_codes", []), list):
        raise ValidationError("failure_codes must be a list")
    if not isinstance(data.get("monitoring_updates", []), list):
        raise ValidationError("monitoring_updates must be a list")


def _check_probability_range(data: dict, field_name: str) -> None:
    val = data[field_name]
    if not isinstance(val, (int, float)):
        raise ValidationError(f"{field_name} must be numeric, got {type(val).__name__}")
    if val < 0.0 or val > 1.0:
        raise ValidationError(f"{field_name} must be in [0, 1], got {val}")


# ---------------------------------------------------------------------------
# JSONL Writer / Reader
# ---------------------------------------------------------------------------
def write_record(record: BetRecord, path: str) -> None:
    """Append a single bet record as one JSON line to the JSONL file.

    Creates parent directories if they don't exist.
    """
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)

    data = record.to_dict()
    validate_record(data)

    with open(p, "a") as f:
        f.write(json.dumps(data, separators=(",", ":")) + "\n")


def read_records(path: str) -> list[BetRecord]:
    """Read all bet records from a JSONL file.

    Returns an empty list if the file doesn't exist or is empty.
    Validates each record on read — raises ValidationError for bad data.
    """
    p = Path(path)
    if not p.exists():
        return []

    records = []
    for line_num, line in enumerate(p.read_text().splitlines(), start=1):
        line = line.strip()
        if not line:
            continue
        try:
            data = json.loads(line)
        except json.JSONDecodeError as e:
            raise ValidationError(f"Invalid JSON on line {line_num}: {e}")

        validate_record(data)
        records.append(BetRecord(**data))

    return records
