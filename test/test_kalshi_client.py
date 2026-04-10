"""Tests for Kalshi API client wrapper — mocked responses only.

TDD RED phase: these tests define the expected KalshiClient interface.
No real API calls.
"""

import os
from unittest.mock import MagicMock, patch, PropertyMock
from pathlib import Path

import pytest

from scripts.kalshi.kalshi_client import KalshiClient, KalshiClientError


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def mock_config():
    """Minimal config dict matching config/kalshi.yaml structure."""
    return {
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
    }


def _make_mock_market(ticker="KXHIGHNY-26APR07-T50", title="NYC High Temp > 50F",
                      status="open", yes_bid=64, yes_ask=66, last_price=65,
                      result=None, event_ticker="KXHIGHNY-26APR07",
                      series_ticker="KXHIGHNY"):
    """Create a mock market object mimicking SDK Market model."""
    m = MagicMock()
    m.ticker = ticker
    m.title = title
    m.status = status
    m.yes_bid = yes_bid
    m.yes_ask = yes_ask
    m.last_price = last_price
    m.result = result
    m.event_ticker = event_ticker
    m.series_ticker = series_ticker
    m.volume = 1000
    m.volume_24h = 200
    m.subtitle = ""
    m.open_time = "2026-04-06T00:00:00Z"
    m.close_time = "2026-04-07T23:59:59Z"
    m.expiration_time = "2026-04-08T00:00:00Z"
    m.can_close_early = False
    m.cap_count = 1
    return m


def _make_mock_position(ticker="KXHIGHNY-26APR07-T50", position=5,
                        market_result=None, realized_pnl=0):
    p = MagicMock()
    p.ticker = ticker
    p.position = position
    p.market_result = market_result
    p.realized_pnl = realized_pnl
    p.event_ticker = "KXHIGHNY-26APR07"
    p.resting_order_count = 0
    p.fees_paid = 0
    p.total_cost = 330
    return p


def _make_mock_settlement(ticker="KXHIGHNY-26APR07-T50", result="yes",
                          yes_count=5, no_count=0, revenue=500):
    s = MagicMock()
    s.ticker = ticker
    s.result = result
    s.yes_count = yes_count
    s.no_count = no_count
    s.revenue = revenue
    s.settled_time = "2026-04-08T00:00:00Z"
    return s


# ---------------------------------------------------------------------------
# Tests: Construction and Auth
# ---------------------------------------------------------------------------

class TestClientConstruction:

    @patch("scripts.kalshi.kalshi_client.kalshi_python")
    def test_create_client_demo_env(self, mock_sdk, mock_config):
        client = KalshiClient(
            config=mock_config,
            api_key_id="test-key-id",
            private_key_path="/tmp/test_key.pem",
        )
        assert client.environment == "demo"
        # SDK Configuration should be called with demo base URL
        mock_sdk.Configuration.assert_called_once()
        call_kwargs = mock_sdk.Configuration.call_args
        assert "demo-api.kalshi.co" in str(call_kwargs)

    @patch("scripts.kalshi.kalshi_client.kalshi_python")
    def test_create_client_prod_env(self, mock_sdk, mock_config):
        mock_config["api"]["environment"] = "prod"
        client = KalshiClient(
            config=mock_config,
            api_key_id="test-key-id",
            private_key_path="/tmp/test_key.pem",
        )
        assert client.environment == "prod"

    @patch("scripts.kalshi.kalshi_client.kalshi_python")
    def test_auth_calls_set_kalshi_auth(self, mock_sdk, mock_config):
        mock_api_client = MagicMock()
        mock_sdk.KalshiClient.return_value = mock_api_client

        client = KalshiClient(
            config=mock_config,
            api_key_id="test-key-id",
            private_key_path="/tmp/test_key.pem",
        )
        mock_api_client.set_kalshi_auth.assert_called_once_with(
            "test-key-id", "/tmp/test_key.pem"
        )


# ---------------------------------------------------------------------------
# Tests: Market Operations
# ---------------------------------------------------------------------------

