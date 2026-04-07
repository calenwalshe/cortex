"""Tests for bet record JSONL schema — writer, reader, validator.

TDD RED phase: these tests define the expected behavior of records.py.
"""

import json
import os
import tempfile
import uuid
from datetime import datetime, timezone
from pathlib import Path

import pytest

# Import will fail until records.py is implemented (RED phase)
from scripts.kalshi.records import (
    BetRecord,
    ValidationError,
    read_records,
    validate_record,
    write_record,
)


def _make_record(**overrides) -> dict:
    """Factory for a valid bet record dict."""
    base = {
        "bet_id": str(uuid.uuid4()),
        "market_ticker": "KXHIGHNY-26APR07-T50",
        "market_question": "Will the high temperature in NYC exceed 50F on April 7?",
        "entry_timestamp": "2026-04-06T14:30:00Z",
        "research_artifact": "data/research/KXHIGHNY-26APR07-T50/research.md",
        "your_probability": 0.72,
        "market_price_at_entry": 0.65,
        "edge": 0.07,
        "position_side": "yes",
        "stake_cents": 500,
        "order_type": "limit",
        "fill_price": None,
        "fill_timestamp": None,
        "resolution_outcome": None,
        "resolution_timestamp": None,
        "pnl_cents": None,
        "brier_contribution": None,
        "log_loss_contribution": None,
        "failure_codes": [],
        "postmortem_path": None,
        "monitoring_updates": [],
    }
    base.update(overrides)
    return base


class TestBetRecord:
    """Test BetRecord dataclass construction and serialization."""

    def test_create_from_dict(self):
        data = _make_record()
        record = BetRecord(**data)
        assert record.bet_id == data["bet_id"]
        assert record.market_ticker == "KXHIGHNY-26APR07-T50"
        assert record.your_probability == 0.72

    def test_to_dict_round_trip(self):
        data = _make_record()
        record = BetRecord(**data)
        as_dict = record.to_dict()
        assert as_dict == data

    def test_all_spec_fields_present(self):
        """Verify the schema matches spec AD-2 exactly."""
        expected_fields = {
            "bet_id", "market_ticker", "market_question", "entry_timestamp",
            "research_artifact", "your_probability", "market_price_at_entry",
            "edge", "position_side", "stake_cents", "order_type",
            "fill_price", "fill_timestamp", "resolution_outcome",
            "resolution_timestamp", "pnl_cents", "brier_contribution",
            "log_loss_contribution", "failure_codes", "postmortem_path",
            "monitoring_updates",
        }
        data = _make_record()
        record = BetRecord(**data)
        actual_fields = set(record.to_dict().keys())
        assert actual_fields == expected_fields


class TestValidation:
    """Test schema validation rejects bad data."""

    def test_valid_record_passes(self):
        data = _make_record()
        # Should not raise
        validate_record(data)

    def test_missing_required_field_rejected(self):
        data = _make_record()
        del data["market_ticker"]
        with pytest.raises(ValidationError, match="market_ticker"):
            validate_record(data)

    def test_missing_bet_id_rejected(self):
        data = _make_record()
        del data["bet_id"]
        with pytest.raises(ValidationError, match="bet_id"):
            validate_record(data)

    def test_probability_below_zero_rejected(self):
        data = _make_record(your_probability=-0.1)
        with pytest.raises(ValidationError, match="your_probability"):
            validate_record(data)

    def test_probability_above_one_rejected(self):
        data = _make_record(your_probability=1.5)
        with pytest.raises(ValidationError, match="your_probability"):
            validate_record(data)

    def test_probability_zero_accepted(self):
        data = _make_record(your_probability=0.0)
        validate_record(data)  # Should not raise

    def test_probability_one_accepted(self):
        data = _make_record(your_probability=1.0)
        validate_record(data)  # Should not raise

    def test_negative_stake_rejected(self):
        data = _make_record(stake_cents=-100)
        with pytest.raises(ValidationError, match="stake_cents"):
            validate_record(data)

    def test_zero_stake_rejected(self):
        data = _make_record(stake_cents=0)
        with pytest.raises(ValidationError, match="stake_cents"):
            validate_record(data)

    def test_invalid_position_side_rejected(self):
        data = _make_record(position_side="maybe")
        with pytest.raises(ValidationError, match="position_side"):
            validate_record(data)

    def test_invalid_order_type_rejected(self):
        data = _make_record(order_type="market_on_close")
        with pytest.raises(ValidationError, match="order_type"):
            validate_record(data)

    def test_market_price_below_zero_rejected(self):
        data = _make_record(market_price_at_entry=-0.01)
        with pytest.raises(ValidationError, match="market_price_at_entry"):
            validate_record(data)

    def test_market_price_above_one_rejected(self):
        data = _make_record(market_price_at_entry=1.01)
        with pytest.raises(ValidationError, match="market_price_at_entry"):
            validate_record(data)

    def test_fill_price_out_of_range_rejected(self):
        data = _make_record(fill_price=1.5)
        with pytest.raises(ValidationError, match="fill_price"):
            validate_record(data)

    def test_failure_codes_not_list_rejected(self):
        data = _make_record(failure_codes="F1")
        with pytest.raises(ValidationError, match="failure_codes"):
            validate_record(data)

    def test_monitoring_updates_not_list_rejected(self):
        data = _make_record(monitoring_updates="update")
        with pytest.raises(ValidationError, match="monitoring_updates"):
            validate_record(data)


