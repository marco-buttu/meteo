#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
VAGRANT_USER_HELPER="${PROJECT_ROOT}/scripts/host/vagrant/vagrant_user.sh"

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

# shellcheck disable=SC1090
source "${VAGRANT_USER_HELPER}"
load_vagrant_run_user
ensure_vagrant_run_user_exists

[[ -f "${PROJECT_ROOT}/Vagrantfile" ]] || fail "Vagrantfile not found in project root: ${PROJECT_ROOT}"

if ! command -v vagrant >/dev/null 2>&1; then
  fail "vagrant was not found in PATH"
fi

cd "${PROJECT_ROOT}"

# Environment variables that must be preserved when Vagrant is executed through
# the technical user. Values not set in the current shell are simply omitted.
ENV_NAMES=(
  HOST_DATA_DIR
  GUEST_DATA_DIR
  HOST_APP_IP
  HOST_APP_PORT
  VM_NETWORK_MODE
  VM_BRIDGE_INTERFACE
  VM_STATIC_IP
  VM_STATIC_NETMASK
  VM_STATIC_GATEWAY
  VM_STATIC_DNS
  VAGRANT_BOX
  VM_MEMORY
  VM_CPUS
  RUN_SMOKE_TESTS
  INSTALL_HOST_DEPS
  SMOKE_TEST_PYTHON
  HOST_SMOKE_VENV
)

env_args=()
for name in "${ENV_NAMES[@]}"; do
  if [[ -n "${!name+x}" ]]; then
    env_args+=("${name}=${!name}")
  fi
done

if ! vagrant_run_user_is_configured || [[ "$(current_username)" == "${VAGRANT_RUN_USER}" ]]; then
  exec vagrant "$@"
fi

if [[ "${EUID}" -eq 0 ]]; then
  exec runuser -u "${VAGRANT_RUN_USER}" -- env "${env_args[@]}" vagrant "$@"
fi

if ! command -v sudo >/dev/null 2>&1; then
  fail "sudo is required to run Vagrant as ${VAGRANT_RUN_USER}"
fi

exec sudo -H -u "${VAGRANT_RUN_USER}" env "${env_args[@]}" vagrant "$@"
