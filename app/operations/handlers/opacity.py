"""Native Python implementation of the legacy opacity operation."""

from __future__ import annotations

from math import exp, floor, sqrt
from pathlib import Path
from typing import Any

import numpy as np

from app.config import DATA_DIR
from app.domain.exceptions import OperationExecutionError
from app.integrations.octave_mdata_reader import MData, read_mdata_file

LEGACY_DECIMALS = 6
LEGACY_MJD_DECIMALS = 3
LEGACY_FREQ_DECIMALS = 3


def handle(params: dict[str, Any]) -> dict[str, Any]:
    data_path = _resolve_data_file(params["date"])
    if not data_path.exists():
        raise OperationExecutionError("file not found", code="ATM_SER_ERROR")

    mdata = read_mdata_file(data_path)
    hour = int(params["hour"])
    freq = float(params["freq"])
    tau = _compute_tau_series(mdata, freq)
    tmean = _compute_radiative_mean_temperature_series(mdata, freq)

    if hour == 0:
        return {
            "result": _build_series_result(
                data_timestamp=params["date"][1:],
                mdata=mdata,
                freq=freq,
                tau=tau,
                tmean=tmean,
            ),
            "plot_bytes": None,
        }

    if hour < 1 or hour > mdata.nh:
        raise OperationExecutionError("bad argument", code="ATM_SER_ERROR")

    index = hour - 1
    return {
        "result": _build_single_result(tau[index], tmean[index]),
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


def _build_single_result(tau_np: float, tmean_k: float) -> dict[str, float]:
    return {
        "tau_np": _round_legacy_float(tau_np),
        "tmean_k": _round_legacy_float(tmean_k),
    }


def _build_series_result(
    *,
    data_timestamp: str,
    mdata: MData,
    freq: float,
    tau: list[float],
    tmean: list[float],
) -> dict[str, Any]:
    year = int(data_timestamp[0:4])
    month = int(data_timestamp[4:6])
    day = int(data_timestamp[6:8])
    model_hour = int(mdata.date[11:13])
    mjd = _mjd(year, month, day, model_hour, 0, 0)
    step_days = mdata.step / 24.0

    series = []
    for index in range(mdata.nh):
        row = _build_single_result(tau[index], tmean[index])
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
            "freq_ghz": _round_legacy_freq(freq),
        },
        "series": series,
    }


def _compute_tau_series(mdata: MData, freq: float) -> list[float]:
    values: list[float] = []
    for epoch in range(mdata.nh):
        tmp = _column_array(mdata.tmp, epoch)
        prs = _column_array(mdata.prs, epoch)
        hgt_km = _column_array(mdata.hgt, epoch) / 1000.0
        rh = _column_array(mdata.rh, epoch)
        clw = _column_array(mdata.clwmr, epoch)
        ka = _ka_freq2(freq, _water_vapor_density(tmp, rh), prs, tmp, _liquid_water_content(prs, tmp, clw))
        values.append(float(np.trapezoid(ka, hgt_km)))
    return values


def _compute_radiative_mean_temperature_series(mdata: MData, freq: float) -> list[float]:
    values: list[float] = []
    for epoch in range(mdata.nh):
        if not mdata.isok:
            values.append(0.0)
            continue

        tmp = _column_array(mdata.tmp, epoch)
        prs = _column_array(mdata.prs, epoch)
        hgt_m = _column_array(mdata.hgt, epoch)
        hgt_km = hgt_m * 1e-3
        rh = _column_array(mdata.rh, epoch)
        clw = _column_array(mdata.clwmr, epoch)
        rvap = _water_vapor_density(tmp, rh)
        ka = _ka_freq2(freq, rvap, prs, tmp, _liquid_water_content(prs, tmp, clw))
        cumulative_tau = _cumulative_trapezoid(hgt_km, ka)
        attenuation = np.exp(-cumulative_tau)
        numerator = float(np.trapezoid(ka * tmp * attenuation, hgt_km))
        denominator = float(np.trapezoid(ka * attenuation, hgt_km))
        values.append(numerator / denominator)
    return values


