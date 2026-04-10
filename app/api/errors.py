from __future__ import annotations

from typing import Tuple

from flask import Flask, jsonify
from werkzeug.exceptions import HTTPException

from app.domain.exceptions import (
    InvalidDateTimeError,
    InvalidJsonError,
    InvalidParameterTypeError,
    InvalidParametersError,
    InvalidRequestError,
    JobFailedError,
    JobNotFoundError,
    MissingParameterError,
    PlotNotAvailableError,
    QueueSubmissionError,
    ResultNotAvailableError,
    ResultNotReadyError,
    UnexpectedParameterError,
    UnknownOperationError,
)


def _build_error_response(code: str, message: str, status_code: int):
    return jsonify({'error': {'code': code, 'message': message}}), status_code


def _resolve_plot_error_status(error: PlotNotAvailableError) -> Tuple[str, int]:
    if error.reason == 'not_ready':
        return str(error), 409

    if error.reason == 'not_supported':
        return str(error), 404

    return str(error), 409


def register_error_handlers(app: Flask) -> None:
    @app.errorhandler(InvalidJsonError)
    def handle_invalid_json(error: InvalidJsonError):
        return _build_error_response('INVALID_JSON', str(error), 400)

    @app.errorhandler(InvalidRequestError)
    def handle_invalid_request(error: InvalidRequestError):
        return _build_error_response('INVALID_REQUEST', str(error), 400)

    @app.errorhandler(UnknownOperationError)
    def handle_unknown_operation(error: UnknownOperationError):
        return _build_error_response('UNKNOWN_OPERATION', str(error), 400)

    @app.errorhandler(InvalidParametersError)
    @app.errorhandler(InvalidParameterTypeError)
    @app.errorhandler(MissingParameterError)
    @app.errorhandler(UnexpectedParameterError)
    @app.errorhandler(InvalidDateTimeError)
    def handle_invalid_parameters(error):
        return _build_error_response('INVALID_PARAMETERS', str(error), 400)

    @app.errorhandler(JobNotFoundError)
    def handle_job_not_found(error: JobNotFoundError):
        return _build_error_response('JOB_NOT_FOUND', str(error), 404)

    @app.errorhandler(ResultNotReadyError)
    def handle_result_not_ready(error: ResultNotReadyError):
        return _build_error_response('RESULT_NOT_READY', str(error), 409)

    @app.errorhandler(ResultNotAvailableError)
    def handle_result_not_available(error: ResultNotAvailableError):
        return _build_error_response('RESULT_NOT_AVAILABLE', str(error), 404)

    @app.errorhandler(PlotNotAvailableError)
    def handle_plot_not_available(error: PlotNotAvailableError):
        message, status_code = _resolve_plot_error_status(error)
        return _build_error_response('PLOT_NOT_AVAILABLE', message, status_code)

    @app.errorhandler(JobFailedError)
    def handle_job_failed(error: JobFailedError):
        return _build_error_response('JOB_FAILED', str(error), 409)

    @app.errorhandler(QueueSubmissionError)
    def handle_queue_submission_failure(error: QueueSubmissionError):
        return _build_error_response('QUEUE_SUBMISSION_FAILED', str(error), 503)

    @app.errorhandler(Exception)
    def handle_unexpected_error(error: Exception):
        if isinstance(error, HTTPException):
            return error
        return _build_error_response('INTERNAL_ERROR', 'Internal server error.', 500)
