from __future__ import annotations

import os
import re
import subprocess
from typing import Any, Callable, Dict, List, Tuple

from app.config import ATM_SER_PATH, DATA_DIR, OCTAVE_BIN, OCTAVE_TIMEOUT_SECONDS
from app.domain.exceptions import (
    OperationExecutionError,
    OperationOutputError,
    OperationTimeoutError,
)


LegacyParser = Callable[[List[str], Dict[str, Any]], Dict[str, Any]]


def run_atm_ser(operation: str, parameters: Dict[str, Any]) -> Dict[str, Any]:
    cmd = _build_command(operation, parameters)
    atm_dir = os.path.dirname(str(ATM_SER_PATH))
    env = os.environ.copy()
    env['DATA_DIR'] = str(DATA_DIR)

    try:
        completed = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=OCTAVE_TIMEOUT_SECONDS,
            check=False,
            cwd=atm_dir,
            env=env,
        )
    except subprocess.TimeoutExpired as exc:
        raise OperationTimeoutError(
            f"Legacy backend timed out after {OCTAVE_TIMEOUT_SECONDS} seconds.",
            code="ATM_SER_TIMEOUT",
        ) from exc
    except OSError as exc:
        raise OperationExecutionError(
            f"Unable to start the legacy backend: {exc}",
            code="ATM_SER_LAUNCH_FAILED",
        ) from exc

    stdout = completed.stdout.strip()
    stderr = completed.stderr.strip()

    if completed.returncode != 0:
        raise OperationExecutionError(
            stderr or stdout or "Legacy backend execution failed.",
            code="OCTAVE_EXECUTION_FAILED",
        )

    if stdout.startswith("Error:"):
        raise OperationExecutionError(
            stdout[len("Error:"):].strip() or "Legacy backend execution failed.",
            code="ATM_SER_ERROR",
        )

    result = _parse_output(operation, stdout, parameters)
    return {
        "result": result,
        "plot_bytes": None,
    }


def _build_command(operation: str, params: Dict[str, Any]) -> list[str]:
    cmd = [OCTAVE_BIN, str(ATM_SER_PATH)]

    if operation == "legacy_iwv":
        cmd += ["iwv", params["date"], str(params["hour"])]
    elif operation == "legacy_opacity":
        cmd += ["opacity", params["date"], str(params["hour"]), _format_float(params["freq"])]
    elif operation == "legacy_meteo":
        cmd += ["meteo", params["date"], str(params["hour"])]
    elif operation == "legacy_rain":
        cmd += ["rain", params["date"], str(params["hour"])]
    elif operation == "legacy_tsys":
        cmd += [
            "tsys",
            params["date"],
            str(params["hour"]),
            _format_float(params["freq"]),
            _format_float(params["theta"]),
            _format_float(params["eta"]),
            _format_float(params["trec"]),
        ]
    else:
        raise OperationExecutionError(
            f"Unsupported legacy operation: {operation}",
            code="UNKNOWN_LEGACY_OPERATION",
        )

    return cmd


def _parse_output(operation: str, output: str, parameters: Dict[str, Any]) -> Dict[str, Any]:
    if not output.strip():
        raise OperationOutputError(
            "Legacy backend returned empty output.",
            code="EMPTY_LEGACY_OUTPUT",
        )

    lines = [line.strip() for line in output.splitlines() if line.strip()]
    parser = _PARSERS.get(operation)
    if parser is None:
        raise OperationOutputError(
            f"No parser registered for legacy operation: {operation}",
            code="UNSUPPORTED_LEGACY_OUTPUT",
        )
    return parser(lines, parameters)


def _parse_iwv(lines: List[str], parameters: Dict[str, Any]) -> Dict[str, Any]:
    if _is_series_request(parameters):
        metadata_lines, header_line, data_lines = _split_series_sections(lines)
        metadata = _parse_key_value_metadata(metadata_lines)
        _ensure_header(header_line, ["n.", "mjd", "IWV(mm)", "ILW(mm)", "ZDD(m)", "ZWD(m)", "Q"])
        rows = _parse_data_rows(data_lines, 7, "legacy_iwv")
        return {
            "metadata": metadata,
            "series": [
                {
                    "index": row[0],
                    "mjd": row[1],
                    "iwv_mm": row[2],
                    "ilw_mm": row[3],
                    "zdd_m": row[4],
                    "zwd_m": row[5],
                    "q": row[6],
                }
                for row in rows
            ],
        }

    row = _parse_single_row(lines, 5, "legacy_iwv")
    return {
        "iwv_mm": row[0],
        "ilw_mm": row[1],
        "zdd_m": row[2],
        "zwd_m": row[3],
        "q": row[4],
    }


