"""Operation-level validation and dispatch helpers."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Dict, Mapping

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

    return normalized_parameters


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
    return value


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
