"""Operation-level validation and dispatch helpers."""

from __future__ import annotations

from datetime import datetime, timezone
import re
from typing import Any, Dict, Mapping

from app import config as app_config
from app.domain.exceptions import (
    InvalidDateTimeError,
    InvalidParametersError,
    InvalidParameterTypeError,
    MissingParameterError,
    UnexpectedParameterError,
)
from app.operations.registry import (
    get_operation_definition as registry_get_operation_definition,
    get_operation_handler as registry_get_operation_handler,
    has_operation,
)


_SUPPORTED_TYPES = frozenset({"string", "float", "integer", "datetime_iso8601"})


def check_operation_exists(operation_name: str) -> None:
    """Ensure that the given operation exists."""
    if not has_operation(operation_name):
        registry_get_operation_definition(operation_name)


def get_operation_definition(operation_name: str) -> Dict[str, Any]:
    """Return the static definition for the given operation."""
    return registry_get_operation_definition(operation_name)


def validate_and_normalize_parameters(
    operation_name: str,
    parameters: Mapping[str, Any],
) -> Dict[str, Any]:
    """Validate and normalize operation parameters against the schema."""
    operation_definition = get_operation_definition(operation_name)

    if not isinstance(parameters, dict):
        raise InvalidParametersError("parameters must be a JSON object.")

    required_parameters = operation_definition.get("required_parameters", {})
    optional_parameters = operation_definition.get("optional_parameters", {})
    allowed_names = set(required_parameters) | set(optional_parameters)

    missing_names = [name for name in required_parameters if name not in parameters]
    if missing_names:
        raise MissingParameterError(
            "Missing required parameter(s): {names}.".format(
                names=", ".join(sorted(missing_names))
            )
        )

    unexpected_names = [name for name in parameters if name not in allowed_names]
    if unexpected_names:
        raise UnexpectedParameterError(
            "Unexpected parameter(s): {names}.".format(
                names=", ".join(sorted(unexpected_names))
            )
        )

    normalized_parameters: Dict[str, Any] = {}
    parameter_schemas = dict(required_parameters)
    parameter_schemas.update(optional_parameters)

    for name, symbolic_type in parameter_schemas.items():
        if name not in parameters:
            continue
        normalized_parameters[name] = _normalize_parameter_value(
            parameter_name=name,
            value=parameters[name],
            symbolic_type=symbolic_type,
        )

    return _apply_parameter_constraints(operation_name, normalized_parameters)


def _apply_parameter_constraints(
    operation_name: str,
    parameters: Dict[str, Any],
) -> Dict[str, Any]:
    """Apply operation-specific validation that cannot be expressed by type only."""

    if operation_name == "data":
        _validate_year(parameters.get("year"), required=False)
        _validate_month(parameters.get("month"), required=False)
        _validate_day(parameters.get("day"), required=False)
        _validate_timestamp_filter("from", parameters.get("from"))
        _validate_timestamp_filter("to", parameters.get("to"))
        _validate_data_limit(parameters.get("limit"))

        start = parameters.get("from")
        end = parameters.get("to")
        if start is not None and end is not None and start > end:
            raise InvalidParametersError(
                "Parameter 'from' must be less than or equal to parameter 'to'."
            )

        return parameters

    if operation_name in {"iwv", "meteo", "opacity", "rain", "tsys"} or operation_name.startswith("legacy_"):
        if "date" in parameters:
            _validate_legacy_date(parameters["date"])
        if "hour" in parameters:
            _validate_hour(parameters["hour"])
        if "freq" in parameters:
            _validate_positive_float("freq", parameters["freq"], max_value=1000.0)
        if "theta" in parameters:
            _validate_float_range("theta", parameters["theta"], min_value=0.0, max_value=90.0)
        if "eta" in parameters:
            _validate_float_range("eta", parameters["eta"], min_value=0.0, max_value=1.0)
        if "trec" in parameters:
            _validate_float_range("trec", parameters["trec"], min_value=0.0, max_value=10000.0)
        return parameters

    if "site_lat" in parameters:
        _validate_float_range("site_lat", parameters["site_lat"], min_value=-90.0, max_value=90.0)
    if "site_lon" in parameters:
        _validate_float_range("site_lon", parameters["site_lon"], min_value=-180.0, max_value=180.0)
    if "site_alt_m" in parameters:
        _validate_float_range("site_alt_m", parameters["site_alt_m"], min_value=-500.0, max_value=10000.0)
    if "max_altitude_m" in parameters:
        _validate_positive_float("max_altitude_m", parameters["max_altitude_m"], max_value=100000.0)
    if "step_m" in parameters:
        _validate_positive_float("step_m", parameters["step_m"], max_value=100000.0)
    if "frequency_ghz" in parameters:
        _validate_positive_float("frequency_ghz", parameters["frequency_ghz"], max_value=1000.0)
    if "elevation_deg" in parameters:
        _validate_float_range("elevation_deg", parameters["elevation_deg"], min_value=0.0, max_value=90.0)
    if "pwv_mm" in parameters:
        _validate_float_range("pwv_mm", parameters["pwv_mm"], min_value=0.0, max_value=1000.0)

    return parameters


