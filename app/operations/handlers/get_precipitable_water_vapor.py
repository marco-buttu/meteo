"""Placeholder handler for get_precipitable_water_vapor."""

from __future__ import annotations

from typing import Any, Dict

from app.domain.exceptions import OperationExecutionError, OperationOutputError


def handle(validated_parameters: Dict[str, Any]) -> Dict[str, Any]:
    """Return a deterministic placeholder result for precipitable water vapor."""
    if not isinstance(validated_parameters, dict):
        raise OperationExecutionError("validated_parameters must be a dictionary.")

    latitude = validated_parameters.get("site_lat")
    longitude = validated_parameters.get("site_lon")
    site_altitude = validated_parameters.get("site_alt_m", 0.0)
    timestamp = validated_parameters.get("timestamp")

    if not isinstance(latitude, float) or not isinstance(longitude, float):
        raise OperationExecutionError("Latitude and longitude must be normalized floats.")
    if not isinstance(site_altitude, float):
        raise OperationExecutionError("site_alt_m must be a normalized float when provided.")
    if not isinstance(timestamp, str):
        raise OperationExecutionError("timestamp must be a normalized ISO 8601 string.")

    base_pwv = 2.0 + (abs(latitude) % 5.0) * 0.12 + (abs(longitude) % 7.0) * 0.03
    altitude_factor = min(site_altitude / 4000.0, 1.0) * 0.35
    pwv_mm = round(max(0.2, base_pwv - altitude_factor), 2)

    output = {
        "result": {
            "pwv_mm": pwv_mm,
            "quality": "good",
            "timestamp": timestamp,
        },
        "plot_bytes": None,
    }

    if output["result"] is None and output["plot_bytes"] is None:
        raise OperationOutputError("Handler output must contain a result or plot bytes.")

    return output
