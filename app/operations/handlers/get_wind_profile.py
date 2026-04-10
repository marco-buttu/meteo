"""Placeholder handler for get_wind_profile."""

from __future__ import annotations

from typing import Any, Dict, List

from app.domain.exceptions import OperationExecutionError, OperationOutputError


_MINIMAL_PNG_BYTES = (
    b'\x89PNG\r\n\x1a\n'
    b'\x00\x00\x00\rIHDR'
    b'\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89'
    b'\x00\x00\x00\x0bIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4'
    b'\x00\x00\x00\x00IEND\xaeB`\x82'
)


def handle(validated_parameters: Dict[str, Any]) -> Dict[str, Any]:
    """Return a deterministic placeholder result and PNG bytes for wind profile."""
    if not isinstance(validated_parameters, dict):
        raise OperationExecutionError("validated_parameters must be a dictionary.")

    max_altitude_m = validated_parameters.get("max_altitude_m")
    step_m = validated_parameters.get("step_m", 500.0)
    timestamp = validated_parameters.get("timestamp")

    if not isinstance(max_altitude_m, float) or max_altitude_m <= 0.0:
        raise OperationExecutionError("max_altitude_m must be a positive normalized float.")
    if not isinstance(step_m, float) or step_m <= 0.0:
        raise OperationExecutionError("step_m must be a positive normalized float when provided.")
    if not isinstance(timestamp, str):
        raise OperationExecutionError("timestamp must be a normalized ISO 8601 string.")

    altitude_values: List[float] = []
    current_altitude = 0.0
    while current_altitude < max_altitude_m:
        altitude_values.append(current_altitude)
        current_altitude += step_m

    if not altitude_values or altitude_values[-1] != max_altitude_m:
        altitude_values.append(max_altitude_m)

    profile = []
    for altitude in altitude_values:
        wind_speed = round(3.0 + (altitude / 1000.0) * 2.1, 2)
        profile.append({"altitude_m": round(altitude, 2), "wind_speed_mps": wind_speed})

    output = {
        "result": {
            "profile": profile,
            "timestamp": timestamp,
        },
        "plot_bytes": _MINIMAL_PNG_BYTES,
    }

    if output["result"] is None and output["plot_bytes"] is None:
        raise OperationOutputError("Handler output must contain a result or plot bytes.")

    return output
