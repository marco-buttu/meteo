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
FLASK_DEBUG = os.getenv('FLASK_DEBUG', '').strip().lower() in {
    '1',
    'true',
    'yes',
    'on',
}
