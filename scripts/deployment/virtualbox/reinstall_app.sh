#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
RUN_SMOKE_TESTS="${RUN_SMOKE_TESTS:-1}"
HOST_APP_PORT="${HOST_APP_PORT:-}"
VAGRANT_ENV_FILE="${PROJECT_ROOT}/.deployment/vagrant.env"

usage() {
  cat <<'USAGE'
Usage: scripts/deployment/virtualbox/reinstall_app.sh [options]

Reinstall the application inside an existing VirtualBox/Vagrant VM.
The VM is kept. Ubuntu, Redis, system packages, Vagrant mounts and port
forwarding are kept. The app installed under /opt/meteo is removed and
installed again from the current project checkout.

Options:
  -h, --help  Show this help message.

Environment variables:
  RUN_SMOKE_TESTS    Run host-side smoke tests after reinstall. Default: 1
                     Set to 0 to skip.
  HOST_APP_PORT      Host port used for smoke tests. Defaults to the value in
                     .deployment/vagrant.env, or 5000 if not configured.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
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

is_false() {
  case "${1,,}" in
    0|false|no|off) return 0 ;;
    *) return 1 ;;
  esac
}

load_saved_vagrant_env() {
  if [[ -f "${VAGRANT_ENV_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${VAGRANT_ENV_FILE}"
  fi
  HOST_APP_PORT="${HOST_APP_PORT:-5000}"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 was not found."
}

run_host_smoke_tests() {
  local python_bin=""
  local base_url="http://127.0.0.1:${HOST_APP_PORT}"

  if [[ -x "${PROJECT_ROOT}/.venv/bin/python" ]]; then
    python_bin="${PROJECT_ROOT}/.venv/bin/python"
  else
    require_command python3
    python_bin="$(command -v python3)"
  fi

  ok "Running host-side smoke tests against ${base_url}"
  BASE_URL="${base_url}" "${python_bin}" "${PROJECT_ROOT}/scripts/smoke_tests.py"
  ok "Host-side smoke tests completed"
}

[[ -f "${PROJECT_ROOT}/Vagrantfile" ]] || fail "Vagrantfile not found in project root: ${PROJECT_ROOT}"
require_command vagrant
load_saved_vagrant_env

cd "${PROJECT_ROOT}"

ok "Ensuring the VM is running without provisioning"
vagrant up --no-provision

ok "Copying and configuring the current project inside the VM"
vagrant ssh -c "sudo env GUEST_DATA_DIR='${GUEST_DATA_DIR:-/dati}' METEO_RUN_USER='vagrant' METEO_RUN_GROUP='vagrant' bash /vagrant/scripts/deployment/virtualbox/prepare_app_in_guest.sh"

ok "Reinstalling the application inside the VM with the native Linux reinstall script"
vagrant ssh -c "sudo bash /opt/meteo/scripts/deployment/local/reinstall_app.sh --yes --user vagrant --group vagrant"

ok "Application reinstall inside the existing VM completed"
ok "API should be reachable from the host at: http://127.0.0.1:${HOST_APP_PORT}"

if is_false "${RUN_SMOKE_TESTS}"; then
  ok "Host-side smoke tests skipped because RUN_SMOKE_TESTS=${RUN_SMOKE_TESTS}"
else
  run_host_smoke_tests
fi