def _parse_opacity(lines: List[str], parameters: Dict[str, Any]) -> Dict[str, Any]:
    if _is_series_request(parameters):
        metadata_lines, header_line, data_lines = _split_series_sections(lines)
        metadata = _parse_key_value_metadata(metadata_lines)
        _ensure_header(header_line, ["n.", "mjd", "tau(Np)", "Tmean(K)"])
        rows = _parse_data_rows(data_lines, 4, "legacy_opacity")
        return {
            "metadata": metadata,
            "series": [
                {
                    "index": row[0],
                    "mjd": row[1],
                    "tau_np": row[2],
                    "tmean_k": row[3],
                }
                for row in rows
            ],
        }

    row = _parse_single_row(lines, 2, "legacy_opacity")
    return {
        "tau_np": row[0],
        "tmean_k": row[1],
    }


def _parse_meteo(lines: List[str], parameters: Dict[str, Any]) -> Dict[str, Any]:
    if _is_series_request(parameters):
        metadata_lines, header_line, data_lines = _split_series_sections(lines)
        metadata = _parse_key_value_metadata(metadata_lines)
        _ensure_header(
            header_line,
            ["n.", "mjd", "T", "(K)", "DPT", "(K)", "RH", "(%)", "P", "(hPa)", "U", "(m/s)", "V", "(m/s)"],
        )
        rows = _parse_data_rows(data_lines, 8, "legacy_meteo")
        return {
            "metadata": metadata,
            "series": [
                {
                    "index": row[0],
                    "mjd": row[1],
                    "temperature_k": row[2],
                    "dew_point_k": row[3],
                    "relative_humidity_pct": row[4],
                    "pressure_hpa": row[5],
                    "u_wind_mps": row[6],
                    "v_wind_mps": row[7],
                }
                for row in rows
            ],
        }

    row = _parse_single_row(lines, 6, "legacy_meteo")
    return {
        "temperature_k": row[0],
        "dew_point_k": row[1],
        "relative_humidity_pct": row[2],
        "pressure_hpa": row[3],
        "u_wind_mps": row[4],
        "v_wind_mps": row[5],
    }


def _parse_rain(lines: List[str], parameters: Dict[str, Any]) -> Dict[str, Any]:
    if _is_series_request(parameters):
        metadata_lines, header_line, data_lines = _split_series_sections(lines)
        metadata = _parse_key_value_metadata(metadata_lines)
        _ensure_header(header_line, ["n.", "mjd", "RAIN", "(mm)"])
        rows = _parse_data_rows(data_lines, 3, "legacy_rain")
        return {
            "metadata": metadata,
            "series": [
                {
                    "index": row[0],
                    "mjd": row[1],
                    "rain_mm": row[2],
                }
                for row in rows
            ],
        }

    value = _parse_single_value(lines, "legacy_rain")
    return {"rain_mm": value}


def _parse_tsys(lines: List[str], parameters: Dict[str, Any]) -> Dict[str, Any]:
    if _is_series_request(parameters):
        metadata_lines, header_line, data_lines = _split_series_sections(lines)
        metadata = _parse_key_value_metadata(metadata_lines)
        _ensure_header(header_line, ["n.", "mjd", "Tsys(K)", "Tsys2(K)"])
        rows = _parse_data_rows(data_lines, 4, "legacy_tsys")
        return {
            "metadata": metadata,
            "series": [
                {
                    "index": row[0],
                    "mjd": row[1],
                    "tsys_k": row[2],
                    "tsys2_k": row[3],
                }
                for row in rows
            ],
        }

    row = _parse_single_row(lines, 2, "legacy_tsys")
    return {
        "tsys_k": row[0],
        "tsys2_k": row[1],
    }


_PARSERS: Dict[str, LegacyParser] = {
    "legacy_iwv": _parse_iwv,
    "legacy_opacity": _parse_opacity,
    "legacy_meteo": _parse_meteo,
    "legacy_rain": _parse_rain,
    "legacy_tsys": _parse_tsys,
}


