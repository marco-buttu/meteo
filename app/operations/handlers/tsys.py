"""Native Python implementation of the legacy tsys operation."""

from __future__ import annotations

from math import cos, exp, floor, pi
from typing import Any

from app.domain.exceptions import OperationExecutionError
from app.integrations.octave_mdata_reader import MData, read_mdata_file
from app.operations.handlers.opacity import (
    _compute_radiative_mean_temperature_series,
    _compute_tau_series,
    _resolve_data_file,
)

LEGACY_DECIMALS = 6
LEGACY_MJD_DECIMALS = 3
LEGACY_THREE_DECIMALS = 3


def handle(params: dict[str, Any]) -> dict[str, Any]:
    data_path = _resolve_data_file(params["date"])
    if not data_path.exists():
        raise OperationExecutionError("file not found", code="ATM_SER_ERROR")

    mdata = read_mdata_file(data_path)
    hour = int(params["hour"])
    freq = float(params["freq"])
    theta = _clamp_theta(float(params["theta"]))
    eta = float(params["eta"])
    trec = float(params["trec"])

    tau = _compute_tau_series(mdata, freq)
    tmean = _compute_radiative_mean_temperature_series(mdata, freq)
    ground_temperature = _compute_ground_temperature_series(mdata)
    tsys_values, tsys2_values, etaf = _compute_tsys_series(
        tau=tau,
        tmean=tmean,
        ground_temperature=ground_temperature,
        freq=freq,
        theta=theta,
        eta=eta,
        trec=trec,
    )

    if hour == 0:
        return {
            "result": _build_series_result(
                data_timestamp=params["date"][1:],
                mdata=mdata,
                freq=freq,
                theta=theta,
                eta=eta,
                trec=trec,
                etaf=etaf,
                tsys_values=tsys_values,
                tsys2_values=tsys2_values,
            ),
            "plot_bytes": None,
        }

    if hour < 1 or hour > mdata.nh:
        raise OperationExecutionError("bad argument", code="ATM_SER_ERROR")

    index = hour - 1
    return {
        "result": _build_single_result(tsys_values[index], tsys2_values[index]),
        "plot_bytes": None,
    }


def _clamp_theta(theta: float) -> float:
    if theta < 6.0:
        return 6.0
    if theta > 90.0:
        return 90.0
    return theta


def _compute_ground_temperature_series(mdata: MData) -> list[float]:
    return [float(mdata.tmp[0][index]) for index in range(mdata.nh)]


def _compute_tsys_series(
    *,
    tau: list[float],
    tmean: list[float],
    ground_temperature: list[float],
    freq: float,
    theta: float,
    eta: float,
    trec: float,
) -> tuple[list[float], list[float], float]:
    a = 0.997
    b = 0.426
    c = 46.92
    d = 5.7
    etaf = a - b / (1 + (freq / c) ** d)
    phi = 90.0 - theta
    air_mass = 1.0 / cos(phi * pi / 180.0)
    receiver_image_ratio = 10.0
    receiver_factor = 1.0 + 1.0 / receiver_image_ratio
    fixed_ground_temperature = 293.0

    tsys_values: list[float] = []
    tsys2_values: list[float] = []
    for index, tau_value in enumerate(tau):
        sky_emission = 1.0 - exp(-tau_value * air_mass)
        tsys = tmean[index] * eta * sky_emission + (1.0 - eta) * ground_temperature[index] + trec
        tsys2 = receiver_factor * (
            tmean[index] * etaf * sky_emission
            + (1.0 - etaf) * fixed_ground_temperature
            + trec
        )
        tsys_values.append(tsys)
        tsys2_values.append(tsys2)

    return tsys_values, tsys2_values, etaf


def _build_single_result(tsys_k: float, tsys2_k: float) -> dict[str, float]:
    return {
        "tsys_k": _round_legacy_float(tsys_k),
        "tsys2_k": _round_legacy_float(tsys2_k),
    }


def _build_series_result(
    *,
    data_timestamp: str,
    mdata: MData,
    freq: float,
    theta: float,
    eta: float,
    trec: float,
    etaf: float,
    tsys_values: list[float],
    tsys2_values: list[float],
) -> dict[str, Any]:
    year = int(data_timestamp[0:4])
    month = int(data_timestamp[4:6])
    day = int(data_timestamp[6:8])
    model_hour = int(mdata.date[11:13])
    mjd = _mjd(year, month, day, model_hour, 0, 0)
    step_days = mdata.step / 24.0

    series = []
    for index in range(mdata.nh):
        row = _build_single_result(tsys_values[index], tsys2_values[index])
        row = {
            "index": index + 1,
            "mjd": _round_legacy_mjd(mjd),
            **row,
        }
        series.append(row)
        mjd += step_days

    return {
        "metadata": {
            "epoch": int(data_timestamp),
            "freq_ghz": _round_legacy_three(freq),
            "trec_k": _round_legacy_three(trec),
            "theta_deg": _round_legacy_three(theta),
            "eta": _round_legacy_three(eta),
            "etaf": _round_legacy_three(etaf),
        },
        "series": series,
    }


def _round_legacy_float(value: float) -> float:
    return round(float(value), LEGACY_DECIMALS)


def _round_legacy_mjd(value: float) -> float:
    return round(float(value), LEGACY_MJD_DECIMALS)


def _round_legacy_three(value: float) -> float:
    return round(float(value), LEGACY_THREE_DECIMALS)


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
