#!/usr/bin/env python3
"""
File: smoke_tests_final.py

Purpose:
    End-to-end smoke tests for the HTTP API and legacy operations.

Output style:
    - Clear start of each test
    - Short, useful intermediate steps
    - One final PASS or FAIL per test
    - ANSI colors for readability
    - Final summary includes failed test numbers and names

How to use:
    1. Start Redis.
    2. Start the Flask API.
    3. Start the RQ worker.
    4. Run:
           python smoke_tests_final.py

Optional environment variables:
    BASE_URL=http://127.0.0.1:5000
    TIMEOUT_SECONDS=30
    POLL_INTERVAL=1.0
    LEGACY_DATE=A2026011600

Current expected legacy behavior with LEGACY_DATE=A2026011600:
    - legacy_iwv single point: success
    - legacy_iwv series: success
    - legacy_opacity single point: success
    - legacy_opacity series: success
    - legacy_meteo single point: success
    - legacy_meteo series: success
    - legacy_rain single point: success
    - legacy_tsys single point: success
    - legacy_tsys series: success
"""

import json
import os
import sys
import time
from dataclasses import dataclass
from typing import Any, Callable, Dict, Iterable, List, Tuple

import requests


BASE_URL = os.getenv("BASE_URL", "http://127.0.0.1:5000").rstrip("/")
TIMEOUT_SECONDS = int(os.getenv("TIMEOUT_SECONDS", "30"))
POLL_INTERVAL = float(os.getenv("POLL_INTERVAL", "1.0"))
LEGACY_DATE = os.getenv("LEGACY_DATE", "A2026011600")


class Color:
    RESET = "\033[0m"
    BOLD = "\033[1m"
    RED = "\033[31m"
    GREEN = "\033[32m"
    YELLOW = "\033[33m"
    BLUE = "\033[34m"
    CYAN = "\033[36m"


class TestFailure(Exception):
    """Raised when a smoke test fails."""


@dataclass
class TestContext:
    base_url: str = BASE_URL
    timeout_seconds: int = TIMEOUT_SECONDS
    poll_interval: float = POLL_INTERVAL
    legacy_date: str = LEGACY_DATE


@dataclass
class TestCase:
    number: int
    name: str
    func: Callable[["TestContext"], None]


def colorize(text: str, color: str) -> str:
    return f"{color}{text}{Color.RESET}"


def bold(text: str) -> str:
    return colorize(text, Color.BOLD)


def blue(text: str) -> str:
    return colorize(text, Color.BLUE)


def cyan(text: str) -> str:
    return colorize(text, Color.CYAN)


def green(text: str) -> str:
    return colorize(text, Color.GREEN)


def yellow(text: str) -> str:
    return colorize(text, Color.YELLOW)


def red(text: str) -> str:
    return colorize(text, Color.RED)


def section(title: str) -> None:
    print(f"\n{blue(bold(f'=== {title} ==='))}")


def step(message: str) -> None:
    print(f"{cyan('[STEP]')} {message}")


def fail(message: str) -> None:
    raise TestFailure(message)


def pretty_json(data: Any) -> str:
    return json.dumps(data, indent=2, sort_keys=True, ensure_ascii=False)


def assert_equal(actual: Any, expected: Any, message: str) -> None:
    if actual != expected:
        fail(f"{message} (expected={expected!r}, got={actual!r})")