class TestWriteAndRead:
    """Test JSONL write/read round-trip."""

    def test_write_single_record(self, tmp_path):
        path = tmp_path / "bets.jsonl"
        data = _make_record()
        record = BetRecord(**data)
        write_record(record, str(path))

        lines = path.read_text().strip().split("\n")
        assert len(lines) == 1
        parsed = json.loads(lines[0])
        assert parsed["market_ticker"] == "KXHIGHNY-26APR07-T50"

    def test_write_appends(self, tmp_path):
        path = tmp_path / "bets.jsonl"
        r1 = BetRecord(**_make_record(bet_id="id-1"))
        r2 = BetRecord(**_make_record(bet_id="id-2"))
        write_record(r1, str(path))
        write_record(r2, str(path))

        lines = path.read_text().strip().split("\n")
        assert len(lines) == 2

    def test_read_all_records(self, tmp_path):
        path = tmp_path / "bets.jsonl"
        r1 = BetRecord(**_make_record(bet_id="id-1"))
        r2 = BetRecord(**_make_record(bet_id="id-2"))
        write_record(r1, str(path))
        write_record(r2, str(path))

        records = read_records(str(path))
        assert len(records) == 2
        assert records[0].bet_id == "id-1"
        assert records[1].bet_id == "id-2"

    def test_round_trip_preserves_all_fields(self, tmp_path):
        path = tmp_path / "bets.jsonl"
        data = _make_record(
            fill_price=0.66,
            fill_timestamp="2026-04-06T14:35:00Z",
            resolution_outcome="yes",
            resolution_timestamp="2026-04-08T00:00:00Z",
            pnl_cents=170,
            brier_contribution=0.0784,
            log_loss_contribution=0.3285,
            failure_codes=["F2", "F5"],
            postmortem_path="data/postmortems/KXHIGHNY-26APR07-T50/aar.md",
            monitoring_updates=[{"timestamp": "2026-04-07T08:00:00Z", "action": "hold"}],
        )
        record = BetRecord(**data)
        write_record(record, str(path))
        records = read_records(str(path))
        assert len(records) == 1
        assert records[0].to_dict() == data

    def test_read_empty_file(self, tmp_path):
        path = tmp_path / "bets.jsonl"
        path.touch()
        records = read_records(str(path))
        assert records == []

    def test_read_nonexistent_file(self, tmp_path):
        path = tmp_path / "does_not_exist.jsonl"
        records = read_records(str(path))
        assert records == []

    def test_write_creates_parent_directories(self, tmp_path):
        path = tmp_path / "nested" / "dir" / "bets.jsonl"
        record = BetRecord(**_make_record())
        write_record(record, str(path))
        assert path.exists()

    def test_read_validates_each_record(self, tmp_path):
        """Bad records in the file should raise on read."""
        path = tmp_path / "bets.jsonl"
        # Write a valid record, then manually append an invalid one
        record = BetRecord(**_make_record())
        write_record(record, str(path))
        with open(path, "a") as f:
            f.write(json.dumps({"bad": "record"}) + "\n")

        with pytest.raises(ValidationError):
            read_records(str(path))
