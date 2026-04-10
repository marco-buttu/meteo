"""Static declarative catalog of supported operations."""

from __future__ import annotations

from typing import Dict, Mapping


ParameterSchema = Dict[str, str]
OperationSchema = Dict[str, object]
OperationCatalog = Dict[str, OperationSchema]


OPERATION_CATALOG: OperationCatalog = {
    "get_precipitable_water_vapor": {
        "description": "Estimate precipitable water vapor for a given site and time.",
        "produces_result": True,
        "produces_plot": False,
        "required_parameters": {
            "timestamp": "datetime_iso8601",
            "site_lat": "float",
            "site_lon": "float",
        },
        "optional_parameters": {
            "site_alt_m": "float",
        },
    },
    "get_wind_profile": {
        "description": "Return wind speed profile as a function of altitude.",
        "produces_result": True,
        "produces_plot": True,
        "required_parameters": {
            "timestamp": "datetime_iso8601",
            "site_lat": "float",
            "site_lon": "float",
            "max_altitude_m": "float",
        },
        "optional_parameters": {
            "step_m": "float",
        },
    },
    "get_system_temperature_estimate": {
        "description": "Estimate system temperature for a given observing setup.",
        "produces_result": True,
        "produces_plot": False,
        "required_parameters": {
            "frequency_ghz": "float",
            "elevation_deg": "float",
            "pwv_mm": "float",
        },
        "optional_parameters": {
            "receiver_band": "string",
        },
    },
    "plot_opacity_timeseries": {
        "description": "Generate an opacity time series plot for a time interval.",
        "produces_result": True,
        "produces_plot": True,
        "required_parameters": {
            "start_time": "datetime_iso8601",
            "end_time": "datetime_iso8601",
            "site_lat": "float",
            "site_lon": "float",
        },
        "optional_parameters": {
            "frequency_ghz": "float",
        },
    },
    "legacy_iwv": {
        "description": "Execute the legacy 'iwv' command through the legacy backend.",
        "produces_result": True,
        "produces_plot": False,
        "required_parameters": {
            "date": "string",
            "hour": "integer",
        },
        "optional_parameters": {},
    },
    "legacy_opacity": {
        "description": "Execute the legacy 'opacity' command through the legacy backend.",
        "produces_result": True,
        "produces_plot": False,
        "required_parameters": {
            "date": "string",
            "hour": "integer",
            "freq": "float",
        },
        "optional_parameters": {},
    },
    "legacy_meteo": {
        "description": "Execute the legacy 'meteo' command through the legacy backend.",
        "produces_result": True,
        "produces_plot": False,
        "required_parameters": {
            "date": "string",
            "hour": "integer",
        },
        "optional_parameters": {},
    },
    "legacy_rain": {
        "description": "Execute the legacy 'rain' command through the legacy backend.",
        "produces_result": True,
        "produces_plot": False,
        "required_parameters": {
            "date": "string",
            "hour": "integer",
        },
        "optional_parameters": {},
    },
    "legacy_tsys": {
        "description": "Execute the legacy 'tsys' command through the legacy backend.",
        "produces_result": True,
        "produces_plot": False,
        "required_parameters": {
            "date": "string",
            "hour": "integer",
            "freq": "float",
            "theta": "float",
            "eta": "float",
            "trec": "float",
        },
        "optional_parameters": {},
    },
}


SUPPORTED_TYPE_NAMES = (
    "string",
    "float",
    "integer",
    "datetime_iso8601",
)


def get_operation_catalog() -> Mapping[str, OperationSchema]:
    """Return the full static operation catalog."""

    return OPERATION_CATALOG
