from __future__ import annotations

from typing import Any, Dict

from app.config import OCTAVE_TIMEOUT_SECONDS
from app.domain.exceptions import OperationExecutionError, OperationTimeoutError
from app.domain.job_models import OperationOutput


def run_octave_operation(operation_name: str, parameters: Dict[str, Any]) -> OperationOutput:
    """Placeholder integration point for future Octave subprocess execution."""
    if not isinstance(operation_name, str) or not operation_name:
        raise OperationExecutionError('operation_name must be a non-empty string.')

    if not isinstance(parameters, dict):
        raise OperationExecutionError('parameters must be a dictionary.')

    if parameters.get('_simulate_timeout'):
        raise OperationTimeoutError(
            "Operation '{name}' exceeded timeout of {timeout} seconds.".format(
                name=operation_name,
                timeout=OCTAVE_TIMEOUT_SECONDS,
            )
        )

    if parameters.get('_simulate_execution_error'):
        raise OperationExecutionError(
            "External execution failed for operation '{name}'.".format(
                name=operation_name
            )
        )

    payload = _simulate_dispatcher_output(operation_name, parameters)
    output = OperationOutput.from_dict(payload)

    if not output.is_valid():
        raise OperationExecutionError(
            'External runner returned output that does not match the internal contract.'
        )

    return output


def _simulate_dispatcher_output(
    operation_name: str,
    parameters: Dict[str, Any],
) -> Dict[str, Any]:
    return {
        'result': {
            'runner': 'placeholder',
            'operation': operation_name,
            'parameters': parameters,
            'timeout_seconds': OCTAVE_TIMEOUT_SECONDS,
        },
        'plot_bytes': None,
    }
