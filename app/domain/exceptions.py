"""Application exception hierarchy for the server project."""

from __future__ import annotations

from typing import Literal, Optional


class ApplicationError(Exception):
    """Base class for all application-specific errors."""

    default_message = 'Application error.'

    def __init__(self, message: Optional[str] = None) -> None:
        super().__init__(message or self.default_message)


class ValidationError(ApplicationError):
    """Base class for request and parameter validation errors."""

    default_message = 'Validation error.'


class InvalidJsonError(ValidationError):
    """Raised when a request body is not valid JSON."""

    default_message = 'Invalid JSON payload.'


class InvalidRequestError(ValidationError):
    """Raised when the request payload structure is invalid."""

    default_message = 'Invalid request payload.'


class UnknownOperationError(ValidationError):
    """Raised when an operation name is not present in the catalog."""

    default_message = 'Unknown operation.'


class InvalidParametersError(ValidationError):
    """Raised when operation parameters are invalid."""

    default_message = 'Invalid operation parameters.'


class InvalidParameterTypeError(InvalidParametersError):
    """Raised when a parameter has an unexpected type."""

    default_message = 'Invalid parameter type.'


class MissingParameterError(InvalidParametersError):
    """Raised when a required parameter is missing."""

    default_message = 'Missing required parameter.'


class UnexpectedParameterError(InvalidParametersError):
    """Raised when an unexpected parameter is provided."""

    default_message = 'Unexpected parameter.'


class InvalidDateTimeError(InvalidParametersError):
    """Raised when a datetime parameter is not in the expected format."""

    default_message = 'Invalid datetime value.'


class JobNotFoundError(ApplicationError):
    """Raised when a job identifier does not exist."""

    default_message = 'Job not found.'


class ResultNotReadyError(ApplicationError):
    """Raised when a job result has not been produced yet."""

    default_message = 'Result not ready.'


class ResultNotAvailableError(ApplicationError):
    """Raised when a completed job does not provide a result artifact."""

    default_message = 'Result not available.'


class PlotNotAvailableError(ApplicationError):
    """Raised when a plot artifact is not available for a job."""

    default_message = 'Plot not available.'

    def __init__(
        self,
        message: Optional[str] = None,
        *,
        reason: Optional[Literal['not_ready', 'not_supported']] = None,
    ) -> None:
        super().__init__(message or self.default_message)
        self.reason = reason


class JobFailedError(ApplicationError):
    """Raised when a job ended in the failed state."""

    default_message = 'Job failed.'


class OperationError(ApplicationError):
    """Base class for operation execution errors."""

    default_code = 'OPERATION_ERROR'
    default_message = 'Operation error.'

    def __init__(self, message: Optional[str] = None, *, code: Optional[str] = None) -> None:
        super().__init__(message or self.default_message)
        self.code = code or self.default_code


class OperationExecutionError(OperationError):
    """Raised when operation execution fails."""

    default_code = 'OPERATION_EXECUTION_FAILED'
    default_message = 'Operation execution failed.'


class OperationTimeoutError(OperationError):
    """Raised when operation execution exceeds the allowed timeout."""

    default_code = 'OPERATION_TIMEOUT'
    default_message = 'Operation execution timed out.'


class OperationOutputError(OperationError):
    """Raised when an operation returns invalid or inconsistent output."""

    default_code = 'INVALID_OPERATION_OUTPUT'
    default_message = 'Operation output is invalid.'


class StorageError(ApplicationError):
    """Raised when the storage layer fails."""

    default_message = 'Storage error.'


class QueueError(ApplicationError):
    """Raised when queue interaction fails."""

    default_message = 'Queue error.'


class QueueSubmissionError(ApplicationError):
    """Raised when job submission fails after metadata creation."""

    default_message = 'Job submission failed.'

    def __init__(self, job_id: str, message: Optional[str] = None) -> None:
        self.job_id = job_id
        final_message = message or self.default_message
        super().__init__(final_message)
