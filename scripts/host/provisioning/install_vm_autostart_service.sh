#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
RUN_USER="${1:?run user is required}"
SERVICE_NAME="${2:-meteo-vm.service}"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"
VAGRANT_BIN="${VAGRANT_BIN:-$(command -v vagrant || true)}"

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

ok() {
  echo "[OK] $*"
}

[[ "${EUID}" -eq 0 ]] || fail "This script must be run as root. Use sudo."
[[ -n "${VAGRANT_BIN}" ]] || fail "vagrant was not found in PATH"
[[ -x "${VAGRANT_BIN}" ]] || fail "vagrant is not executable: ${VAGRANT_BIN}"
id "${RUN_USER}" >/dev/null 2>&1 || fail "Run user does not exist: ${RUN_USER}"
[[ -f "${PROJECT_ROOT}/Vagrantfile" ]] || fail "Vagrantfile not found in project root: ${PROJECT_ROOT}"

cat > "${SERVICE_PATH}" <<EOF_SERVICE
[Unit]
Description=Meteo VirtualBox VM managed by Vagrant
After=network-online.target vboxdrv.service
Wants=network-online.target

[Service]
Type=oneshot
User=${RUN_USER}
WorkingDirectory=${PROJECT_ROOT}
ExecStart=${VAGRANT_BIN} up --no-provision
ExecStop=${VAGRANT_BIN} halt
RemainAfterExit=yes
TimeoutStartSec=600
TimeoutStopSec=180

[Install]
WantedBy=multi-user.target
EOF_SERVICE

systemctl daemon-reload
systemctl enable "${SERVICE_NAME}"
ok "Installed and enabled host VM autostart service: ${SERVICE_NAME}"
ok "Service file: ${SERVICE_PATH}"