def _column_array(matrix: list[list[float]], index: int) -> np.ndarray:
    return np.array([row[index] for row in matrix], dtype=float)


def _water_vapor_density(tmp: np.ndarray, rh: np.ndarray) -> np.ndarray:
    temperature_c = tmp - 273.15
    return 216.7 * (rh / 100.0 * 6.112 * np.exp(17.62 * temperature_c / (243.12 + temperature_c)) / tmp)


def _liquid_water_content(prs: np.ndarray, tmp: np.ndarray, clw: np.ndarray) -> np.ndarray:
    rd = 287.05
    air_density = 100.0 * prs / (rd * tmp)
    return 1e3 * air_density * clw


def _cumulative_trapezoid(x: np.ndarray, y: np.ndarray) -> np.ndarray:
    result = np.zeros_like(y, dtype=float)
    for index in range(1, len(y)):
        result[index] = float(np.trapezoid(y[: index + 1], x[: index + 1]))
    return result


def _ka_freq2(freq: float, ro_v: np.ndarray, pressure: np.ndarray, tatm: np.ndarray, water: np.ndarray) -> np.ndarray:
    freq_p = np.array([
        56.2648,
        58.4466,
        59.5920,
        60.4348,
        61.1506,
        61.8002,
        62.4112,
        62.9980,
        63.5685,
        64.1278,
        64.6789,
        65.2241,
        65.7647,
        66.3020,
        66.8367,
        67.3694,
        67.9007,
        68.4308,
        68.9601,
        69.4887,
    ])
    freq_m = np.array([
        118.7503,
        62.4863,
        60.3061,
        59.1642,
        58.3239,
        57.6125,
        56.9682,
        56.3634,
        55.7838,
        55.2214,
        54.6711,
        54.1300,
        53.5957,
        53.0668,
        52.5422,
        52.0212,
        51.5030,
        50.9873,
        50.4736,
        49.9618,
    ])
    y_p = np.array([
        4.51,
        4.94,
        3.52,
        1.86,
        0.33,
        -1.03,
        -2.23,
        -3.32,
        -4.32,
        -5.26,
        -6.13,
        -6.99,
        -7.74,
        -8.61,
        -9.11,
        -10.3,
        -9.87,
        -13.2,
        -7.07,
        -25.8,
    ]) * 1e-4
    y_m = np.array([
        -0.214,
        -3.78,
        -3.92,
        -2.68,
        -1.13,
        0.344,
        1.65,
        2.84,
        3.91,
        4.93,
        5.84,
        6.76,
        7.55,
        8.47,
        9.01,
        10.3,
        9.86,
        13.3,
        7.01,
        26.4,
    ]) * 1e-4

    gamma_j = 1.18 * (pressure / 1013.0) * ((300.0 / tatm) ** 0.85)
    gamma_b = 0.49 * (pressure / 1013.0) * ((300.0 / tatm) ** 0.89)
    fo2 = (0.7 * gamma_b) / (freq**2 + gamma_b**2)

    for index in range(20):
        j = (index + 1) * 2 - 1
        fi_j = 4.6e-3 * (300.0 / tatm) * (2 * j + 1) * np.exp(-6.89e-3 * (300.0 / tatm) * j * (j + 1))
        d_plus = _d_jp(j)
        d_minus = _d_jm(j)
        g_p_freqp = (gamma_j * (d_plus**2) + (freq - freq_p[index]) * y_p[index] * pressure) / ((freq - freq_p[index]) ** 2 + gamma_j**2)
        g_m_freqp = (gamma_j * (d_minus**2) + (freq - freq_m[index]) * y_m[index] * pressure) / ((freq - freq_m[index]) ** 2 + gamma_j**2)
        g_p_freqm = (gamma_j * (d_plus**2) + (-freq - freq_p[index]) * y_p[index] * pressure) / ((-freq - freq_p[index]) ** 2 + gamma_j**2)
        g_m_freqm = (gamma_j * (d_minus**2) + (-freq - freq_m[index]) * y_m[index] * pressure) / ((-freq - freq_m[index]) ** 2 + gamma_j**2)
        fo2 = fo2 + fi_j * (g_p_freqp + g_p_freqm + g_m_freqp + g_m_freqm)

    ko2 = 1.61e-2 * freq**2 * (pressure / 1013.0) * ((300.0 / tatm) ** 2) * fo2

    delta_k = 4.75e-6 * ro_v * (pressure / 1013.0) * ((300.0 / tatm) ** 2.1) * (freq**2)
    freq_i = np.array([22.23515, 183.31012, 323.0, 325.1538, 380.1968, 390.0, 436.0, 438.0, 442.0, 448.0008])
    energy = np.array([644.0, 196.0, 1850.0, 454.0, 306.0, 2199.0, 1507.0, 1070.0, 1507.0, 412.0])
    a_coeff = np.array([1.0, 41.9, 334.4, 115.7, 651.8, 127.0, 191.4, 697.6, 590.2, 973.1])
    gamma_i0 = np.array([2.85, 2.68, 2.3, 3.03, 3.19, 2.11, 1.5, 1.94, 1.51, 2.47])
    a = np.array([1.75, 2.03, 1.95, 1.85, 1.82, 2.03, 1.97, 2.01, 2.02, 2.19])
    x = np.array([0.626, 0.649, 0.420, 0.619, 0.630, 0.330, 0.290, 0.360, 0.332, 0.510])

    kh2o = delta_k.copy()
    for index in range(10):
        gamma_i = gamma_i0[index] * (pressure / 1013.0) * ((300.0 / tatm) ** x[index]) * (1 + 1e-2 * a[index] * ((ro_v * tatm) / pressure))
        fh2o = gamma_i / ((freq_i[index] ** 2 - freq**2) ** 2 + 4 * freq**2 * (gamma_i**2))
        kh2o = kh2o + (2 * freq**2 * a_coeff[index]) * ro_v * ((300.0 / tatm) ** 2.5) * np.exp(-energy[index] / tatm) * fh2o

    th = 300.0 / tatm
    gamma1 = 20.20 - 146 * (th - 1) + 316 * (th - 1) ** 2
    gamma2 = 39.8 * gamma1
    e0 = 77.66 + 103.3 * (th - 1)
    e1 = 0.0671 * e0
    e2 = 3.52
    er_r = e0 - freq**2 * ((e0 - e1) / (freq**2 + gamma1**2) + (e1 - e2) / (freq**2 + gamma2**2))
    er_i = freq * (gamma1 * (e0 - e1) / (freq**2 + gamma1**2) + gamma2 * (e1 - e2) / (freq**2 + gamma2**2))
    refractivity = 4.5 * water * (er_i / ((er_r + 2) ** 2 + er_i**2))
    kliq = 0.1820 * freq * refractivity

    ka_db = kh2o + ko2 + kliq
    return 0.1 * np.log(10.0) * ka_db


def _d_jp(j: int) -> float:
    return sqrt((j * (2 * j + 3)) / ((j + 1) * (2 * j + 1)))


def _d_jm(j: int) -> float:
    return sqrt(((j + 1) * (2 * j - 1)) / (j * (2 * j + 1)))


def _round_legacy_float(value: float) -> float:
    return round(float(value), LEGACY_DECIMALS)


def _round_legacy_mjd(value: float) -> float:
    return round(float(value), LEGACY_MJD_DECIMALS)


def _round_legacy_freq(value: float) -> float:
    return round(float(value), LEGACY_FREQ_DECIMALS)


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