class TestMarketOperations:

    @patch("scripts.kalshi.kalshi_client.kalshi_python")
    def test_list_markets_returns_dicts(self, mock_sdk, mock_config):
        """list_markets should return plain dicts, not SDK objects."""
        mock_api_client = MagicMock()
        mock_sdk.KalshiClient.return_value = mock_api_client

        mock_markets_api = MagicMock()
        mock_sdk.MarketsApi.return_value = mock_markets_api

        mock_response = MagicMock()
        mock_response.markets = [
            _make_mock_market(ticker="KXHIGHNY-26APR07-T50"),
            _make_mock_market(ticker="KXHIGHCHI-26APR07-T45", title="Chicago High > 45F",
                              series_ticker="KXHIGHCHI"),
        ]
        mock_response.cursor = None
        mock_markets_api.get_markets.return_value = mock_response

        client = KalshiClient(config=mock_config, api_key_id="k", private_key_path="/tmp/k.pem")
        markets = client.list_markets(series_ticker="KXHIGHNY")

        assert isinstance(markets, list)
        assert len(markets) == 2
        assert isinstance(markets[0], dict)
        assert markets[0]["ticker"] == "KXHIGHNY-26APR07-T50"
        assert "yes_bid" in markets[0]
        assert "last_price" in markets[0]

    @patch("scripts.kalshi.kalshi_client.kalshi_python")
    def test_list_weather_markets_filters_by_prefix(self, mock_sdk, mock_config):
        """list_weather_markets uses the configured series prefix."""
        mock_api_client = MagicMock()
        mock_sdk.KalshiClient.return_value = mock_api_client

        mock_markets_api = MagicMock()
        mock_sdk.MarketsApi.return_value = mock_markets_api

        mock_response = MagicMock()
        mock_response.markets = [_make_mock_market()]
        mock_response.cursor = None
        mock_markets_api.get_markets.return_value = mock_response

        client = KalshiClient(config=mock_config, api_key_id="k", private_key_path="/tmp/k.pem")
        markets = client.list_weather_markets(city="NYC")

        # Should call get_markets with series_ticker containing the city
        mock_markets_api.get_markets.assert_called_once()
        call_kwargs = mock_markets_api.get_markets.call_args[1]
        assert "KXHIGHNY" in call_kwargs.get("series_ticker", "")

    @patch("scripts.kalshi.kalshi_client.kalshi_python")
    def test_get_market_returns_dict(self, mock_sdk, mock_config):
        mock_api_client = MagicMock()
        mock_sdk.KalshiClient.return_value = mock_api_client

        mock_markets_api = MagicMock()
        mock_sdk.MarketsApi.return_value = mock_markets_api

        mock_response = MagicMock()
        mock_response.market = _make_mock_market()
        mock_markets_api.get_market.return_value = mock_response

        client = KalshiClient(config=mock_config, api_key_id="k", private_key_path="/tmp/k.pem")
        market = client.get_market("KXHIGHNY-26APR07-T50")

        assert isinstance(market, dict)
        assert market["ticker"] == "KXHIGHNY-26APR07-T50"
        assert market["status"] == "open"


# ---------------------------------------------------------------------------
# Tests: Order Operations
# ---------------------------------------------------------------------------

class TestOrderOperations:

    @patch("scripts.kalshi.kalshi_client.kalshi_python")
    def test_place_limit_order_returns_dict(self, mock_sdk, mock_config):
        mock_api_client = MagicMock()
        mock_sdk.KalshiClient.return_value = mock_api_client

        mock_portfolio_api = MagicMock()
        mock_sdk.PortfolioApi.return_value = mock_portfolio_api

        mock_order_response = MagicMock()
        mock_order_response.order = MagicMock()
        mock_order_response.order.order_id = "order-123"
        mock_order_response.order.status = "resting"
        mock_order_response.order.ticker = "KXHIGHNY-26APR07-T50"
        mock_order_response.order.side = "yes"
        mock_order_response.order.type = "limit"
        mock_order_response.order.yes_price = 66
        mock_order_response.order.count = 5
        mock_portfolio_api.create_order.return_value = mock_order_response

        client = KalshiClient(config=mock_config, api_key_id="k", private_key_path="/tmp/k.pem")
        result = client.place_limit_order(
            ticker="KXHIGHNY-26APR07-T50",
            side="yes",
            count=5,
            yes_price_cents=66,
        )

        assert isinstance(result, dict)
        assert result["order_id"] == "order-123"
        assert result["status"] == "resting"

        # Verify SDK was called with CreateOrderRequest
        mock_portfolio_api.create_order.assert_called_once()

    @patch("scripts.kalshi.kalshi_client.kalshi_python")
    def test_place_limit_order_validates_side(self, mock_sdk, mock_config):
        mock_sdk.KalshiClient.return_value = MagicMock()
        client = KalshiClient(config=mock_config, api_key_id="k", private_key_path="/tmp/k.pem")

        with pytest.raises(ValueError, match="side"):
            client.place_limit_order(
                ticker="KXHIGHNY-26APR07-T50",
                side="maybe",
                count=5,
                yes_price_cents=66,
            )


