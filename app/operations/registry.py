"""Central registry for operation definitions and handlers."""

from __future__ import annotations

from collections.abc import Callable, Mapping
from typing import Dict, Tuple

from app.domain.exceptions import UnknownOperationError
from app.operations.schemas import OPERATION_CATALOG

try:
    from app.operations.handlers.data_catalog import handle as handle_data_catalog
    from app.operations.handlers.iwv import handle as handle_iwv
    from app.operations.handlers.meteo import handle as handle_meteo
    from app.operations.handlers.opacity import handle as handle_opacity
    from app.operations.handlers.rain import handle as handle_rain
    from app.operations.handlers.tsys import handle as handle_tsys
    from app.operations.handlers.legacy_passthrough import handle_legacy_iwv
    from app.operations.handlers.legacy_passthrough import handle_legacy_meteo
    from app.operations.handlers.legacy_passthrough import handle_legacy_opacity
    from app.operations.handlers.legacy_passthrough import handle_legacy_rain
    from app.operations.handlers.legacy_passthrough import handle_legacy_tsys
except ModuleNotFoundError as exc:
    _IMPORT_ERROR = exc
    _HANDLER_IMPORTS_AVAILABLE = False
else:
    _IMPORT_ERROR = None
    _HANDLER_IMPORTS_AVAILABLE = True


OperationHandler = Callable[[dict], dict]
OperationDefinition = Mapping[str, object]


def _build_handler_registry() -> Dict[str, OperationHandler]:
    if not _HANDLER_IMPORTS_AVAILABLE:
        return {}

    return {
        "data": handle_data_catalog,
        "iwv": handle_iwv,
        "meteo": handle_meteo,
        "opacity": handle_opacity,
        "rain": handle_rain,
        "tsys": handle_tsys,
        "legacy_iwv": handle_legacy_iwv,
        "legacy_opacity": handle_legacy_opacity,
        "legacy_meteo": handle_legacy_meteo,
        "legacy_rain": handle_legacy_rain,
        "legacy_tsys": handle_legacy_tsys,
    }


_HANDLER_REGISTRY = _build_handler_registry()


def _validate_registry_consistency() -> None:
    if not _HANDLER_IMPORTS_AVAILABLE:
        return

    schema_operations = set(OPERATION_CATALOG)
    handler_operations = set(_HANDLER_REGISTRY)

    missing_handlers = schema_operations - handler_operations
    extra_handlers = handler_operations - schema_operations

    if missing_handlers or extra_handlers:
        problems = []
        if missing_handlers:
            problems.append(
                "Missing handlers for operations: {names}.".format(
                    names=", ".join(sorted(missing_handlers))
                )
            )
        if extra_handlers:
            problems.append(
                "Handlers registered for unknown operations: {names}.".format(
                    names=", ".join(sorted(extra_handlers))
                )
            )
        raise RuntimeError(" ".join(problems))


_validate_registry_consistency()


def list_operations() -> Tuple[str, ...]:
    """Return all available operation names in a stable order."""
    return tuple(sorted(OPERATION_CATALOG))


def has_operation(operation_name: str) -> bool:
    """Return True when the operation exists in the catalog."""
    return operation_name in OPERATION_CATALOG


def get_operation_definition(operation_name: str) -> OperationDefinition:
    """Return the declarative definition for an operation."""
    try:
        return OPERATION_CATALOG[operation_name]
    except KeyError as exc:
        raise UnknownOperationError(
            "Unknown operation: '{name}'.".format(name=operation_name)
        ) from exc


def get_operation_handler(operation_name: str) -> OperationHandler:
    """Return the handler callable associated with an operation."""
    get_operation_definition(operation_name)

    if not _HANDLER_IMPORTS_AVAILABLE:
        raise RuntimeError(
            "Operation handlers are not available yet. "
            "Expected handler modules under app.operations.handlers."
        ) from _IMPORT_ERROR

    try:
        return _HANDLER_REGISTRY[operation_name]
    except KeyError as exc:
        raise RuntimeError(
            "Handler registry is inconsistent for operation: '{name}'.".format(
                name=operation_name
            )
        ) from exc
