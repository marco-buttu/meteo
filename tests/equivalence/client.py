"""HTTP client helpers for asynchronous operation equivalence tests."""

from __future__ import annotations

import time
from typing import Any

import requests


class ApiClient:
    def __init__(
        self,
        *,
        base_url: str,
        poll_timeout_seconds: float,
        poll_interval_seconds: float,
        http_timeout_seconds: float,
    ) -> None:
        self.base_url = base_url.rstrip("/")
        self.poll_timeout_seconds = poll_timeout_seconds
        self.poll_interval_seconds = poll_interval_seconds
        self.http_timeout_seconds = http_timeout_seconds

    def submit_job(self, operation: str, parameters: dict[str, Any]) -> dict[str, Any]:
        response = requests.post(
            f"{self.base_url}/jobs",
            json={"operation": operation, "parameters": parameters},
            timeout=self.http_timeout_seconds,
        )
        return {
            "status_code": response.status_code,
            "json": _response_json(response),
        }

    def wait_for_job(self, job_id: str) -> dict[str, Any]:
        deadline = time.monotonic() + self.poll_timeout_seconds
        last_payload: dict[str, Any] | None = None
        while time.monotonic() <= deadline:
            response = requests.get(
                f"{self.base_url}/jobs/{job_id}",
                timeout=self.http_timeout_seconds,
            )
            response.raise_for_status()
            payload = response.json()
            last_payload = payload
            if payload.get("status") in {"finished", "failed"}:
                return payload
            time.sleep(self.poll_interval_seconds)
        raise AssertionError(f"Job {job_id} did not finish before timeout. Last payload: {last_payload}")

    def get_result(self, job_id: str) -> dict[str, Any] | None:
        response = requests.get(
            f"{self.base_url}/jobs/{job_id}/result",
            timeout=self.http_timeout_seconds,
        )
        if response.status_code == 404:
            return None
        response.raise_for_status()
        return response.json()

    def run_operation(self, operation: str, parameters: dict[str, Any]) -> dict[str, Any]:
        submitted = self.submit_job(operation, parameters)
        assert submitted["status_code"] == 202, (
            f"POST /jobs must accept operation={operation} "
            f"(expected=202, got={submitted['status_code']}): {submitted['json']}"
        )
        job_id = submitted["json"]["job_id"]
        metadata = self.wait_for_job(job_id)
        result = self.get_result(job_id) if metadata.get("status") == "finished" else None
        return {
            "job_id": job_id,
            "metadata": metadata,
            "result_response": result,
        }


def _response_json(response: requests.Response) -> Any:
    try:
        return response.json()
    except ValueError:
        return response.text
