"""Kalshi calibration harness — foundation layer.

Provides API client, bet record management, and configuration
for the prediction market calibration system.
"""

from scripts.kalshi.kalshi_client import KalshiClient
from scripts.kalshi.records import BetRecord, write_record, read_records, validate_record

__all__ = ["KalshiClient", "BetRecord", "write_record", "read_records", "validate_record"]
