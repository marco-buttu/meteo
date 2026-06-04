#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env"
RUN_USER="${SUDO_USER:-${USER}}"
RUN_GROUP=""
START_SERVICES=1
REMOVE_RUNTIME_DATA=0
YES=0
DRY_RUN=0
SYSTEMD_DIR="/etc/systemd/system"

usage() {
  cat <<'USAGE'
Usage: scripts/app/deployment/reinstall_app.sh [options]

Reinstall the Meteo application on the current Linux machine without removing
system packages or Redis data. This script is intended to be reusable both on a
native host and inside the VirtualBox VM.

The script stops and removes the Meteo systemd units, removes the Python virtual
environment, optionally removes runtime data, runs the application setup again,
reinstalls the systemd units, and starts them by default.

Options:
  --project-root PATH       Project root to reinstall. Default: current repo root.
  --env-file PATH           Environment file used by setup and systemd.
  --user USER               Linux user that will own and run the app services.
  --group GROUP             Linux group that will run the app services.
  --remove-runtime-data     Remove JOB_STORAGE_DIR and PLOT_STORAGE_DIR from .env.
  --no-start                Reinstall services but do not start them.
  --yes                     Required unless --dry-run is used.
  --dry-run                 Print destructive actions without changing files.
  -h, --help                Show this help message.

Examples:
  sudo scripts/app/deployment/reinstall_app.sh --yes
  sudo scripts/app/deployment/reinstall_app.sh --yes --user vagrant --group vagrant
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
      shift 2
      ;;
    --group)
      RUN_GROUP="$2"
      shift 2
      ;;
    --remove-runtime-data)
      REMOVE_RUNTIME_DATA=1
      shift
      ;;
    --no-start)
      START_SERVICES=0
      shift
      ;;
    --yes)
      YES=1
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

