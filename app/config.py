from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv


BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / '.env')


def _get_int_env(name: str, default: int) -> int:
    raw_value = os.getenv(name)
    if raw_value is None:
        return default

    try:
        return int(raw_value)
    except ValueError as exc:
        raise ValueError(
            'Environment variable {name!r} must be an integer.'.format(name=name)
        ) from exc


def _get_bool_env(name: str, default: bool = False) -> bool:
    raw_value = os.getenv(name)
    if raw_value is None:
        return default

    return raw_value.strip().lower() in {
        '1',
        'true',
        'yes',
        'on',
    }


def _get_path_env(name: str, default: Path | str | None = None) -> Path:
    raw_value = os.getenv(name)
    if raw_value is None:
        if default is None:
            raise ValueError(
                'Environment variable {name!r} is required.'.format(name=name)
            )
        raw_value = str(default)

    return Path(raw_value).expanduser().resolve()


JOB_STORAGE_DIR = _get_path_env(
    'JOB_STORAGE_DIR',
    BASE_DIR / 'runtime_data' / 'jobs',
)

PLOT_STORAGE_DIR = _get_path_env(
    'PLOT_STORAGE_DIR',
    BASE_DIR / 'runtime_data' / 'plots',
)

ATM_SER_PATH = _get_path_env(
    'ATM_SER_PATH',
    BASE_DIR / 'octave' / 'scripts' / 'atm_ser',
)

OCTAVE_BIN = os.getenv('OCTAVE_BIN', 'octave-cli')
OCTAVE_TIMEOUT_SECONDS = _get_int_env('OCTAVE_TIMEOUT_SECONDS', 30)

DATA_DIR = _get_path_env('DATA_DIR')

REDIS_URL = os.getenv('REDIS_URL', 'redis://127.0.0.1:6379/0')
RQ_QUEUE_NAME = os.getenv('RQ_QUEUE_NAME', 'default')

FLASK_HOST = os.getenv('FLASK_HOST', '127.0.0.1')
FLASK_PORT = _get_int_env('FLASK_PORT', 5000)
FLASK_DEBUG = _get_bool_env('FLASK_DEBUG', False)

# Application-level hardening defaults. These are intentionally conservative
# and can be overridden from .env when needed.
MAX_JSON_BODY_BYTES = _get_int_env('MAX_JSON_BODY_BYTES', 65536)
MAX_LEGACY_COMMAND_LENGTH = _get_int_env('MAX_LEGACY_COMMAND_LENGTH', 256)
DATA_OPERATION_DEFAULT_LIMIT = _get_int_env('DATA_OPERATION_DEFAULT_LIMIT', 1000)
DATA_OPERATION_MAX_LIMIT = _get_int_env('DATA_OPERATION_MAX_LIMIT', 5000)
LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO').strip().upper() or 'INFO'
