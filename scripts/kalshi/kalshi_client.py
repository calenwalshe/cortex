"""Kalshi API client — thin wrapper over the official kalshi-python SDK.

Isolates SDK types behind a clean dict-based interface. Consumers never
import or interact with kalshi_python directly.

Auth: RSA-PSS via key_id + private_key PEM file path (from environment,
NEVER stored in repo).
"""

from __future__ import annotations

from pathlib import Path
from typing import Any, Optional

import yaml

try:
    import kalshi_python
except ImportError as e:
    raise ImportError(
        "kalshi-python SDK not installed. Run: pip install kalshi-python"
    ) from e


class KalshiClientError(Exception):
    """Raised for API-level errors from the Kalshi client."""


# ---------------------------------------------------------------------------
# Default config values
# ---------------------------------------------------------------------------
_DEFAULTS = {
    "api": {
        "demo": {"base_url": "https://demo-api.kalshi.co/trade-api/v2"},
        "prod": {"base_url": "https://api.elections.kalshi.com/trade-api/v2"},
        "environment": "demo",
    },
    "markets": {
        "target_cities": ["NYC", "Chicago"],
        "weather_series_prefix": "KXHIGH",
    },
    "trading": {
        "default_stake_cents": 500,
        "edge_threshold": 0.05,
        "default_order_type": "limit",
    },
    "monitoring": {
        "interval_seconds": 3600,
    },
    "data": {
        "bets_path": "data/bets/bets.jsonl",
    },
}


def _deep_merge(base: dict, override: dict) -> dict:
    """Recursively merge override into base, returning a new dict."""
    result = dict(base)
    for k, v in override.items():
        if k in result and isinstance(result[k], dict) and isinstance(v, dict):
            result[k] = _deep_merge(result[k], v)
        else:
            result[k] = v
    return result


def load_config(path: str) -> dict:
    """Load YAML config and merge with defaults for missing keys."""
    with open(path) as f:
        raw = yaml.safe_load(f) or {}
    return _deep_merge(_DEFAULTS, raw)


# ---------------------------------------------------------------------------
# Market object → dict conversion
# ---------------------------------------------------------------------------
_MARKET_FIELDS = [
    "ticker", "series_ticker", "event_ticker", "title", "subtitle",
    "open_time", "close_time", "expiration_time", "status",
    "yes_bid", "yes_ask", "last_price", "volume", "volume_24h",
    "result", "can_close_early", "cap_count",
]

_POSITION_FIELDS = [
    "ticker", "event_ticker", "market_result", "realized_pnl",
    "resting_order_count", "position", "fees_paid", "total_cost",
]

_SETTLEMENT_FIELDS = [
    "ticker", "result", "yes_count", "no_count", "revenue", "settled_time",
]


def _sdk_to_dict(obj: Any, fields: list[str]) -> dict[str, Any]:
    """Extract known fields from an SDK model object into a plain dict."""
    return {f: getattr(obj, f, None) for f in fields}


# ---------------------------------------------------------------------------
# City code mapping for weather market series tickers
# ---------------------------------------------------------------------------
_CITY_CODES = {
    "NYC": "NY",
    "Chicago": "CHI",
    "Los Angeles": "LA",
    "Miami": "MIA",
    "Houston": "HOU",
    "Denver": "DEN",
    "Seattle": "SEA",
    "Dallas": "DAL",
    "Atlanta": "ATL",
    "Phoenix": "PHO",
    "Minneapolis": "MIN",
    "Detroit": "DET",
    "Boston": "BOS",
    "Philadelphia": "PHI",
    "Washington DC": "DC",
    "San Francisco": "SF",
    "Nashville": "NAS",
}