run() {
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    printf '[DRY-RUN]'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

require_root() {
  [[ "${EUID}" -eq 0 ]] || fail "This script must be run as root. Use sudo."
}

require_yes() {
  if [[ "${YES}" -eq 0 && "${DRY_RUN}" -eq 0 ]]; then
    fail "Refusing to reinstall without --yes. Re-run with --dry-run to preview, or with --yes to apply."
  fi
}

resolve_path() {
  local raw_path="$1"
  local path
  local dir
  local base

  if [[ "$raw_path" == /* ]]; then
    path="$raw_path"
  elif [[ "$raw_path" == ~* ]]; then
    path="${raw_path/#\~/$HOME}"
  else
    path="${PROJECT_ROOT}/${raw_path}"
  fi

  dir="$(dirname "$path")"
  base="$(basename "$path")"

  if [[ -d "$dir" ]]; then
    printf '%s/%s\n' "$(cd "$dir" && pwd -P)" "$base"
  else
    printf '%s\n' "$path"
  fi
}

safe_rm_dir() {
  local label="$1"
  local target="$2"
  local resolved
  resolved="$(resolve_path "$target")"

  if [[ ! -e "$resolved" ]]; then
    ok "${label} does not exist: ${resolved}"
    return 0
  fi

  [[ -d "$resolved" ]] || fail "${label} is not a directory, refusing to remove: ${resolved}"

  case "$resolved" in
    /|/bin|/boot|/dev|/etc|/home|/lib|/lib64|/media|/mnt|/opt|/proc|/root|/run|/sbin|/srv|/sys|/tmp|/usr|/var)
      fail "Refusing to remove unsafe directory for ${label}: ${resolved}"
      ;;
  esac

  if [[ "$resolved" == "$PROJECT_ROOT" ]]; then
    fail "Refusing to remove project root for ${label}: ${resolved}"
  fi

  ok "Removing ${label}: ${resolved}"
  run rm -rf -- "$resolved"
}

load_env_if_available() {
  if [[ -f "${ENV_FILE}" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "${ENV_FILE}"
    set +a
    ok "Loaded environment file: ${ENV_FILE}"
  else
    ok "Environment file not found, runtime paths will be skipped: ${ENV_FILE}"
  fi
}

resolve_run_identity() {
  if [[ "${RUN_USER}" == "root" && -d "${PROJECT_ROOT}" ]]; then
    local owner
    owner="$(stat -c '%U' "${PROJECT_ROOT}" 2>/dev/null || true)"
    if [[ -n "${owner}" && "${owner}" != "UNKNOWN" ]]; then
      RUN_USER="${owner}"
    fi
  fi

  id "${RUN_USER}" >/dev/null 2>&1 || fail "Runtime user does not exist: ${RUN_USER}"

  if [[ -z "${RUN_GROUP}" ]]; then
    RUN_GROUP="$(id -gn "${RUN_USER}" 2>/dev/null || true)"
  fi
  [[ -n "${RUN_GROUP}" ]] || fail "Could not determine runtime group for user: ${RUN_USER}"
  getent group "${RUN_GROUP}" >/dev/null 2>&1 || fail "Runtime group does not exist: ${RUN_GROUP}"
}

stop_and_remove_services() {
  ok "Stopping Meteo systemd services if present"
  run systemctl stop meteo-app.service meteo-worker.service || true

  ok "Disabling Meteo systemd services if present"
  run systemctl disable meteo-app.service meteo-worker.service || true

  ok "Removing Meteo systemd unit files"
  run rm -f "${SYSTEMD_DIR}/meteo-app.service" "${SYSTEMD_DIR}/meteo-worker.service"

  ok "Reloading systemd"
  run systemctl daemon-reload
  run systemctl reset-failed meteo-app.service meteo-worker.service || true
}

remove_venv() {
  safe_rm_dir "Python virtual environment" "${PROJECT_ROOT}/.venv"
}

remove_runtime_data() {
  if [[ "${REMOVE_RUNTIME_DATA}" -eq 0 ]]; then
    ok "Runtime data removal skipped"
    return 0
  fi

  if [[ -n "${JOB_STORAGE_DIR:-}" ]]; then
    safe_rm_dir "JOB_STORAGE_DIR" "${JOB_STORAGE_DIR}"
  else
    ok "JOB_STORAGE_DIR is not set; skipping"
  fi

  if [[ -n "${PLOT_STORAGE_DIR:-}" ]]; then
    safe_rm_dir "PLOT_STORAGE_DIR" "${PLOT_STORAGE_DIR}"
  else
    ok "PLOT_STORAGE_DIR is not set; skipping"
  fi
}

run_setup() {
  ok "Preparing Python application as ${RUN_USER}"
  run sudo -u "${RUN_USER}" -H env ENV_FILE="${ENV_FILE}" bash "${PROJECT_ROOT}/scripts/app/deployment/setup_app.sh"
}

install_services() {
  local args=(
    --project-root "${PROJECT_ROOT}"
    --env-file "${ENV_FILE}"
    --user "${RUN_USER}"
    --group "${RUN_GROUP}"
  )

  if [[ "${START_SERVICES}" -eq 1 ]]; then
    args+=(--start)
  fi

  ok "Installing systemd services"
  run bash "${PROJECT_ROOT}/scripts/app/deployment/install_systemd_services.sh" "${args[@]}"
}

require_root
require_yes
[[ -d "${PROJECT_ROOT}" ]] || fail "Project root does not exist: ${PROJECT_ROOT}"
[[ -f "${PROJECT_ROOT}/scripts/app/deployment/setup_app.sh" ]] || fail "setup_app.sh not found under project root"
[[ -f "${PROJECT_ROOT}/scripts/app/deployment/install_systemd_services.sh" ]] || fail "install_systemd_services.sh not found under project root"
resolve_run_identity
load_env_if_available

ok "Reinstalling Meteo application in ${PROJECT_ROOT}"
ok "Runtime user: ${RUN_USER}:${RUN_GROUP}"
stop_and_remove_services
remove_venv
remove_runtime_data
run_setup
install_services

ok "Application reinstall completed"
if [[ "${START_SERVICES}" -eq 1 ]]; then
  ok "Services were restarted"
else
  ok "Services installed but not started. Start them with: sudo systemctl start meteo-app meteo-worker"
fi