# ---------------------------------------------------------------------------
# Tests: Position and Settlement
# ---------------------------------------------------------------------------

class TestPositionAndSettlement:

    @patch("scripts.kalshi.kalshi_client.kalshi_python")
    def test_get_positions_returns_dicts(self, mock_sdk, mock_config):
        mock_api_client = MagicMock()
        mock_sdk.KalshiClient.return_value = mock_api_client

        mock_portfolio_api = MagicMock()
        mock_sdk.PortfolioApi.return_value = mock_portfolio_api

        mock_response = MagicMock()
        mock_response.market_positions = [_make_mock_position()]
        mock_response.cursor = None
        mock_portfolio_api.get_positions.return_value = mock_response

        client = KalshiClient(config=mock_config, api_key_id="k", private_key_path="/tmp/k.pem")
        positions = client.get_positions()

        assert isinstance(positions, list)
        assert len(positions) == 1
        assert isinstance(positions[0], dict)
        assert positions[0]["ticker"] == "KXHIGHNY-26APR07-T50"
        assert positions[0]["position"] == 5

    @patch("scripts.kalshi.kalshi_client.kalshi_python")
    def test_get_settlements_returns_dicts(self, mock_sdk, mock_config):
        mock_api_client = MagicMock()
        mock_sdk.KalshiClient.return_value = mock_api_client

        mock_portfolio_api = MagicMock()
        mock_sdk.PortfolioApi.return_value = mock_portfolio_api

        mock_response = MagicMock()
        mock_response.settlements = [_make_mock_settlement()]
        mock_response.cursor = None
        mock_portfolio_api.get_settlements.return_value = mock_response

        client = KalshiClient(config=mock_config, api_key_id="k", private_key_path="/tmp/k.pem")
        settlements = client.get_settlements()

        assert isinstance(settlements, list)
        assert len(settlements) == 1
        assert isinstance(settlements[0], dict)
        assert settlements[0]["ticker"] == "KXHIGHNY-26APR07-T50"
        assert settlements[0]["result"] == "yes"
        assert settlements[0]["revenue"] == 500


# ---------------------------------------------------------------------------
# Tests: Config Loading
# ---------------------------------------------------------------------------

class TestConfigLoading:

    @patch("scripts.kalshi.kalshi_client.kalshi_python")
    def test_load_config_from_yaml(self, mock_sdk):
        """load_config reads the YAML file and returns a dict."""
        from scripts.kalshi.kalshi_client import load_config

        config = load_config(str(Path(__file__).parent.parent / "config" / "kalshi.yaml"))
        assert "api" in config
        assert config["api"]["environment"] == "demo"
        assert "NYC" in config["markets"]["target_cities"]

    @patch("scripts.kalshi.kalshi_client.kalshi_python")
    def test_load_config_defaults(self, mock_sdk):
        """load_config fills defaults for missing optional keys."""
        import tempfile, yaml

        minimal = {"api": {"environment": "demo"}}
        with tempfile.NamedTemporaryFile(mode="w", suffix=".yaml", delete=False) as f:
            yaml.dump(minimal, f)
            f.flush()
            from scripts.kalshi.kalshi_client import load_config
            config = load_config(f.name)

        os.unlink(f.name)
        # Should have defaults filled in
        assert "demo" in config["api"]
        assert config["trading"]["default_stake_cents"] == 500

    @patch("scripts.kalshi.kalshi_client.kalshi_python")
    def test_client_from_config_file(self, mock_sdk, mock_config):
        """KalshiClient.from_config_file is a convenience constructor."""
        import tempfile, yaml

        with tempfile.NamedTemporaryFile(mode="w", suffix=".yaml", delete=False) as f:
            yaml.dump(mock_config, f)
            f.flush()
            client = KalshiClient.from_config_file(
                config_path=f.name,
                api_key_id="test-key",
                private_key_path="/tmp/k.pem",
            )

        os.unlink(f.name)
        assert client.environment == "demo"
