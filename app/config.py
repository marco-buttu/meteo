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


JOB_STORAGE_DIR = Path(
    os.getenv('JOB_STORAGE_DIR', BASE_DIR / 'runtime_data' / 'jobs')
).resolve()

PLOT_STORAGE_DIR = Path(
    os.getenv('PLOT_STORAGE_DIR', BASE_DIR / 'runtime_data' / 'plots')
).resolve()

ATM_SER_PATH = Path(BASE_DIR / 'octave' / 'scripts' / 'atm_ser')

OCTAVE_BIN = os.getenv('OCTAVE_BIN', 'octave-cli')
OCTAVE_TIMEOUT_SECONDS = _get_int_env('OCTAVE_TIMEOUT_SECONDS', 30)

DATA_DIR = Path(os.getenv('DATA_DIR')).resolve()

JOB_STORAGE_DIR = Path(
    os.getenv('JOB_STORAGE_DIR', BASE_DIR / 'runtime_data' / 'jobs')
).resolve()

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
