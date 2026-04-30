#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env"
RUN_USER="${SUDO_USER:-${USER}}"
RUN_GROUP="$(id -gn "${RUN_USER}" 2>/dev/null || true)"
ENABLE_SERVICES=1
START_SERVICES=0
DRY_RUN=0
SYSTEMD_DIR="/etc/systemd/system"

usage() {
  cat <<'USAGE'
Usage: scripts/deployment/local/install_systemd_services.sh [options]

Install the native Linux systemd services for the Meteo application.

Options:
  --project-root PATH  Project root to use in the services.
  --env-file PATH      Environment file to load from systemd.
  --user USER          Linux user that will run the services.
  --group GROUP        Linux group that will run the services.
  --no-enable          Install services without enabling them at boot.
  --start              Start or restart services after installation.
  --dry-run            Print generated units without installing them.
  -h, --help           Show this help message.

The script expects scripts/deployment/local/setup_app.sh to have already created the virtual
environment and installed the Python dependencies.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-root)
      PROJECT_ROOT="$(cd "$2" && pwd)"
      ENV_FILE="${PROJECT_ROOT}/.env"
      shift 2
      ;;
    --env-file)
      ENV_FILE="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
      shift 2
      ;;
    --user)
      RUN_USER="$2"
      if [[ -z "${RUN_GROUP}" || "${RUN_GROUP}" == "root" ]]; then
        RUN_GROUP="$(id -gn "${RUN_USER}" 2>/dev/null || true)"
      fi
      shift 2
      ;;
    --group)
      RUN_GROUP="$2"
      shift 2
      ;;
    --no-enable)
      ENABLE_SERVICES=0
      shift
      ;;
    --start)
      START_SERVICES=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
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

render_unit() {
  local template="$1"
  sed \
    -e "s#__PROJECT_ROOT__#${PROJECT_ROOT}#g" \
    -e "s#__ENV_FILE__#${ENV_FILE}#g" \
    -e "s#__PYTHON_BIN__#${PROJECT_ROOT}/.venv/bin/python#g" \
    -e "s#__RUN_USER__#${RUN_USER}#g" \
    -e "s#__RUN_GROUP__#${RUN_GROUP}#g" \
    "${template}"
}

validate() {
  [[ -d "${PROJECT_ROOT}" ]] || fail "Project root does not exist: ${PROJECT_ROOT}"
  [[ -f "${PROJECT_ROOT}/run.py" ]] || fail "run.py not found in project root: ${PROJECT_ROOT}"
  [[ -f "${PROJECT_ROOT}/worker.py" ]] || fail "worker.py not found in project root: ${PROJECT_ROOT}"
  [[ -f "${ENV_FILE}" ]] || fail "Environment file not found: ${ENV_FILE}"
  [[ -x "${PROJECT_ROOT}/.venv/bin/python" ]] || fail "Virtualenv Python not found: ${PROJECT_ROOT}/.venv/bin/python. Run scripts/deployment/local/setup_app.sh first."
  [[ -f "${PROJECT_ROOT}/systemd/meteo-app.service" ]] || fail "Missing systemd template: systemd/meteo-app.service"
  [[ -f "${PROJECT_ROOT}/systemd/meteo-worker.service" ]] || fail "Missing systemd template: systemd/meteo-worker.service"
  id "${RUN_USER}" >/dev/null 2>&1 || fail "User does not exist: ${RUN_USER}"
  getent group "${RUN_GROUP}" >/dev/null 2>&1 || fail "Group does not exist: ${RUN_GROUP}"
}

validate

if [[ "${DRY_RUN}" -eq 1 ]]; then
  ok "Dry run: meteo-app.service"
  render_unit "${PROJECT_ROOT}/systemd/meteo-app.service"
  echo
  ok "Dry run: meteo-worker.service"
  render_unit "${PROJECT_ROOT}/systemd/meteo-worker.service"
  exit 0
fi

if [[ "${EUID}" -ne 0 ]]; then
  fail "This script must be run as root. Use sudo."
fi

ok "Installing meteo-app.service"
render_unit "${PROJECT_ROOT}/systemd/meteo-app.service" > "${SYSTEMD_DIR}/meteo-app.service"

ok "Installing meteo-worker.service"
render_unit "${PROJECT_ROOT}/systemd/meteo-worker.service" > "${SYSTEMD_DIR}/meteo-worker.service"

ok "Reloading systemd"
systemctl daemon-reload

if [[ "${ENABLE_SERVICES}" -eq 1 ]]; then
  ok "Enabling services at boot"
  systemctl enable meteo-app.service meteo-worker.service
else
  ok "Service enable skipped"
fi

if [[ "${START_SERVICES}" -eq 1 ]]; then
  ok "Starting or restarting services"
  systemctl restart meteo-app.service meteo-worker.service
else
  ok "Service start skipped. Start them with: sudo systemctl start meteo-app meteo-worker"
fi

ok "systemd service installation completed"
