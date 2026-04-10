"""Placeholder handler for get_system_temperature_estimate."""

from __future__ import annotations

from typing import Any, Dict

from app.domain.exceptions import OperationExecutionError, OperationOutputError


def handle(validated_parameters: Dict[str, Any]) -> Dict[str, Any]:
    """Return a deterministic placeholder result for system temperature."""
    if not isinstance(validated_parameters, dict):
        raise OperationExecutionError("validated_parameters must be a dictionary.")

    frequency_ghz = validated_parameters.get("frequency_ghz")
    elevation_deg = validated_parameters.get("elevation_deg")
    pwv_mm = validated_parameters.get("pwv_mm")
    receiver_band = validated_parameters.get("receiver_band", "default")

    if not isinstance(frequency_ghz, float):
        raise OperationExecutionError("frequency_ghz must be a normalized float.")
    if not isinstance(elevation_deg, float):
        raise OperationExecutionError("elevation_deg must be a normalized float.")
    if not isinstance(pwv_mm, float):
        raise OperationExecutionError("pwv_mm must be a normalized float.")
    if not isinstance(receiver_band, str):
        raise OperationExecutionError("receiver_band must be a string when provided.")

    atmospheric_term = pwv_mm * 2.4
    elevation_penalty = max(0.0, 60.0 - elevation_deg) * 0.18
    frequency_term = frequency_ghz * 0.55
    system_temperature_k = round(35.0 + atmospheric_term + elevation_penalty + frequency_term, 2)

    output = {
        "result": {
            "system_temperature_k": system_temperature_k,
            "quality": "placeholder",
            "receiver_band": receiver_band,
        },
        "plot_bytes": None,
    }

    if output["result"] is None and output["plot_bytes"] is None:
        raise OperationOutputError("Handler output must contain a result or plot bytes.")

    return output