def _validate_legacy_date(value: str) -> None:
    if not re.fullmatch(r"[A-Za-z]\d{10}", value):
        raise InvalidParametersError(
            "Parameter 'date' must use legacy format <DB><YYYYMMDDHH>."
        )


def _validate_timestamp_filter(parameter_name: str, value: str | None) -> None:
    if value is None:
        return
    if not re.fullmatch(r"\d{10}", value):
        raise InvalidParametersError(
            "Parameter '{name}' must use YYYYMMDDHH format.".format(
                name=parameter_name
            )
        )


def _validate_year(value: int | None, *, required: bool) -> None:
    if value is None:
        if required:
            raise InvalidParametersError("Parameter 'year' is required.")
        return
    if not 1 <= value <= 9999:
        raise InvalidParametersError("Parameter 'year' must be between 1 and 9999.")


def _validate_month(value: int | None, *, required: bool) -> None:
    if value is None:
        if required:
            raise InvalidParametersError("Parameter 'month' is required.")
        return
    if not 1 <= value <= 12:
        raise InvalidParametersError("Parameter 'month' must be between 1 and 12.")


def _validate_day(value: int | None, *, required: bool) -> None:
    if value is None:
        if required:
            raise InvalidParametersError("Parameter 'day' is required.")
        return
    if not 1 <= value <= 31:
        raise InvalidParametersError("Parameter 'day' must be between 1 and 31.")


def _validate_data_limit(value: int | None) -> None:
    if value is None:
        return
    if not 1 <= value <= app_config.DATA_OPERATION_MAX_LIMIT:
        raise InvalidParametersError(
            "Parameter 'limit' must be between 1 and {max_limit}.".format(
                max_limit=app_config.DATA_OPERATION_MAX_LIMIT
            )
        )


def _validate_hour(value: int) -> None:
    # Keep this validation structural only. The legacy backend decides whether
    # the requested epoch exists for the selected data file, so out-of-range
    # epochs must be accepted as jobs and fail asynchronously in the worker.
    if value < 0:
        raise InvalidParametersError("Parameter 'hour' must be greater than or equal to 0.")


def _validate_positive_float(
    parameter_name: str,
    value: float,
    *,
    max_value: float | None = None,
) -> None:
    if value <= 0.0:
        raise InvalidParametersError(
            "Parameter '{name}' must be greater than 0.".format(
                name=parameter_name
            )
        )
    if max_value is not None and value > max_value:
        raise InvalidParametersError(
            "Parameter '{name}' must be less than or equal to {max_value}.".format(
                name=parameter_name,
                max_value=max_value,
            )
        )


def _validate_float_range(
    parameter_name: str,
    value: float,
    *,
    min_value: float,
    max_value: float,
) -> None:
    if not min_value <= value <= max_value:
        raise InvalidParametersError(
            "Parameter '{name}' must be between {min_value} and {max_value}.".format(
                name=parameter_name,
                min_value=min_value,
                max_value=max_value,
            )
        )