def _is_series_request(parameters: Dict[str, Any]) -> bool:
    return int(parameters.get("hour", 0)) == 0


def _split_series_sections(lines: List[str]) -> Tuple[List[str], str, List[str]]:
    if len(lines) < 3:
        raise OperationOutputError(
            "Legacy series output is incomplete.",
            code="INVALID_LEGACY_SERIES_OUTPUT",
        )

    data_start_index = None
    for index, line in enumerate(lines):
        tokens = _split_tokens(line)
        if tokens and re.fullmatch(r"[+-]?\d+", tokens[0]):
            data_start_index = index
            break

    if data_start_index is None or data_start_index < 1:
        raise OperationOutputError(
            "Legacy series output does not contain a valid table.",
            code="INVALID_LEGACY_SERIES_OUTPUT",
        )

    metadata_lines = lines[: data_start_index - 1]
    header_line = lines[data_start_index - 1]
    data_lines = lines[data_start_index:]
    return metadata_lines, header_line, data_lines


def _parse_key_value_metadata(lines: List[str]) -> Dict[str, Any]:
    metadata: Dict[str, Any] = {}
    for line in lines:
        for raw_key, raw_value in re.findall(r"([^:\t]+):\s*([^\t]+)", line):
            key = _normalize_metadata_key(raw_key)
            metadata[key] = _coerce_value(raw_value.strip())
    return metadata


def _parse_data_rows(data_lines: List[str], expected_columns: int, operation: str) -> List[List[Any]]:
    rows: List[List[Any]] = []
    for line in data_lines:
        tokens = _split_tokens(line)
        if len(tokens) != expected_columns:
            raise OperationOutputError(
                f"Inconsistent column count in {operation} output.",
                code="INVALID_LEGACY_ROW",
            )
        rows.append([_coerce_token(token) for token in tokens])

    if not rows:
        raise OperationOutputError(
            f"No data rows found in {operation} output.",
            code="EMPTY_LEGACY_SERIES",
        )

    return rows


def _parse_single_row(lines: List[str], expected_columns: int, operation: str) -> List[Any]:
    if len(lines) != 1:
        raise OperationOutputError(
            f"Expected a single output row for {operation}.",
            code="INVALID_LEGACY_SINGLE_ROW",
        )

    tokens = _split_tokens(lines[0])
    if len(tokens) != expected_columns:
        raise OperationOutputError(
            f"Unexpected number of values in {operation} output.",
            code="INVALID_LEGACY_SINGLE_ROW",
        )

    return [_coerce_token(token) for token in tokens]


def _parse_single_value(lines: List[str], operation: str) -> float:
    values = _parse_single_row(lines, 1, operation)
    value = values[0]
    if not isinstance(value, (int, float)):
        raise OperationOutputError(
            f"Expected a numeric scalar value for {operation}.",
            code="INVALID_LEGACY_SCALAR",
        )
    return float(value)


def _ensure_header(header_line: str, expected_tokens: List[str]) -> None:
    actual_tokens = _split_tokens(header_line)
    if actual_tokens != expected_tokens:
        raise OperationOutputError(
            "Legacy header format is not recognized.",
            code="INVALID_LEGACY_HEADER",
        )


def _split_tokens(line: str) -> List[str]:
    return [token for token in re.split(r"[\t ]+", line.strip()) if token]


def _coerce_token(token: str) -> Any:
    try:
        if re.fullmatch(r"[+-]?\d+", token):
            return int(token)
        return float(token)
    except ValueError as exc:
        raise OperationOutputError(
            f"Non-numeric value found in legacy output: {token!r}.",
            code="INVALID_LEGACY_VALUE",
        ) from exc


def _coerce_value(raw_value: str) -> Any:
    value = raw_value.strip()
    try:
        return _coerce_token(value)
    except OperationOutputError:
        return value


def _normalize_metadata_key(raw_key: str) -> str:
    key = raw_key.strip().lower()
    key = key.replace(".", "")
    key = key.replace("%", "pct")
    key = key.replace("(", "_")
    key = key.replace(")", "")
    key = key.replace("/", "_")
    key = re.sub(r"[^a-z0-9]+", "_", key)
    return key.strip("_")


def _format_float(value: Any) -> str:
    return format(float(value), ".15g")
