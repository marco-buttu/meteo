#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
RUN_USER="${VAGRANT_RUN_USER:-meteo-vm}"
SHARED_GROUP="${SHARED_GROUP:-sviluppo}"
SHARED_DIR="${SHARED_DIR:-}"
DATA_DIR="${HOST_DATA_DIR:-}"
INSTALL_AUTOSTART="${INSTALL_AUTOSTART:-prompt}"
ASSUME_YES="${ASSUME_YES:-0}"
SERVICE_NAME="${SERVICE_NAME:-meteo-vm.service}"
VAGRANT_ENV_FILE="${PROJECT_ROOT}/.deployment/vagrant.env"

usage() {
  cat <<'USAGE'
Usage: sudo scripts/host/provisioning/provision_host.sh [options]

Prepare the physical host for shared VirtualBox/Vagrant VM management.

Options:
  --run-user USER          Technical user that will own/manage the VM. Default: meteo-vm
  --shared-group GROUP     Shared Linux group allowed to work on the project. Default: sviluppo
  --shared-dir PATH        Shared directory containing the project tree. Asked interactively if unset. Default prompt: /wff
  --data-dir PATH          Host data directory to validate for the technical user. Optional.
  --install-autostart      Install and enable the host systemd autostart service.
  --no-autostart           Do not install the host systemd autostart service.
  --service-name NAME      systemd service name. Default: meteo-vm.service
  -y, --yes                Use defaults and do not ask confirmation where possible.
  -h, --help               Show this help message.

This script must be run with sudo. Normal deployment should still be run without sudo:
  ./admin.sh virtualbox
USAGE
}

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

ok() {
  echo "[OK] $*"
}

read_saved_data_dir() {
  [[ -f "${VAGRANT_ENV_FILE}" ]] || return 1
  awk -F= '$1 == "HOST_DATA_DIR" {print substr($0, index($0,$2)); exit}' "${VAGRANT_ENV_FILE}"
}

ask_if_needed() {
  local prompt="$1"
  local default_value="$2"
  local var_name="$3"
  local value=""

  if [[ -n "${!var_name:-}" ]]; then
    return 0
  fi

  if [[ "${ASSUME_YES}" == "1" || ! -t 0 ]]; then
    printf -v "${var_name}" '%s' "${default_value}"
    return 0
  fi

  read -r -p "${prompt} [${default_value}]: " value
  printf -v "${var_name}" '%s' "${value:-${default_value}}"
}

ask_autostart_if_needed() {
  local answer=""

  case "${INSTALL_AUTOSTART}" in
    1|yes|YES|true|TRUE) INSTALL_AUTOSTART=1; return 0 ;;
    0|no|NO|false|FALSE) INSTALL_AUTOSTART=0; return 0 ;;
    prompt) ;;
    *) fail "Invalid INSTALL_AUTOSTART value: ${INSTALL_AUTOSTART}" ;;
  esac

  if [[ "${ASSUME_YES}" == "1" || ! -t 0 ]]; then
    INSTALL_AUTOSTART=1
    return 0
  fi

  read -r -p "Install and enable VM autostart at host boot? [Y/n]: " answer
  case "${answer}" in
    ""|y|Y|yes|YES|Yes) INSTALL_AUTOSTART=1 ;;
    *) INSTALL_AUTOSTART=0 ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-user)
      RUN_USER="$2"
      shift 2
      ;;
    --shared-group)
      SHARED_GROUP="$2"
      shift 2
      ;;
    --shared-dir)
      SHARED_DIR="$2"
      shift 2
      ;;
    --data-dir)
      DATA_DIR="$2"
      shift 2
      ;;
    --install-autostart)
      INSTALL_AUTOSTART=1
      shift
      ;;
    --no-autostart)
      INSTALL_AUTOSTART=0
      shift
      ;;
    --service-name)
      SERVICE_NAME="$2"
      shift 2
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

[[ "${EUID}" -eq 0 ]] || fail "Host provisioning must be run as root. Use sudo."

if [[ -z "${DATA_DIR}" ]]; then
  DATA_DIR="$(read_saved_data_dir || true)"
fi

ask_if_needed "Shared directory containing the project tree" "/wff" SHARED_DIR
ask_autostart_if_needed

bash "${PROJECT_ROOT}/scripts/host/provisioning/check_host_state.sh"
bash "${PROJECT_ROOT}/scripts/host/provisioning/create_vagrant_user.sh" "${RUN_USER}" "${SHARED_GROUP}"
ASSUME_YES="${ASSUME_YES}" bash "${PROJECT_ROOT}/scripts/host/provisioning/configure_vagrant_permissions.sh" \
  "${RUN_USER}" "${SHARED_GROUP}" "${SHARED_DIR}" "${DATA_DIR}"

if [[ "${INSTALL_AUTOSTART}" == "1" ]]; then
  bash "${PROJECT_ROOT}/scripts/host/provisioning/install_vm_autostart_service.sh" "${RUN_USER}" "${SERVICE_NAME}"
else
  ok "Host VM autostart service installation skipped"
fi

ok "Host provisioning completed"
ok "Technical Vagrant user: ${RUN_USER}"
ok "Shared directory: ${SHARED_DIR}"
