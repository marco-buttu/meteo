"""Static declarative catalog of supported operations."""

from __future__ import annotations

from typing import Dict, Mapping


ParameterSchema = Dict[str, str]
OperationSchema = Dict[str, object]
OperationCatalog = Dict[str, OperationSchema]


OPERATION_CATALOG: OperationCatalog = {

    "data": {
        "description": "List available legacy data files from DATA_DIR/mdata.",
        "produces_result": True,
        "produces_plot": False,
        "required_parameters": {},
        "optional_parameters": {
            "year": "integer",
            "month": "integer",
            "day": "integer",
            "from": "string",
            "to": "string",
            "limit": "integer",
        },
    },
    "iwv": {
        "description": "Execute the native Python implementation of the IWV command.",
        "produces_result": True,
        "produces_plot": False,
        "required_parameters": {
            "date": "string",
            "hour": "integer",
        },
        "optional_parameters": {},
    },
    "meteo": {
        "description": "Execute the native Python implementation of the meteo command.",
        "produces_result": True,
        "produces_plot": False,
        "required_parameters": {
            "date": "string",
            "hour": "integer",
        },
        "optional_parameters": {},
    },
    "opacity": {
        "description": "Execute the native Python implementation of the opacity command.",
        "produces_result": True,
        "produces_plot": False,
        "required_parameters": {
            "date": "string",
            "hour": "integer",
            "freq": "float",
        },
        "optional_parameters": {},
    },
    "rain": {
        "description": "Execute the native Python implementation of the rain command.",
        "produces_result": True,
        "produces_plot": False,
        "required_parameters": {
            "date": "string",
            "hour": "integer",
        },
        "optional_parameters": {},
    },
    "tsys": {
        "description": "Execute the native Python implementation of the tsys command.",
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
