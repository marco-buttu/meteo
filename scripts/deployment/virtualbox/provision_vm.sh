#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/meteo}"
GUEST_DATA_DIR="${GUEST_DATA_DIR:-/dati}"
RUN_USER="${METEO_RUN_USER:-vagrant}"
RUN_GROUP="${METEO_RUN_GROUP:-vagrant}"
VM_NETWORK_MODE="${VM_NETWORK_MODE:-nat}"

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

ok() {
  echo "[OK] $*"
}

[[ "${EUID}" -eq 0 ]] || fail "Provisioning must run as root."

ok "Preparing VM-specific application context"
GUEST_DATA_DIR="${GUEST_DATA_DIR}" \
METEO_RUN_USER="${RUN_USER}" \
METEO_RUN_GROUP="${RUN_GROUP}" \
bash /vagrant/scripts/deployment/virtualbox/prepare_app_in_guest.sh

cd "${APP_DIR}"

ok "Installing system dependencies with the native Linux deployment script"
bash "${APP_DIR}/scripts/deployment/local/install_system_deps_debian.sh"

ok "Preparing Python application with the native Linux deployment script"
sudo -u "${RUN_USER}" -H bash "${APP_DIR}/scripts/deployment/local/setup_app.sh"

if [[ "${VM_NETWORK_MODE}" == "static" ]]; then
  ok "Configuring static VM network"
  bash "${APP_DIR}/scripts/deployment/virtualbox/configure_static_network.sh"
fi

ok "Installing and starting systemd services with the native Linux deployment script"
bash "${APP_DIR}/scripts/deployment/local/install_systemd_services.sh" \
  --user "${RUN_USER}" \
  --group "${RUN_GROUP}" \
  --start

ok "VM provisioning completed"
