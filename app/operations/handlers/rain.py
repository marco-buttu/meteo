"""Native Python implementation of the legacy rain operation."""

from __future__ import annotations

from math import floor
from pathlib import Path
from typing import Any

from app.config import DATA_DIR
from app.domain.exceptions import OperationExecutionError
from app.integrations.octave_mdata_reader import MData, read_mdata_file

LEGACY_DECIMALS = 6
LEGACY_MJD_DECIMALS = 3


def handle(params: dict[str, Any]) -> dict[str, Any]:
    data_path = _resolve_data_file(params["date"])
    if not data_path.exists():
        raise OperationExecutionError("file not found", code="ATM_SER_ERROR")

    mdata = read_mdata_file(data_path)
    hour = int(params["hour"])

    if hour == 0:
        return {
            "result": _build_series_result(data_timestamp=params["date"][1:], mdata=mdata),
            "plot_bytes": None,
        }

    if hour < 1 or hour > mdata.nh:
        raise OperationExecutionError("bad argument", code="ATM_SER_ERROR")

    return {
        "result": _build_single_result(mdata=mdata, epoch_index=hour - 1),
        "plot_bytes": None,
    }


def _resolve_data_file(legacy_date: str) -> Path:
    db_prefix = legacy_date[0].upper()
    timestamp = legacy_date[1:]

    if db_prefix == "A":
        return DATA_DIR / "mdata" / f"{timestamp}.dat"
    if db_prefix == "B":
        return DATA_DIR / "oldmdata" / f"{timestamp}.dat"

    raise OperationExecutionError("db not found", code="ATM_SER_ERROR")


def _build_single_result(*, mdata: MData, epoch_index: int) -> dict[str, float]:
    return {
        "rain_mm": _round_legacy_float(mdata.crain[0][epoch_index]),
    }


def _build_series_result(*, data_timestamp: str, mdata: MData) -> dict[str, Any]:
    year = int(data_timestamp[0:4])
    month = int(data_timestamp[4:6])
    day = int(data_timestamp[6:8])
    model_hour = int(mdata.date[11:13])
    mjd = _mjd(year, month, day, model_hour, 0, 0)
    step_days = mdata.step / 24.0

    series = []
    for index in range(mdata.nh):
        row = _build_single_result(mdata=mdata, epoch_index=index)
        row = {
            "index": index + 1,
            "mjd": _round_legacy_mjd(mjd),
            **row,
        }
        series.append(row)
        mjd += step_days

    return {
        "metadata": {"epoch": int(data_timestamp)},
        "series": series,
    }


def _round_legacy_float(value: float) -> float:
    return round(float(value), LEGACY_DECIMALS)


def _round_legacy_mjd(value: float) -> float:
    return round(float(value), LEGACY_MJD_DECIMALS)


def _mjd(year: int, month: int, day: int, hour: int, minute: int, second: int) -> float:
    a = floor((14 - month) / 12)
    y = year + 4800 - a
    m = month + 12 * a - 3
    julian_day = (
        day
        + floor((153 * m + 2) / 5)
        + y * 365
        + floor(y / 4)
        - floor(y / 100)
        + floor(y / 400)
        - 32045
        + (second + 60 * minute + 3600 * (hour - 12)) / 86400
    )
    return julian_day - 2400000.5
