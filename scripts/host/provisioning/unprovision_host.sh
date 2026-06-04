#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
RUN_USER="${VAGRANT_RUN_USER:-meteo-vm}"
SERVICE_NAME="${SERVICE_NAME:-meteo-vm.service}"
REMOVE_USER="${REMOVE_USER:-prompt}"
ASSUME_YES="${ASSUME_YES:-0}"
VAGRANT_USER_ENV_FILE="${PROJECT_ROOT}/.deployment/host-vagrant-user.env"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"

usage() {
  cat <<'USAGE'
Usage: sudo scripts/host/provisioning/unprovision_host.sh [options]

Remove host provisioning artifacts created for shared VirtualBox/Vagrant VM
management.

Options:
  --run-user USER          Technical Vagrant user. Default: meteo-vm
  --service-name NAME      systemd service name. Default: meteo-vm.service
  --remove-user           Also remove the technical user and its home directory.
  --keep-user             Keep the technical user. Default behavior unless prompted otherwise.
  -y, --yes               Do not ask confirmation for non-destructive cleanup.
                          Does not remove the technical user unless --remove-user is also set.
  -h, --help              Show this help message.

This script must be run with sudo.

What it removes by default:
  - the host-side VM autostart systemd service, if present;
  - .deployment/host-vagrant-user.env, if present.

What it does not fully revert:
  - group ownership and permissions previously applied to the project tree.
    Those changes are intentionally not reverted automatically.
USAGE
}

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

ok() {
  echo "[OK] $*"
}

warn() {
  echo "[WARNING] $*" >&2
}

ask_yes_no_default_no() {
  local prompt="$1"
  local answer=""

  if [[ ! -t 0 ]]; then
    return 1
  fi

  read -r -p "${prompt} [y/N]: " answer
  case "${answer}" in
    y|Y|yes|YES|Yes) return 0 ;;
    *) return 1 ;;
  esac
}

service_exists() {
  [[ -f "${SERVICE_PATH}" ]] || systemctl list-unit-files "${SERVICE_NAME}" --no-legend 2>/dev/null | grep -q "^${SERVICE_NAME}"
}

stop_disable_remove_service() {
  if ! service_exists; then
    ok "Host VM autostart service not found: ${SERVICE_NAME}"
    return 0
  fi

  ok "Stopping host VM autostart service if active: ${SERVICE_NAME}"
  systemctl stop "${SERVICE_NAME}" 2>/dev/null || true

  ok "Disabling host VM autostart service: ${SERVICE_NAME}"
  systemctl disable "${SERVICE_NAME}" 2>/dev/null || true

  if [[ -f "${SERVICE_PATH}" ]]; then
    ok "Removing systemd service file: ${SERVICE_PATH}"
    rm -f "${SERVICE_PATH}"
  fi

  systemctl daemon-reload
  systemctl reset-failed "${SERVICE_NAME}" 2>/dev/null || true
  ok "Host VM autostart service removed: ${SERVICE_NAME}"
}

remove_vagrant_user_env_file() {
  if [[ -f "${VAGRANT_USER_ENV_FILE}" ]]; then
    ok "Removing Vagrant run user configuration: ${VAGRANT_USER_ENV_FILE}"
    rm -f "${VAGRANT_USER_ENV_FILE}"
  else
    ok "Vagrant run user configuration not found: ${VAGRANT_USER_ENV_FILE}"
  fi
}

maybe_remove_run_user() {
  case "${REMOVE_USER}" in
    1|yes|YES|true|TRUE)
      ;;
    0|no|NO|false|FALSE)
      ok "Technical Vagrant user kept: ${RUN_USER}"
      return 0
      ;;
    prompt)
      if [[ "${ASSUME_YES}" == "1" ]]; then
        ok "Technical Vagrant user kept: ${RUN_USER}"
        return 0
      fi
      if ! id "${RUN_USER}" >/dev/null 2>&1; then
        ok "Technical Vagrant user does not exist: ${RUN_USER}"
        return 0
      fi
      cat <<EOF_WARN >&2
[WARNING] Removing ${RUN_USER} is destructive.
[WARNING] It can remove the user's home directory, including VirtualBox/Vagrant state owned by that user.
[WARNING] Only do this if you no longer need the VM owned by ${RUN_USER}.
EOF_WARN
      if ! ask_yes_no_default_no "Remove technical Vagrant user and its home directory (${RUN_USER})?"; then
        ok "Technical Vagrant user kept: ${RUN_USER}"
        return 0
      fi
      ;;
    *)
      fail "Invalid REMOVE_USER value: ${REMOVE_USER}"
      ;;
  esac

  if ! id "${RUN_USER}" >/dev/null 2>&1; then
    ok "Technical Vagrant user does not exist: ${RUN_USER}"
    return 0
  fi

  ok "Removing technical Vagrant user and home directory: ${RUN_USER}"
  userdel -r "${RUN_USER}" || fail "Failed to remove user ${RUN_USER}. Stop its processes or remove it manually."
  ok "Technical Vagrant user removed: ${RUN_USER}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-user)
      RUN_USER="$2"
      shift 2
      ;;
    --service-name)
      SERVICE_NAME="$2"
      SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"
      shift 2
      ;;
    --remove-user)
      REMOVE_USER=1
      shift
      ;;
    --keep-user)
      REMOVE_USER=0
      shift
      ;;
    -y|--yes)
      ASSUME_YES=1
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

[[ "${EUID}" -eq 0 ]] || fail "Host unprovisioning must be run as root. Use sudo."
[[ -f "${PROJECT_ROOT}/deploy.sh" ]] || fail "deploy.sh not found in project root: ${PROJECT_ROOT}"

stop_disable_remove_service
remove_vagrant_user_env_file
maybe_remove_run_user

warn "Project tree ownership, group permissions and setgid bits were not reverted."
warn "Review them manually if you need to restore the exact previous permission state."
ok "Host unprovisioning completed"
