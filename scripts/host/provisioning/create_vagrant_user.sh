#!/usr/bin/env bash
set -euo pipefail

RUN_USER="${1:?run user is required}"
SHARED_GROUP="${2:?shared group is required}"

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

ok() {
  echo "[OK] $*"
}

[[ "${EUID}" -eq 0 ]] || fail "This script must be run as root. Use sudo."

if ! getent group vboxusers >/dev/null 2>&1; then
  fail "Required group does not exist: vboxusers. Install/configure VirtualBox first."
fi

if ! getent group "${SHARED_GROUP}" >/dev/null 2>&1; then
  fail "Shared group does not exist: ${SHARED_GROUP}"
fi

if id "${RUN_USER}" >/dev/null 2>&1; then
  ok "Technical Vagrant user already exists: ${RUN_USER}"
else
  ok "Creating technical Vagrant user: ${RUN_USER}"
  useradd --create-home --shell /bin/bash --groups "vboxusers,${SHARED_GROUP}" "${RUN_USER}"
fi

ok "Ensuring ${RUN_USER} belongs to vboxusers and ${SHARED_GROUP}"
usermod -aG vboxusers "${RUN_USER}"
usermod -aG "${SHARED_GROUP}" "${RUN_USER}"
