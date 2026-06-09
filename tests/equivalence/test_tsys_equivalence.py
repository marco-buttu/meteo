"""Equivalence tests for legacy_tsys and the native Python tsys operation."""

from __future__ import annotations

from typing import Any

import pytest

from tests.equivalence.client import ApiClient
from tests.equivalence.compare import assert_json_equivalent

LEGACY_SIX_DECIMAL_FIELDS = {"tsys_k", "tsys2_k"}
LEGACY_MJD_DECIMAL_FIELDS = {"mjd"}
LEGACY_THREE_DECIMAL_FIELDS = {"freq_ghz", "trec_k", "theta_deg", "eta", "etaf"}


def _client(config: dict[str, Any]) -> ApiClient:
    return ApiClient(
        base_url=str(config.get("base_url", "http://127.0.0.1:5000")),
        poll_timeout_seconds=float(config.get("poll_timeout_seconds", 60)),
        poll_interval_seconds=float(config.get("poll_interval_seconds", 1)),
        http_timeout_seconds=float(config.get("http_timeout_seconds", 10)),
    )


def _tsys_config(config: dict[str, Any]) -> dict[str, Any]:
    return dict(config.get("tsys", {}))


def _valid_cases(config: dict[str, Any]) -> list[dict[str, Any]]:
    return list(_tsys_config(config).get("valid_cases", []))


def _configured_sweeps(config: dict[str, Any]) -> list[dict[str, Any]]:
    return list(_tsys_config(config).get("all_valid_epochs_for_cases", []))


def _async_failure_cases(config: dict[str, Any]) -> list[dict[str, Any]]:
    return list(_tsys_config(config).get("async_failure_cases", []))


def _request_validation_cases(config: dict[str, Any]) -> list[dict[str, Any]]:
    return list(_tsys_config(config).get("request_validation_cases", []))


def _run_pair(client: ApiClient, parameters: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
    legacy = client.run_operation("legacy_tsys", parameters)
    native = client.run_operation("tsys", parameters)
    return legacy, native


def _assert_same_terminal_status(legacy: dict[str, Any], native: dict[str, Any]) -> None:
    legacy_status = legacy["metadata"].get("status")
    native_status = native["metadata"].get("status")
    assert legacy_status == native_status, f"Terminal status mismatch: {legacy_status!r} != {native_status!r}"


def _assert_native_result_uses_legacy_rounding(result: dict[str, Any]) -> None:
    if "series" in result:
        _assert_rounded_numeric_fields(result.get("metadata", {}))
        for item in result.get("series", []):
            _assert_rounded_numeric_fields(item)
        return

    _assert_rounded_numeric_fields(result)


def _assert_rounded_numeric_fields(payload: dict[str, Any]) -> None:
    for field in LEGACY_SIX_DECIMAL_FIELDS:
        if field in payload:
            value = payload[field]
            assert value == round(float(value), 6), f"Field {field} is not rounded to 6 decimals: {value!r}"

    for field in LEGACY_MJD_DECIMAL_FIELDS:
        if field in payload:
            value = payload[field]
            assert value == round(float(value), 3), f"Field {field} is not rounded to 3 decimals: {value!r}"

    for field in LEGACY_THREE_DECIMAL_FIELDS:
        if field in payload:
            value = payload[field]
            assert value == round(float(value), 3), f"Field {field} is not rounded to 3 decimals: {value!r}"


def _assert_finished_results_equivalent(
    legacy: dict[str, Any],
    native: dict[str, Any],
    *,
    abs_tol: float,
    rel_tol: float,
) -> None:
    _assert_same_terminal_status(legacy, native)
    assert legacy["metadata"].get("status") == "finished"
    assert native["metadata"].get("status") == "finished"
    assert legacy["result_response"] is not None
    assert native["result_response"] is not None
    _assert_native_result_uses_legacy_rounding(native["result_response"]["result"])
    assert_json_equivalent(
        legacy["result_response"]["result"],
        native["result_response"]["result"],
        abs_tol=abs_tol,
        rel_tol=rel_tol,
    )


def _assert_failed_errors_equivalent(legacy: dict[str, Any], native: dict[str, Any], case: dict[str, Any]) -> None:
    _assert_same_terminal_status(legacy, native)
    assert legacy["metadata"].get("status") == "failed"
    assert native["metadata"].get("status") == "failed"

    expected_message_tokens = case.get("expected_message_contains", [])
    if expected_message_tokens:
        legacy_error = legacy["metadata"].get("error") or {}
        native_error = native["metadata"].get("error") or {}
        legacy_message = str(legacy_error.get("message", "")).lower()
        native_message = str(native_error.get("message", "")).lower()
        for token in expected_message_tokens:
            token_lower = str(token).lower()
            assert token_lower in legacy_message, f"Legacy error does not contain {token!r}: {legacy_error}"
            assert token_lower in native_message, f"Native error does not contain {token!r}: {native_error}"


def _series_length(client: ApiClient, case: dict[str, Any]) -> int:
    parameters = dict(case)
    parameters["hour"] = 0
    result = client.run_operation("legacy_tsys", parameters)
    assert result["metadata"].get("status") == "finished"
    payload = result["result_response"]
    assert payload is not None
    series = payload.get("result", {}).get("series", [])
    return len(series)


def test_tsys_configured_valid_cases_match_legacy(equivalence_config: dict[str, Any]) -> None:
    client = _client(equivalence_config)
    abs_tol = float(equivalence_config.get("abs_tol", 1e-6))
    rel_tol = float(equivalence_config.get("rel_tol", 1e-6))

    for case in _valid_cases(equivalence_config):
        parameters = dict(case["parameters"])
        legacy, native = _run_pair(client, parameters)
        _assert_finished_results_equivalent(legacy, native, abs_tol=abs_tol, rel_tol=rel_tol)


def test_tsys_all_valid_epochs_match_legacy_for_configured_cases(equivalence_config: dict[str, Any]) -> None:
    client = _client(equivalence_config)
    abs_tol = float(equivalence_config.get("abs_tol", 1e-6))
    rel_tol = float(equivalence_config.get("rel_tol", 1e-6))

    for case in _configured_sweeps(equivalence_config):
        base_parameters = dict(case)
        count = _series_length(client, base_parameters)
        assert count > 0
        for hour in range(0, count + 1):
            parameters = dict(base_parameters)
            parameters["hour"] = hour
            legacy, native = _run_pair(client, parameters)
            _assert_finished_results_equivalent(legacy, native, abs_tol=abs_tol, rel_tol=rel_tol)


def test_tsys_expected_async_failures_match_legacy(equivalence_config: dict[str, Any]) -> None:
    client = _client(equivalence_config)

    for case in _async_failure_cases(equivalence_config):
        parameters = dict(case["parameters"])
        legacy, native = _run_pair(client, parameters)
        _assert_failed_errors_equivalent(legacy, native, case)


@pytest.mark.parametrize("operation", ["legacy_tsys", "tsys"])
def test_tsys_request_validation_cases(equivalence_config: dict[str, Any], operation: str) -> None:
    client = _client(equivalence_config)

    for case in _request_validation_cases(equivalence_config):
        parameters = dict(case["parameters"])
        response = client.submit_job(operation, parameters)
        assert response["status_code"] == int(case.get("expected_status", 400)), response["json"]
