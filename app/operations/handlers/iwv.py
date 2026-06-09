"""Native Python implementation of the legacy IWV operation."""

from __future__ import annotations

from math import exp, floor
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
    iwv, ilw, zdd, zwd = _compute_iwv_series(mdata)

    if hour == 0:
        return {
            "result": _build_series_result(
                data_timestamp=params["date"][1:],
                mdata=mdata,
                iwv=iwv,
                ilw=ilw,
                zdd=zdd,
                zwd=zwd,
            ),
            "plot_bytes": None,
        }

    if hour < 1 or hour > mdata.nh:
        raise OperationExecutionError("bad argument", code="ATM_SER_ERROR")

    index = hour - 1
    return {
        "result": _build_single_result(iwv[index], ilw[index], zdd[index], zwd[index]),
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


def _compute_iwv_series(mdata: MData) -> tuple[list[float], list[float], list[float], list[float]]:
    iwv_values: list[float] = []
    ilw_values: list[float] = []
    zdd_values: list[float] = []
    zwd_values: list[float] = []

    for epoch in range(mdata.nh):
        tmp = _column(mdata.tmp, epoch)
        dpt = _column(mdata.dpt, epoch)
        prs = _column(mdata.prs, epoch)
        hgt = _column(mdata.hgt, epoch)
        clw = _column(mdata.clwmr, epoch)
        rh = _column(mdata.rh, epoch)
        zdd, zwd, ilw, iwv = _pwl5(tmp, dpt, prs, hgt, clw, rh)
        iwv_values.append(iwv)
        ilw_values.append(ilw)
        zdd_values.append(zdd)
        zwd_values.append(zwd)

    return iwv_values, ilw_values, zdd_values, zwd_values


def _column(matrix: list[list[float]], index: int) -> list[float]:
    return [row[index] for row in matrix]


def _pwl5(
    tmp: list[float],
    dpt: list[float],
    prs: list[float],
    hgt: list[float],
    clw: list[float],
    rh: list[float],
) -> tuple[float, float, float, float]:
    # Constants and formulas mirror octave/scripts/pwl5.m.
    g = 9.784
    rd = 287.05
    rs = 8.314472
    mw = 0.018015
    md = 0.0289644
    eps0 = mw / md
    k1 = 77.60
    k2 = 70.4
    k3 = 3.739e5
    t0 = 273.15

    dpt_c = [value - t0 for value in dpt]
    e = [exp(1.81 + 17.27 * value / (value + 237.5)) for value in dpt_c]
    q = [eps0 * e_value / prs_value for e_value, prs_value in zip(e, prs)]

    zwd0 = [
        (q_value * rd / g / eps0) * ((k2 - k1 * eps0) + k3 / tmp_value)
        for q_value, tmp_value in zip(q, tmp)
    ]
    zwd = _trapz([-value for value in prs], zwd0) * 1e-6
    zdd = k1 * rd / g * prs[0] * 1e-6

    tm = 0.673 * tmp[0] + 83.0
    c_factor = 1e6 * mw / (k2 - k1 * eps0 + k3 / tm) / rs
    _pw = zwd * c_factor * 100.0

    temp_c = [value - t0 for value in tmp]
    rho = [
        1e-3
        * 216.7
        * (rh_value / 100.0 * 6.112 * exp(17.62 * t_value / (243.12 + t_value)) / tmp_value)
        for rh_value, t_value, tmp_value in zip(rh, temp_c, tmp)
    ]
    iwv = _trapz(hgt, rho)

    air_density = [100.0 * prs_value / (rd * tmp_value) for prs_value, tmp_value in zip(prs, tmp)]
    liquid_water_content = [ad_value * clw_value for ad_value, clw_value in zip(air_density, clw)]
    ilw = _trapz(hgt, liquid_water_content)

    return zdd, zwd, ilw, iwv


def _trapz(x_values: list[float], y_values: list[float]) -> float:
    total = 0.0
    for index in range(len(x_values) - 1):
        dx = x_values[index + 1] - x_values[index]
        total += 0.5 * dx * (y_values[index + 1] + y_values[index])
    return total


def _build_single_result(iwv: float, ilw: float, zdd: float, zwd: float) -> dict[str, float]:
    return {
        "iwv_mm": _round_legacy_float(iwv),
        "ilw_mm": _round_legacy_float(ilw),
        "zdd_m": _round_legacy_float(zdd),
        "zwd_m": _round_legacy_float(zwd),
        "q": _round_legacy_float(_q_value(iwv, zwd)),
    }


def _build_series_result(
    *,
    data_timestamp: str,
    mdata: MData,
    iwv: list[float],
    ilw: list[float],
    zdd: list[float],
    zwd: list[float],
) -> dict[str, Any]:
    year = int(data_timestamp[0:4])
    month = int(data_timestamp[4:6])
    day = int(data_timestamp[6:8])
    model_hour = int(mdata.date[11:13])
    mjd = _mjd(year, month, day, model_hour, 0, 0)
    step_days = mdata.step / 24.0

    series = []
    for index in range(mdata.nh):
        series.append(
            {
                "index": index + 1,
                "mjd": _round_legacy_mjd(mjd),
                "iwv_mm": _round_legacy_float(iwv[index]),
                "ilw_mm": _round_legacy_float(ilw[index]),
                "zdd_m": _round_legacy_float(zdd[index]),
                "zwd_m": _round_legacy_float(zwd[index]),
                "q": _round_legacy_float(_q_value(iwv[index], zwd[index])),
            }
        )
        mjd += step_days

    return {
        "metadata": {"epoch": int(data_timestamp)},
        "series": series,
    }


def _round_legacy_float(value: float) -> float:
    return round(float(value), LEGACY_DECIMALS)


def _round_legacy_mjd(value: float) -> float:
    return round(float(value), LEGACY_MJD_DECIMALS)


def _q_value(iwv: float, zwd: float) -> float:
    return 1e-3 * iwv / zwd


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
