#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env"
SYSTEMD_DIR="/etc/systemd/system"
STATE_FILE="${PROJECT_ROOT}/.deployment/native-linux-state.env"
REMOVE_VENV=1
REMOVE_RUNTIME_DATA=0
REMOVE_SYSTEM_DEPS=0
PURGE_SYSTEM_DEPS=0
REMOVE_REDIS_DATA=0
YES=0
DRY_RUN=0

SYSTEM_PACKAGES=(
  python3
  python3-venv
  python3-pip
  redis-server
  octave
)

usage() {
  cat <<'USAGE'
Usage: scripts/deployment/local/uninstall_native_linux.sh [options]

Remove the native Linux deployment installed for the Meteo application.

By default, the script removes the Meteo systemd services and the local Python
virtual environment. Runtime data and system packages are not removed unless you
explicitly request it.

Options:
  --project-root PATH       Project root to clean.
  --env-file PATH           Environment file used to resolve runtime paths.
  --keep-venv               Do not remove PROJECT_ROOT/.venv.
  --remove-runtime-data     Remove JOB_STORAGE_DIR and PLOT_STORAGE_DIR from .env.
  --remove-system-deps      Remove only system packages that were not installed
                            before scripts/deployment/local/install_system_deps_debian.sh ran.
  --purge-system-deps       Purge those system packages instead of removing them.
                            Implies --remove-system-deps.
  --remove-redis-data       Also remove Redis data after package removal.
                            This is destructive and should only be used in a
                            disposable test machine or VM.
  --yes                     Required for destructive actions.
  --dry-run                 Print actions without changing the system.
  -h, --help                Show this help message.

Typical reset for a disposable test VM:

  sudo scripts/deployment/local/uninstall_native_linux.sh --yes --remove-runtime-data --remove-system-deps

If no state file is available, --remove-system-deps will not remove packages.
Use apt manually if you really want to purge system packages from such a host.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-root)
      PROJECT_ROOT="$(cd "$2" && pwd)"
      ENV_FILE="${PROJECT_ROOT}/.env"
      STATE_FILE="${PROJECT_ROOT}/.deployment/native-linux-state.env"
      shift 2
      ;;
    --env-file)
      ENV_FILE="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
      shift 2
      ;;
    --keep-venv)
      REMOVE_VENV=0
      shift
      ;;
    --remove-runtime-data)
      REMOVE_RUNTIME_DATA=1
      shift
      ;;
    --remove-system-deps)
      REMOVE_SYSTEM_DEPS=1
      shift
      ;;
    --purge-system-deps)
      REMOVE_SYSTEM_DEPS=1
      PURGE_SYSTEM_DEPS=1
      shift
      ;;
    --remove-redis-data)
      REMOVE_REDIS_DATA=1
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
  if [[ "${EUID}" -ne 0 ]]; then
    fail "This script must be run as root. Use sudo."
  fi
}

require_yes_for_destructive_actions() {
  if [[ "${YES}" -eq 0 && "${DRY_RUN}" -eq 0 ]]; then
    fail "Refusing to uninstall without --yes. Re-run with --dry-run to preview, or with --yes to apply."
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
  if [[ "${REMOVE_VENV}" -eq 1 ]]; then
    safe_rm_dir "Python virtual environment" "${PROJECT_ROOT}/.venv"
  else
    ok "Virtual environment removal skipped"
  fi
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

package_was_preexisting() {
  local package="$1"
  [[ -f "${STATE_FILE}" ]] || return 1
  grep -Eq "^PREEXISTING_PACKAGE_${package//-/_}=1$" "${STATE_FILE}"
}

remove_system_packages() {
  if [[ "${REMOVE_SYSTEM_DEPS}" -eq 0 ]]; then
    ok "System package removal skipped"
    return 0
  fi

  if [[ ! -f "${STATE_FILE}" ]]; then
    ok "State file not found; refusing to remove system packages: ${STATE_FILE}"
    return 0
  fi

  local packages_to_remove=()
  local package

  for package in "${SYSTEM_PACKAGES[@]}"; do
    if package_was_preexisting "$package"; then
      ok "Keeping pre-existing package: ${package}"
    else
      if dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q 'install ok installed'; then
        packages_to_remove+=("$package")
      else
        ok "Package is already absent: ${package}"
      fi
    fi
  done

  if [[ "${#packages_to_remove[@]}" -eq 0 ]]; then
    ok "No system packages to remove"
  else
    if [[ "${PURGE_SYSTEM_DEPS}" -eq 1 ]]; then
      ok "Purging system packages installed by the deployment script: ${packages_to_remove[*]}"
      run apt-get purge -y "${packages_to_remove[@]}"
    else
      ok "Removing system packages installed by the deployment script: ${packages_to_remove[*]}"
      run apt-get remove -y "${packages_to_remove[@]}"
    fi
    ok "Autoremoving unused dependencies"
    run apt-get autoremove -y
  fi

  if [[ "${REMOVE_REDIS_DATA}" -eq 1 ]]; then
    ok "Removing Redis data and configuration leftovers"
    run rm -rf /var/lib/redis /var/log/redis /etc/redis
  fi
}

remove_state_file() {
  if [[ -f "${STATE_FILE}" ]]; then
    ok "Removing deployment state file: ${STATE_FILE}"
    run rm -f "${STATE_FILE}"
  else
    ok "Deployment state file not found: ${STATE_FILE}"
  fi
}

require_root
require_yes_for_destructive_actions
[[ -d "${PROJECT_ROOT}" ]] || fail "Project root does not exist: ${PROJECT_ROOT}"

load_env_if_available
stop_and_remove_services
remove_venv
remove_runtime_data
remove_system_packages
remove_state_file

ok "Native Linux deployment uninstall completed"
