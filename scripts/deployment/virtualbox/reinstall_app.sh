#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
RUN_SMOKE_TESTS="${RUN_SMOKE_TESTS:-1}"
HOST_APP_PORT="${HOST_APP_PORT:-}"
HOST_SMOKE_VENV="${HOST_SMOKE_VENV:-${PROJECT_ROOT}/.deployment/host-smoke-venv}"
SMOKE_TEST_PYTHON="${SMOKE_TEST_PYTHON:-}"
VAGRANT_ENV_FILE="${PROJECT_ROOT}/.deployment/vagrant.env"
SMOKE_PYTHON_HELPER="${PROJECT_ROOT}/scripts/deployment/host/smoke_test_python.sh"

# shellcheck disable=SC1090
source "${SMOKE_PYTHON_HELPER}"

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
  SMOKE_TEST_PYTHON  Optional Python interpreter for smoke tests.
  HOST_SMOKE_VENV    Host virtualenv created when the system Python cannot
                     import requests and the user agrees to create it.
                     Default: .deployment/host-smoke-venv
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

warn() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR:-}" ]]; then
    printf '\033[33m[WARNING] %s\033[0m\n' "$*" >&2
  else
    printf '[WARNING] %s\n' "$*" >&2
  fi
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

  [[ -f "${PROJECT_ROOT}/scripts/smoke_tests.py" ]] || fail "Smoke test script not found: ${PROJECT_ROOT}/scripts/smoke_tests.py"

  if ! python_bin="$(select_or_prepare_smoke_test_python "${PROJECT_ROOT}")"; then
    warn "Host-side smoke tests skipped."
    return 0
  fi

  ok "Running host-side smoke tests with: ${python_bin}"
  ok "Smoke test base URL: ${base_url}"
  BASE_URL="${base_url}" "${python_bin}" "${PROJECT_ROOT}/scripts/smoke_tests.py"
  ok "Host-side smoke tests completed"
}

[[ -f "${PROJECT_ROOT}/Vagrantfile" ]] || fail "Vagrantfile not found in project root: ${PROJECT_ROOT}"
[[ -f "${SMOKE_PYTHON_HELPER}" ]] || fail "Smoke-test Python helper not found: ${SMOKE_PYTHON_HELPER}"
require_command vagrant
load_saved_vagrant_env

cd "${PROJECT_ROOT}"

ok "Ensuring the VM is running without provisioning"
vagrant up --no-provision

ok "Removing the existing application installation inside the VM"
vagrant ssh -c 'set -euo pipefail
sudo systemctl stop meteo-app meteo-worker 2>/dev/null || true
sudo systemctl disable meteo-app meteo-worker 2>/dev/null || true
sudo rm -f /etc/systemd/system/meteo-app.service /etc/systemd/system/meteo-worker.service
sudo systemctl daemon-reload
sudo rm -rf /opt/meteo
'

ok "Reprovisioning the application inside the existing VM"
vagrant provision

ok "Application reinstall inside the existing VM completed"
ok "API should be reachable from the host at: http://127.0.0.1:${HOST_APP_PORT}"

if is_false "${RUN_SMOKE_TESTS}"; then
  ok "Host-side smoke tests skipped because RUN_SMOKE_TESTS=${RUN_SMOKE_TESTS}"
else
  run_host_smoke_tests
fi