# ---------------------------------------------------------------------------
# KalshiClient
# ---------------------------------------------------------------------------
class KalshiClient:
    """Clean interface to Kalshi API. Returns plain dicts, not SDK types.

    Usage:
        config = load_config("config/kalshi.yaml")
        client = KalshiClient(config, api_key_id="...", private_key_path="...")
        markets = client.list_weather_markets(city="NYC")
    """

    def __init__(
        self,
        config: dict,
        api_key_id: str,
        private_key_path: str,
    ) -> None:
        self._config = config
        self.environment = config["api"]["environment"]

        base_url = config["api"][self.environment]["base_url"]

        # Set up SDK configuration
        sdk_config = kalshi_python.Configuration(host=base_url)
        self._api_client = kalshi_python.KalshiClient(configuration=sdk_config)
        self._api_client.set_kalshi_auth(api_key_id, private_key_path)

        # Lazy-init API instances
        self._markets_api = kalshi_python.MarketsApi(self._api_client)
        self._portfolio_api = kalshi_python.PortfolioApi(self._api_client)

    @classmethod
    def from_config_file(
        cls,
        config_path: str,
        api_key_id: str,
        private_key_path: str,
    ) -> KalshiClient:
        """Convenience constructor that loads config from a YAML file."""
        config = load_config(config_path)
        return cls(config=config, api_key_id=api_key_id, private_key_path=private_key_path)

    # ------------------------------------------------------------------
    # Market operations
    # ------------------------------------------------------------------
    def list_markets(
        self,
        series_ticker: Optional[str] = None,
        event_ticker: Optional[str] = None,
        status: Optional[str] = None,
        limit: int = 100,
    ) -> list[dict[str, Any]]:
        """List markets, optionally filtered. Returns list of plain dicts."""
        kwargs: dict[str, Any] = {"limit": limit}
        if series_ticker:
            kwargs["series_ticker"] = series_ticker
        if event_ticker:
            kwargs["event_ticker"] = event_ticker
        if status:
            kwargs["status"] = status

        response = self._markets_api.get_markets(**kwargs)
        return [_sdk_to_dict(m, _MARKET_FIELDS) for m in (response.markets or [])]

    def list_weather_markets(self, city: str) -> list[dict[str, Any]]:
        """List weather markets for a specific city.

        Uses the configured weather_series_prefix + city code.
        """
        prefix = self._config["markets"]["weather_series_prefix"]
        city_code = _CITY_CODES.get(city, city)
        series_ticker = f"{prefix}{city_code}"
        return self.list_markets(series_ticker=series_ticker)

    def get_market(self, ticker: str) -> dict[str, Any]:
        """Get detail for a single market by ticker. Returns a plain dict."""
        response = self._markets_api.get_market(ticker=ticker)
        return _sdk_to_dict(response.market, _MARKET_FIELDS)

    # ------------------------------------------------------------------
    # Order operations
    # ------------------------------------------------------------------
    def place_limit_order(
        self,
        ticker: str,
        side: str,
        count: int,
        yes_price_cents: int,
        client_order_id: Optional[str] = None,
    ) -> dict[str, Any]:
        """Place a limit order. Returns order details as a plain dict.

        Args:
            ticker: Market ticker (e.g. "KXHIGHNY-26APR07-T50")
            side: "yes" or "no"
            count: Number of contracts
            yes_price_cents: Limit price in cents (1-99)
            client_order_id: Optional idempotency key
        """
        if side not in ("yes", "no"):
            raise ValueError(f"side must be 'yes' or 'no', got '{side}'")

        order_params: dict[str, Any] = {
            "ticker": ticker,
            "side": side,
            "action": "buy",
            "count": count,
            "type": "limit",
            "yes_price": yes_price_cents,
        }
        if client_order_id:
            order_params["client_order_id"] = client_order_id

        request = kalshi_python.CreateOrderRequest(**order_params)
        response = self._portfolio_api.create_order(create_order_request=request)

        order = response.order
        return {
            "order_id": order.order_id,
            "status": order.status,
            "ticker": order.ticker,
            "side": order.side,
            "type": order.type,
            "yes_price": order.yes_price,
            "count": order.count,
        }

    # ------------------------------------------------------------------
    # Position operations
    # ------------------------------------------------------------------
    def get_positions(
        self,
        ticker: Optional[str] = None,
        event_ticker: Optional[str] = None,
    ) -> list[dict[str, Any]]:
        """Get current positions. Returns list of plain dicts."""
        kwargs: dict[str, Any] = {}
        if ticker:
            kwargs["ticker"] = ticker
        if event_ticker:
            kwargs["event_ticker"] = event_ticker

        response = self._portfolio_api.get_positions(**kwargs)
        return [
            _sdk_to_dict(p, _POSITION_FIELDS)
            for p in (response.market_positions or [])
        ]

    # ------------------------------------------------------------------
    # Settlement operations
    # ------------------------------------------------------------------
    def get_settlements(self, limit: int = 100) -> list[dict[str, Any]]:
        """Get settlement history. Returns list of plain dicts."""
        response = self._portfolio_api.get_settlements(limit=limit)
        return [
            _sdk_to_dict(s, _SETTLEMENT_FIELDS)
            for s in (response.settlements or [])
        ]