def get_operation_capabilities(operation_name: str) -> Dict[str, bool]:
    """Return whether the operation is expected to produce result and plot."""
    operation_definition = get_operation_definition(operation_name)
    return {
        "produces_result": bool(operation_definition["produces_result"]),
        "produces_plot": bool(operation_definition["produces_plot"]),
    }


def get_operation_handler(operation_name: str):
    """Return the registered handler for the given operation."""
    check_operation_exists(operation_name)
    return registry_get_operation_handler(operation_name)


def _normalize_parameter_value(parameter_name: str, value: Any, symbolic_type: str) -> Any:
    """Normalize a single parameter according to its symbolic type."""
    if symbolic_type not in _SUPPORTED_TYPES:
        raise InvalidParametersError(
            "Unsupported symbolic type {symbolic_type!r} for parameter {parameter_name!r}.".format(
                symbolic_type=symbolic_type,
                parameter_name=parameter_name,
            )
        )

    if symbolic_type == "string":
        return _normalize_string(parameter_name, value)
    if symbolic_type == "float":
        return _normalize_float(parameter_name, value)
    if symbolic_type == "integer":
        return _normalize_integer(parameter_name, value)
    return _normalize_datetime_iso8601(parameter_name, value)


def _normalize_string(parameter_name: str, value: Any) -> str:
    if not isinstance(value, str):
        raise InvalidParameterTypeError(
            "Parameter {parameter_name!r} must be a string.".format(
                parameter_name=parameter_name
            )
        )

    normalized = value.strip()
    if not normalized:
        raise InvalidParameterTypeError(
            "Parameter {parameter_name!r} must be a non-empty string.".format(
                parameter_name=parameter_name
            )
        )
    if len(normalized) > 256:
        raise InvalidParameterTypeError(
            "Parameter {parameter_name!r} must be at most 256 characters.".format(
                parameter_name=parameter_name
            )
        )
    return normalized


def _normalize_float(parameter_name: str, value: Any) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise InvalidParameterTypeError(
            "Parameter {parameter_name!r} must be a float-compatible number.".format(
                parameter_name=parameter_name
            )
        )
    return float(value)


def _normalize_datetime_iso8601(parameter_name: str, value: Any) -> str:
    if not isinstance(value, str):
        raise InvalidParameterTypeError(
            "Parameter {parameter_name!r} must be an ISO 8601 string.".format(
                parameter_name=parameter_name
            )
        )

    candidate = value.strip()
    if not candidate:
        raise InvalidDateTimeError(
            "Parameter {parameter_name!r} must not be empty.".format(
                parameter_name=parameter_name
            )
        )

    if candidate.endswith("Z"):
        candidate = candidate[:-1] + "+00:00"

    try:
        parsed = datetime.fromisoformat(candidate)
    except ValueError as exc:
        raise InvalidDateTimeError(
            "Parameter {parameter_name!r} must be a valid ISO 8601 datetime.".format(
                parameter_name=parameter_name
            )
        ) from exc

    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise InvalidDateTimeError(
            "Parameter {parameter_name!r} must include timezone information.".format(
                parameter_name=parameter_name
            )
        )

    normalized = parsed.astimezone(timezone.utc).isoformat(timespec="seconds")
    return normalized.replace("+00:00", "Z")


def _normalize_integer(parameter_name: str, value: Any) -> int:
    """Normalize an integer parameter."""
    if isinstance(value, bool):
        raise InvalidParameterTypeError(
            "Parameter '{name}' must be an integer.".format(name=parameter_name)
        )

    if isinstance(value, int):
        return value

    if isinstance(value, float):
        if not value.is_integer():
            raise InvalidParameterTypeError(
                "Parameter '{name}' must be an integer.".format(name=parameter_name)
            )
        return int(value)

    if isinstance(value, str):
        stripped_value = value.strip()
        try:
            return int(stripped_value)
        except ValueError as exc:
            raise InvalidParameterTypeError(
                "Parameter '{name}' must be an integer.".format(name=parameter_name)
            ) from exc

    raise InvalidParameterTypeError(
        "Parameter '{name}' must be an integer.".format(name=parameter_name)
    )