def assert_true(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def assert_has_keys(data: Dict[str, Any], required_keys: Iterable[str], message: str) -> None:
    missing = [key for key in required_keys if key not in data]
    if missing:
        fail(f"{message} (missing_keys={missing})")


def post_json(ctx: TestContext, path: str, payload: Dict[str, Any]) -> requests.Response:
    return requests.post(f"{ctx.base_url}{path}", json=payload)


def get_json(ctx: TestContext, path: str) -> requests.Response:
    return requests.get(f"{ctx.base_url}{path}")


def create_job(ctx: TestContext, operation: str, parameters: Dict[str, Any]) -> str:
    payload = {"operation": operation, "parameters": parameters}
    step(f"Create job for operation '{operation}'")
    response = post_json(ctx, "/jobs", payload)
    assert_equal(response.status_code, 202, f"POST /jobs must accept operation={operation}")
    data = response.json()
    job_id = data.get("job_id")
    assert_true(bool(job_id), f"job_id must be present for operation={operation}")
    step("Job accepted")
    return job_id


def wait_for_completion(ctx: TestContext, job_id: str, expected_final_status: str = "finished") -> Dict[str, Any]:
    deadline = time.time() + ctx.timeout_seconds

    while time.time() < deadline:
        response = get_json(ctx, f"/jobs/{job_id}")
        assert_equal(response.status_code, 200, "GET /jobs/<job_id> must return metadata")
        data = response.json()
        status = data.get("status")

        if status == expected_final_status:
            step(f"Job reached expected status '{expected_final_status}'")
            return data

        if status in {"finished", "failed"} and status != expected_final_status:
            error_data = data.get("error")
            fail(
                "Unexpected terminal job status\n"
                f"actual_status={status}\n"
                f"operation={data.get('operation')}\n"
                f"error={pretty_json(error_data)}"
            )

        time.sleep(ctx.poll_interval)

    fail(f"Timeout waiting for job completion (expected_status={expected_final_status})")


def fetch_result(ctx: TestContext, job_id: str) -> Dict[str, Any]:
    step("Fetch result")
    response = get_json(ctx, f"/jobs/{job_id}/result")
    assert_equal(response.status_code, 200, "GET /jobs/<job_id>/result must succeed")
    data = response.json()
    assert_true("result" in data, "Result response must contain 'result'")
    return data


def print_expectation(lines: Iterable[str]) -> None:
    print("Expected:")
    for line in lines:
        print(f"  - {line}")


def test_core_valid_job_lifecycle(ctx: TestContext) -> None:
    print_expectation(
        [
            "POST /jobs returns 202",
            "metadata endpoint returns 200",
            "job finishes successfully",
            "result endpoint returns 200",
        ]
    )

    payload = {
        "operation": "get_precipitable_water_vapor",
        "parameters": {
            "timestamp": "2026-03-27T10:00:00Z",
            "site_lat": 39.5,
            "site_lon": 9.2,
        },
    }

    step("Create standard job")
    response = post_json(ctx, "/jobs", payload)
    assert_equal(response.status_code, 202, "POST /jobs valid request")
    job_id = response.json().get("job_id")
    assert_true(bool(job_id), "job_id must be present")

    step("Read metadata")
    meta_response = get_json(ctx, f"/jobs/{job_id}")
    assert_equal(meta_response.status_code, 200, "Initial metadata fetch")
    meta_data = meta_response.json()
    assert_true("status" in meta_data, "Job metadata must contain status")

    wait_for_completion(ctx, job_id, expected_final_status="finished")

    result = fetch_result(ctx, job_id)
    assert_true("result" in result, "Result response must contain result")


def test_core_plot_generation(ctx: TestContext) -> None:
    print_expectation(
        [
            "POST /jobs returns 202",
            "job finishes successfully",
            "metadata has_plot is true",
            "/plot returns 200 and non-empty content",
        ]
    )

    payload = {
        "operation": "get_wind_profile",
        "parameters": {
            "timestamp": "2026-03-27T10:00:00Z",
            "site_lat": 39.5,
            "site_lon": 9.2,
            "max_altitude_m": 2000,
        },
    }

    step("Create plot job")
    response = post_json(ctx, "/jobs", payload)
    assert_equal(response.status_code, 202, "POST /jobs plot request")
    job_id = response.json()["job_id"]

    wait_for_completion(ctx, job_id, expected_final_status="finished")

    step("Verify metadata")
    meta_response = get_json(ctx, f"/jobs/{job_id}")
    metadata = meta_response.json()
    assert_true(metadata.get("has_plot") is True, "Finished plot job must have has_plot=true")

    step("Fetch plot")
    plot_response = requests.get(f"{ctx.base_url}/jobs/{job_id}/plot")
    assert_equal(plot_response.status_code, 200, "GET /plot")
    assert_true(len(plot_response.content) > 0, "Plot response must not be empty")


def test_core_invalid_json(ctx: TestContext) -> None:
    print_expectation(["HTTP 400 for malformed JSON body"])

    step("Send malformed JSON")
    response = requests.post(
        f"{ctx.base_url}/jobs",
        data='{"operation": ',
        headers={"Content-Type": "application/json"},
    )
    assert_equal(response.status_code, 400, "Invalid JSON must be rejected")


def test_core_unknown_operation(ctx: TestContext) -> None:
    print_expectation(["HTTP 400 for unknown operation"])

    step("Send unknown operation")
    payload = {"operation": "unknown_operation", "parameters": {}}
    response = post_json(ctx, "/jobs", payload)
    assert_equal(response.status_code, 400, "Unknown operation must be rejected")


def test_core_job_not_found(ctx: TestContext) -> None:
    print_expectation(["HTTP 404 for non-existing job"])

    step("Read non-existing job")
    response = get_json(ctx, "/jobs/fake-id")
    assert_equal(response.status_code, 404, "Unknown job_id must return 404")


def test_legacy_iwv_single_point_success(ctx: TestContext) -> None:
    print_expectation(
        [
            "job finishes successfully",
            "result has iwv_mm, ilw_mm, zdd_m, zwd_m, q",
        ]
    )

    job_id = create_job(ctx, "legacy_iwv", {"date": ctx.legacy_date, "hour": 1})
    wait_for_completion(ctx, job_id, expected_final_status="finished")
    result = fetch_result(ctx, job_id)["result"]
    assert_has_keys(result, ["iwv_mm", "ilw_mm", "zdd_m", "zwd_m", "q"], "legacy_iwv single-point result must contain expected keys")


def test_legacy_iwv_series_success(ctx: TestContext) -> None:
    print_expectation(
        [
            "job finishes successfully",
            "result contains metadata",
            "result contains non-empty series",
        ]
    )

    job_id = create_job(ctx, "legacy_iwv", {"date": ctx.legacy_date, "hour": 0})
    wait_for_completion(ctx, job_id, expected_final_status="finished")
    result = fetch_result(ctx, job_id)["result"]
    assert_true("metadata" in result, "legacy_iwv series result must contain metadata")
    assert_true("series" in result, "legacy_iwv series result must contain series")
    assert_true(isinstance(result["series"], list), "legacy_iwv series must be a list")
    assert_true(len(result["series"]) > 0, "legacy_iwv series must not be empty")


def test_legacy_opacity_single_point_success(ctx: TestContext) -> None:
    print_expectation(
        [
            "job finishes successfully",
            "result has tau_np and tmean_k",
        ]
    )

    job_id = create_job(ctx, "legacy_opacity", {"date": ctx.legacy_date, "hour": 1, "freq": 86.3})
    wait_for_completion(ctx, job_id, expected_final_status="finished")
    result = fetch_result(ctx, job_id)["result"]
    assert_has_keys(result, ["tau_np", "tmean_k"], "legacy_opacity single-point result must contain expected keys")


def test_legacy_opacity_series_success(ctx: TestContext) -> None:
    print_expectation(
        [
            "job finishes successfully",
            "result contains metadata",
            "result contains non-empty series",
        ]
    )

    job_id = create_job(ctx, "legacy_opacity", {"date": ctx.legacy_date, "hour": 0, "freq": 86.3})
    wait_for_completion(ctx, job_id, expected_final_status="finished")
    result = fetch_result(ctx, job_id)["result"]
    assert_true("metadata" in result, "legacy_opacity series result must contain metadata")
    assert_true("series" in result, "legacy_opacity series result must contain series")
    assert_true(isinstance(result["series"], list), "legacy_opacity series must be a list")
    assert_true(len(result["series"]) > 0, "legacy_opacity series must not be empty")


def test_legacy_meteo_single_point_success(ctx: TestContext) -> None:
    print_expectation(
        [
            "job finishes successfully",
            "result has all expected meteo keys",
        ]
    )

    job_id = create_job(ctx, "legacy_meteo", {"date": ctx.legacy_date, "hour": 1})
    wait_for_completion(ctx, job_id, expected_final_status="finished")
    result = fetch_result(ctx, job_id)["result"]
    assert_has_keys(
        result,
        ["temperature_k", "dew_point_k", "relative_humidity_pct", "pressure_hpa", "u_wind_mps", "v_wind_mps"],
        "legacy_meteo single-point result must contain expected keys",
    )


def test_legacy_meteo_series_success(ctx: TestContext) -> None:
    print_expectation(
        [
            "job finishes successfully",
            "result contains metadata",
            "result contains non-empty series",
        ]
    )

    job_id = create_job(ctx, "legacy_meteo", {"date": ctx.legacy_date, "hour": 0})
    wait_for_completion(ctx, job_id, expected_final_status="finished")
    result = fetch_result(ctx, job_id)["result"]
    assert_true("metadata" in result, "legacy_meteo series result must contain metadata")
    assert_true("series" in result, "legacy_meteo series result must contain series")
    assert_true(isinstance(result["series"], list), "legacy_meteo series must be a list")
    assert_true(len(result["series"]) > 0, "legacy_meteo series must not be empty")


def test_legacy_rain_single_point_success(ctx: TestContext) -> None:
    print_expectation(
        [
            "job finishes successfully",
            "result has rain_mm",
        ]
    )

    job_id = create_job(ctx, "legacy_rain", {"date": ctx.legacy_date, "hour": 1})
    wait_for_completion(ctx, job_id, expected_final_status="finished")
    result = fetch_result(ctx, job_id)["result"]
    assert_has_keys(result, ["rain_mm"], "legacy_rain single-point result must contain rain_mm")


def test_legacy_file_not_found_expected_failure(ctx: TestContext) -> None:
    print_expectation(
        [
            "job fails",
            "structured error exists",
            "error message mentions file",
        ]
    )

    job_id = create_job(ctx, "legacy_iwv", {"date": "A2099030112", "hour": 1})
    metadata = wait_for_completion(ctx, job_id, expected_final_status="failed")
    error_data = metadata.get("error") or {}
    message = error_data.get("message", "").lower()
    assert_true(bool(error_data), "File-not-found failure must expose structured error payload")
    assert_true("file" in message, "File-not-found failure message must mention file")


def test_legacy_db_not_found_expected_failure(ctx: TestContext) -> None:
    print_expectation(
        [
            "job fails",
            "structured error exists",
            "backend error message is printed for diagnosis",
        ]
    )

    job_id = create_job(ctx, "legacy_iwv", {"date": "Z2026011600", "hour": 1})
    metadata = wait_for_completion(ctx, job_id, expected_final_status="failed")
    error_data = metadata.get("error") or {}
    assert_true(bool(error_data), "DB-prefix failure must expose structured error payload")
    assert_true(bool(error_data.get("code")), "DB-prefix failure must expose error.code")
    message = error_data.get("message", "")
    step(f"Backend error message: {message}")


def test_legacy_epoch_out_of_range_expected_failure(ctx: TestContext) -> None:
    print_expectation(
        [
            "job fails",
            "structured error exists",
        ]
    )

    job_id = create_job(ctx, "legacy_meteo", {"date": ctx.legacy_date, "hour": 999})
    metadata = wait_for_completion(ctx, job_id, expected_final_status="failed")
    error_data = metadata.get("error") or {}
    assert_true(bool(error_data), "Out-of-range epoch failure must expose structured error payload")


def test_invalid_parameters_missing_freq_for_opacity(ctx: TestContext) -> None:
    print_expectation(["HTTP 400 for missing required parameter freq"])

    step("Send request with missing freq")
    payload = {"operation": "legacy_opacity", "parameters": {"date": ctx.legacy_date, "hour": 1}}
    response = post_json(ctx, "/jobs", payload)
    assert_equal(response.status_code, 400, "Missing freq must be rejected for legacy_opacity")


def test_invalid_parameter_type_for_rain(ctx: TestContext) -> None:
    print_expectation(["HTTP 400 for invalid parameter type"])

    step("Send request with invalid hour type")
    payload = {"operation": "legacy_rain", "parameters": {"date": ctx.legacy_date, "hour": "uno"}}
    response = post_json(ctx, "/jobs", payload)
    assert_equal(response.status_code, 400, "Invalid hour type must be rejected for legacy_rain")


def test_legacy_tsys_single_point_success(ctx: TestContext) -> None:
    print_expectation(
        [
            "job finishes successfully",
            "result has tsys_k and tsys2_k",
        ]
    )

    job_id = create_job(
        ctx,
        "legacy_tsys",
        {"date": ctx.legacy_date, "hour": 1, "freq": 86.3, "theta": 45.0, "eta": 0.95, "trec": 50.0},
    )
    wait_for_completion(ctx, job_id, expected_final_status="finished")
    result = fetch_result(ctx, job_id)["result"]
    assert_has_keys(result, ["tsys_k", "tsys2_k"], "legacy_tsys single-point result must contain expected keys")


def test_legacy_tsys_series_success(ctx: TestContext) -> None:
    print_expectation(
        [
            "job finishes successfully",
            "result contains metadata",
            "result contains non-empty series",
        ]
    )

    job_id = create_job(
        ctx,
        "legacy_tsys",
        {"date": ctx.legacy_date, "hour": 0, "freq": 86.3, "theta": 45.0, "eta": 0.95, "trec": 50.0},
    )
    wait_for_completion(ctx, job_id, expected_final_status="finished")
    result = fetch_result(ctx, job_id)["result"]
    assert_true("metadata" in result, "legacy_tsys series result must contain metadata")
    assert_true("series" in result, "legacy_tsys series result must contain series")
    assert_true(isinstance(result["series"], list), "legacy_tsys series must be a list")
    assert_true(len(result["series"]) > 0, "legacy_tsys series must not be empty")


def run_test(case: TestCase, ctx: TestContext) -> Tuple[bool, str]:
    header = f"[{case.number:02d}] {case.name}"
    print(f"\n{bold('>>> START TEST')} {header}")
    try:
        case.func(ctx)
        print(f"{green(bold('<<< END TEST PASS'))} {header}")
        return True, ""
    except TestFailure as exc:
        print(f"{red(bold('[FAIL]'))} {exc}")
        print(f"{red(bold('<<< END TEST FAIL'))} {header}")
        return False, str(exc)
    except requests.RequestException as exc:
        message = f"Network/request error: {exc}"
        print(f"{red(bold('[FAIL]'))} {message}")
        print(f"{red(bold('<<< END TEST FAIL'))} {header}")
        return False, message
    except Exception as exc:
        message = f"Unexpected exception: {type(exc).__name__}: {exc}"
        print(f"{red(bold('[FAIL]'))} {message}")
        print(f"{red(bold('<<< END TEST FAIL'))} {header}")
        return False, message


def main() -> int:
    ctx = TestContext()

    print(bold("Smoke test configuration:"))
    print(f"  BASE_URL={ctx.base_url}")
    print(f"  TIMEOUT_SECONDS={ctx.timeout_seconds}")
    print(f"  POLL_INTERVAL={ctx.poll_interval}")
    print(f"  LEGACY_DATE={ctx.legacy_date}")

    tests: List[TestCase] = [
        TestCase(1, "Core API | valid job lifecycle", test_core_valid_job_lifecycle),
        TestCase(2, "Core API | plot generation", test_core_plot_generation),
        TestCase(3, "Core API | invalid JSON", test_core_invalid_json),
        TestCase(4, "Core API | unknown operation", test_core_unknown_operation),
        TestCase(5, "Core API | job not found", test_core_job_not_found),
        TestCase(6, "Legacy | iwv single-point success", test_legacy_iwv_single_point_success),
        TestCase(7, "Legacy | iwv series success", test_legacy_iwv_series_success),
        TestCase(8, "Legacy | opacity single-point success", test_legacy_opacity_single_point_success),
        TestCase(9, "Legacy | opacity series success", test_legacy_opacity_series_success),
        TestCase(10, "Legacy | meteo single-point success", test_legacy_meteo_single_point_success),
        TestCase(11, "Legacy | meteo series success", test_legacy_meteo_series_success),
        TestCase(12, "Legacy | rain single-point success", test_legacy_rain_single_point_success),
        TestCase(13, "Legacy | missing legacy file expected failure", test_legacy_file_not_found_expected_failure),
        TestCase(14, "Legacy | unsupported DB expected failure", test_legacy_db_not_found_expected_failure),
        TestCase(15, "Legacy | epoch out-of-range expected failure", test_legacy_epoch_out_of_range_expected_failure),
        TestCase(16, "Validation | missing freq for legacy_opacity", test_invalid_parameters_missing_freq_for_opacity),
        TestCase(17, "Validation | invalid hour type for legacy_rain", test_invalid_parameter_type_for_rain),
        TestCase(18, "Legacy | tsys single-point success", test_legacy_tsys_single_point_success),
        TestCase(19, "Legacy | tsys series success", test_legacy_tsys_series_success),
    ]

    passed = 0
    failed: List[Tuple[int, str, str]] = []

    for case in tests:
        success, reason = run_test(case, ctx)
        if success:
            passed += 1
        else:
            failed.append((case.number, case.name, reason))

    total = len(tests)

    print(f"\n{blue(bold('=== FINAL RESULT ==='))}")
    if not failed:
        print(f"{green(bold('ALL TESTS PASSED'))} {passed}/{total}")
        return 0

    print(f"{red(bold('SOME TESTS FAILED'))} {passed}/{total} passed")
    print("Failed tests:")
    for number, name, reason in failed:
        print(f"  - [{number:02d}] {name}")
        print(f"    reason: {reason}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
