from __future__ import annotations

import re
from typing import Any, Dict


DATA_TIMESTAMP_PATTERN = re.compile(r"^\d{10}$")


class LegacyCommandError(Exception):
    def __init__(self, code: str, message: str):
        self.code = code
        self.message = message
        super().__init__(message)


def parse_legacy_command(command: str) -> Dict[str, Any]:
    if not command or not command.strip():
        raise LegacyCommandError("INVALID_REQUEST", "Empty command")

    parts = [p.strip() for p in command.split(",")]
    if any(part == "" for part in parts):
        raise LegacyCommandError("INVALID_PARAMETER", "Command contains an empty field")

    instr = parts[0]

    if instr == "iwv":
        _check_len(parts, 3)
        return {
            "operation": "legacy_iwv",
            "parameters": {
                "date": "A" + _parse_data_timestamp(parts[1]),
                "hour": _parse_hour(parts[2]),
            },
        }

    if instr == "opacity":
        _check_len(parts, 4)
        return {
            "operation": "legacy_opacity",
            "parameters": {
                "date": "A" + _parse_data_timestamp(parts[1]),
                "hour": _parse_hour(parts[2]),
                "freq": _parse_float(parts[3], "freq"),
            },
        }

    if instr == "meteo":
        _check_len(parts, 3)
        return {
            "operation": "legacy_meteo",
            "parameters": {
                "date": "A" + _parse_data_timestamp(parts[1]),
                "hour": _parse_hour(parts[2]),
            },
        }

    if instr == "rain":
        _check_len(parts, 3)
        return {
            "operation": "legacy_rain",
            "parameters": {
                "date": "A" + _parse_data_timestamp(parts[1]),
                "hour": _parse_hour(parts[2]),
            },
        }

    if instr == "tsys":
        _check_len(parts, 7)
        return {
            "operation": "legacy_tsys",
            "parameters": {
                "date": "A" + _parse_data_timestamp(parts[1]),
                "hour": _parse_hour(parts[2]),
                "freq": _parse_float(parts[3], "freq"),
                "theta": _parse_float(parts[4], "theta"),
                "eta": _parse_float(parts[5], "eta"),
                "trec": _parse_float(parts[6], "trec"),
            },
        }

    raise LegacyCommandError("UNKNOWN_COMMAND", f"Unknown command: {instr}")


def _check_len(parts: list[str], expected: int) -> None:
    if len(parts) != expected:
        raise LegacyCommandError(
            "INVALID_PARAMETER_COUNT",
            f"Expected {expected - 1} parameters, got {len(parts) - 1}",
        )


def _parse_data_timestamp(value: str) -> str:
    if not DATA_TIMESTAMP_PATTERN.fullmatch(value):
        raise LegacyCommandError(
            "INVALID_PARAMETER",
            "Data timestamp must use YYYYMMDDHH format",
        )
    return value


def _parse_hour(value: str) -> int:
    try:
        hour = int(value)
    except ValueError as exc:
        raise LegacyCommandError(
            "INVALID_PARAMETER_TYPE",
            "Parameter 'hour' must be an integer",
        ) from exc

    # Keep this validation structural only. The legacy backend decides whether
    # the requested epoch exists for the selected data file, so out-of-range
    # epochs must be accepted as jobs and fail asynchronously in the worker.
    if hour < 0:
        raise LegacyCommandError(
            "INVALID_PARAMETER",
            "Parameter 'hour' must be greater than or equal to 0",
        )
    return hour


def _parse_float(value: str, parameter_name: str) -> float:
    try:
        return float(value)
    except ValueError as exc:
        raise LegacyCommandError(
            "INVALID_PARAMETER_TYPE",
            "Parameter '{name}' must be a number".format(name=parameter_name),
        ) from exc
