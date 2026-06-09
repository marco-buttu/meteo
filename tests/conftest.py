"""Pytest configuration for API equivalence tests."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import pytest


DEFAULT_CONFIG_PATH = Path(__file__).parent / "fixtures" / "equivalence_config.json"


def pytest_addoption(parser: pytest.Parser) -> None:
    parser.addoption(
        "--equivalence-config",
        action="store",
        default=None,
        help="Path to the equivalence test configuration JSON file.",
    )


@pytest.fixture(scope="session")
def equivalence_config(request: pytest.FixtureRequest) -> dict[str, Any]:
    raw_path = request.config.getoption("--equivalence-config")
    path = Path(raw_path).expanduser() if raw_path else DEFAULT_CONFIG_PATH
    path = path.resolve()
    with path.open("r", encoding="utf-8") as handle:
        config = json.load(handle)
    config["_config_path"] = str(path)
    return config
