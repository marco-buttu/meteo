from __future__ import annotations

from flask import Flask, Response, current_app, jsonify, request
from werkzeug.exceptions import BadRequest

from app.domain.exceptions import InvalidJsonError, InvalidRequestError
from app.api.legacy_parser import parse_legacy_command, LegacyCommandError


def register_routes(app: Flask) -> None:
    @app.route("/jobs", methods=["POST"])
    def create_job():
        payload = _parse_create_job_payload()

        job_service = current_app.extensions["job_service"]
        metadata = job_service.create_job(
            operation=payload["operation"],
            parameters=payload["parameters"],
        )
        return jsonify(metadata.to_dict()), 202

    @app.route("/jobs/<job_id>", methods=["GET"])
    def get_job(job_id: str):
        job_service = current_app.extensions["job_service"]
        metadata = job_service.get_job_metadata(job_id)
        return jsonify(metadata.to_dict()), 200

    @app.route("/jobs/<job_id>/result", methods=["GET"])
    def get_job_result(job_id: str):
        job_service = current_app.extensions["job_service"]
        result_wrapper = job_service.get_job_result(job_id)
        return jsonify(result_wrapper.to_dict()), 200

    @app.route("/jobs/<job_id>/plot", methods=["GET"])
    def get_job_plot(job_id: str):
        job_service = current_app.extensions["job_service"]
        plot_bytes = job_service.get_job_plot(job_id)
        return Response(plot_bytes, mimetype="image/png", status=200)

    @app.route("/legacy/command", methods=["POST"])
    def create_legacy_job():
        raw_body = request.get_data(cache=True)
        if not raw_body:
            raise InvalidRequestError("Request body is missing.")

        if request.is_json:
            try:
                payload = request.get_json(force=False, silent=False)
            except BadRequest as exc:
                raise InvalidJsonError("Request body must contain valid JSON.") from exc

            if payload is None:
                raise InvalidJsonError("Request body must contain valid JSON.")

            if not isinstance(payload, dict):
                raise InvalidRequestError("Request body must be a JSON object.")

            if "command" not in payload:
                raise InvalidRequestError("Missing required top-level field 'command'.")

            command = payload["command"]
            if not isinstance(command, str) or not command.strip():
                raise InvalidRequestError("Field 'command' must be a non-empty string.")

            command = command.strip()
        else:
            command = raw_body.decode().strip()
            if not command:
                raise InvalidRequestError("Request body is missing.")

        try:
            parsed = parse_legacy_command(command)
        except LegacyCommandError as exc:
            raise InvalidRequestError(exc.message) from exc

        job_service = current_app.extensions["job_service"]
        metadata = job_service.create_job(
            operation=parsed["operation"],
            parameters=parsed["parameters"],
        )
        return jsonify(metadata.to_dict()), 202

def _parse_create_job_payload():
    raw_body = request.get_data(cache=True)
    if not raw_body:
        raise InvalidJsonError("Request body is missing.")

    try:
        payload = request.get_json(force=False, silent=False)
    except BadRequest as exc:
        raise InvalidJsonError("Request body must contain valid JSON.") from exc

    if payload is None:
        raise InvalidJsonError("Request body must contain valid JSON.")

    if not isinstance(payload, dict):
        raise InvalidRequestError("Request body must be a JSON object.")

    if "operation" not in payload:
        raise InvalidRequestError("Missing required top-level field 'operation'.")

    if "parameters" not in payload:
        raise InvalidRequestError("Missing required top-level field 'parameters'.")

    operation = payload["operation"]
    parameters = payload["parameters"]

    if not isinstance(operation, str) or not operation.strip():
        raise InvalidRequestError("Field 'operation' must be a non-empty string.")

    if not isinstance(parameters, dict):
        raise InvalidRequestError("Field 'parameters' must be a JSON object.")

    return {
        "operation": operation.strip(),
        "parameters": parameters,
    }
