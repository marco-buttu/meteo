#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${PROJECT_ROOT}/.env}"
USE_VENV=1
SKIP_INSTALL=0
SKIP_ENV_CHECK=0
SKIP_EXTERNAL_PATHS=0

usage() {
  cat <<'USAGE'
Usage: scripts/setup_app.sh [options]

Prepare the application after system dependencies are already available.

Options:
  --no-venv              Install Python dependencies in the current Python environment.
  --skip-install         Do not install Python dependencies.
  --skip-env-check       Do not validate .env.
  --skip-external-paths  Validate .env but do not require external data/backend paths to exist.
                         Useful during image builds where volumes are not mounted yet.
  -h, --help             Show this help message.

This script does not install system packages, does not start Redis, does not
start the Flask app, and does not start the worker.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-venv)
      USE_VENV=0
      shift
      ;;
    --skip-install)
      SKIP_INSTALL=1
      shift
      ;;
    --skip-env-check)
      SKIP_ENV_CHECK=1
      shift
      ;;
    --skip-external-paths)
      SKIP_EXTERNAL_PATHS=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

ok() {
  echo "[OK] $*"
}

[[ -f "${PROJECT_ROOT}/requirements.txt" ]] || fail "requirements.txt not found in ${PROJECT_ROOT}"
[[ -f "${PROJECT_ROOT}/run.py" ]] || fail "run.py not found in ${PROJECT_ROOT}"
[[ -f "${PROJECT_ROOT}/worker.py" ]] || fail "worker.py not found in ${PROJECT_ROOT}"
[[ -d "${PROJECT_ROOT}/app" ]] || fail "app package not found in ${PROJECT_ROOT}"

cd "$PROJECT_ROOT"
ok "Project root: ${PROJECT_ROOT}"

PYTHON_BIN="python3"
PIP_BIN="python3 -m pip"

if [[ "$SKIP_INSTALL" -eq 0 ]]; then
  if [[ "$USE_VENV" -eq 1 && -z "${VIRTUAL_ENV:-}" ]]; then
    if [[ ! -d "${PROJECT_ROOT}/.venv" ]]; then
      ok "Creating virtual environment: ${PROJECT_ROOT}/.venv"
      python3 -m venv "${PROJECT_ROOT}/.venv"
    else
      ok "Virtual environment already exists: ${PROJECT_ROOT}/.venv"
    fi
    PYTHON_BIN="${PROJECT_ROOT}/.venv/bin/python"
    PIP_BIN="${PYTHON_BIN} -m pip"
  elif [[ -n "${VIRTUAL_ENV:-}" ]]; then
    PYTHON_BIN="python"
    PIP_BIN="python -m pip"
    ok "Using active virtual environment: ${VIRTUAL_ENV}"
  else
    ok "Using current Python environment"
  fi

  ok "Upgrading pip"
  $PIP_BIN install --upgrade pip

  ok "Installing Python dependencies from requirements.txt"
  $PIP_BIN install -r requirements.txt
else
  ok "Python dependency installation skipped"
fi

if [[ "$SKIP_ENV_CHECK" -eq 0 ]]; then
  CHECK_ARGS=()
  if [[ "$SKIP_EXTERNAL_PATHS" -eq 1 ]]; then
    CHECK_ARGS+=(--skip-external-paths)
  fi
  ENV_FILE="$ENV_FILE" bash "${PROJECT_ROOT}/scripts/check_env.sh" "${CHECK_ARGS[@]}"
else
  ok "Environment validation skipped"
fi

ok "Application setup completed"
