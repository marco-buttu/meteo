"""Placeholder handler for plot_opacity_timeseries."""

from __future__ import annotations

from typing import Any, Dict

from app.domain.exceptions import OperationExecutionError, OperationOutputError


_MINIMAL_PNG_BYTES = (
    b'\x89PNG\r\n\x1a\n'
    b'\x00\x00\x00\rIHDR'
    b'\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89'
    b'\x00\x00\x00\x0bIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4'
    b'\x00\x00\x00\x00IEND\xaeB`\x82'
)


def handle(validated_parameters: Dict[str, Any]) -> Dict[str, Any]:
    """Return deterministic placeholder metadata and PNG bytes for opacity plot."""
    if not isinstance(validated_parameters, dict):
        raise OperationExecutionError("validated_parameters must be a dictionary.")

    start_time = validated_parameters.get("start_time")
    end_time = validated_parameters.get("end_time")
    frequency_ghz = validated_parameters.get("frequency_ghz", 100.0)

    if not isinstance(start_time, str) or not isinstance(end_time, str):
        raise OperationExecutionError("start_time and end_time must be normalized ISO 8601 strings.")
    if not isinstance(frequency_ghz, float):
        raise OperationExecutionError("frequency_ghz must be a normalized float when provided.")

    output = {
        "result": {
            "start_time": start_time,
            "end_time": end_time,
            "frequency_ghz": frequency_ghz,
            "series_points": 4,
            "quality": "placeholder",
        },
        "plot_bytes": _MINIMAL_PNG_BYTES,
    }

    if output["result"] is None and output["plot_bytes"] is None:
        raise OperationOutputError("Handler output must contain a result or plot bytes.")

    return output
