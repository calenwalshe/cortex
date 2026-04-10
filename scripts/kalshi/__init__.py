"""Kalshi calibration harness — foundation layer.

Provides API client, bet record management, and configuration
for the prediction market calibration system.
"""

__all__ = ["KalshiClient", "BetRecord", "write_record", "read_records", "validate_record"]


def __getattr__(name: str):
    """Lazy imports to avoid circular/missing module issues during development."""
    if name == "KalshiClient":
        from scripts.kalshi.kalshi_client import KalshiClient
        return KalshiClient
    if name in ("BetRecord", "write_record", "read_records", "validate_record"):
        import scripts.kalshi.records as _records
        return getattr(_records, name)
    raise AttributeError(f"module 'scripts.kalshi' has no attribute {name!r}")
