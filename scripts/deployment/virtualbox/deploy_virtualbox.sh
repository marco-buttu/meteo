#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
HOST_DATA_DIR="${HOST_DATA_DIR:-}"
GUEST_DATA_DIR="${GUEST_DATA_DIR:-/dati}"
HOST_APP_PORT="${HOST_APP_PORT:-5000}"
RUN_SMOKE_TESTS="${RUN_SMOKE_TESTS:-1}"
HOST_SMOKE_VENV="${HOST_SMOKE_VENV:-${PROJECT_ROOT}/.deployment/host-smoke-venv}"
SMOKE_TEST_PYTHON="${SMOKE_TEST_PYTHON:-}"
VAGRANT_ENV_FILE="${PROJECT_ROOT}/.deployment/vagrant.env"

usage() {
  cat <<'USAGE'
Usage: scripts/deployment/virtualbox/deploy_virtualbox.sh [options]

Create and provision a VirtualBox VM through Vagrant.

Options:
  -h, --help  Show this help message.

Environment variables:
  HOST_DATA_DIR      Required unless provided interactively. Data directory on host.
  GUEST_DATA_DIR     Directory where host data are mounted in the VM. Default: /dati
  HOST_APP_PORT      Host port forwarded to guest port 5000. Default: 5000
  VAGRANT_BOX        Ubuntu Vagrant box. Default: ubuntu/jammy64
  VM_MEMORY          VM memory in MB. Default: 4096
  VM_CPUS            VM CPU count. Default: 2
  RUN_SMOKE_TESTS    Run host-side smoke tests after deployment. Default: 1
                     Set to 0 to skip.
  SMOKE_TEST_PYTHON  Optional Python interpreter for smoke tests.
  HOST_SMOKE_VENV    Host virtualenv created when requests is not available.
                     Default: .deployment/host-smoke-venv

Examples:
  HOST_DATA_DIR=/home/marco/wrf/data ./deploy.sh virtualbox
  HOST_DATA_DIR=/home/marco/wrf/data HOST_APP_PORT=5001 ./deploy.sh virtualbox
  HOST_DATA_DIR=/home/marco/wrf/data RUN_SMOKE_TESTS=0 ./deploy.sh virtualbox

The selected host data directory is saved in .deployment/vagrant.env so that
later commands such as `vagrant up` can reuse it automatically.
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

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 was not found. Install it before running the VirtualBox deployment."
}

load_saved_vagrant_env() {
  if [[ -f "${VAGRANT_ENV_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${VAGRANT_ENV_FILE}"
  fi
}

abs_path() {
  local path="$1"
  if [[ "$path" == ~* ]]; then
    path="${path/#\~/$HOME}"
  fi
  if [[ "$path" == /* ]]; then
    printf '%s\n' "$path"
  else
    printf '%s\n' "$(cd "$(dirname "$path")" && pwd -P)/$(basename "$path")"
  fi
}

is_false() {
  case "${1,,}" in
    0|false|no|off) return 0 ;;
    *) return 1 ;;
  esac
}

python_can_import_requests() {
  local python_bin="$1"
  "${python_bin}" - <<'PY' >/dev/null 2>&1
import requests
PY
}

select_smoke_test_python() {
  if [[ -n "${SMOKE_TEST_PYTHON}" ]]; then
    [[ -x "${SMOKE_TEST_PYTHON}" ]] || fail "SMOKE_TEST_PYTHON is not executable: ${SMOKE_TEST_PYTHON}"
    python_can_import_requests "${SMOKE_TEST_PYTHON}" || fail "SMOKE_TEST_PYTHON cannot import requests: ${SMOKE_TEST_PYTHON}"
    printf '%s\n' "${SMOKE_TEST_PYTHON}"
    return 0
  fi

  if [[ -x "${PROJECT_ROOT}/.venv/bin/python" ]] && python_can_import_requests "${PROJECT_ROOT}/.venv/bin/python"; then
    printf '%s\n' "${PROJECT_ROOT}/.venv/bin/python"
    return 0
  fi

  require_command python3
  if python_can_import_requests python3; then
    command -v python3
    return 0
  fi

  ok "Creating host virtual environment for smoke tests: ${HOST_SMOKE_VENV}"
  python3 -m venv "${HOST_SMOKE_VENV}" || fail "Failed to create host smoke test virtual environment. Is python3-venv installed?"
  "${HOST_SMOKE_VENV}/bin/python" -m pip install --upgrade pip
  "${HOST_SMOKE_VENV}/bin/python" -m pip install -r "${PROJECT_ROOT}/requirements.txt"

  python_can_import_requests "${HOST_SMOKE_VENV}/bin/python" || fail "Smoke test virtual environment cannot import requests."
  printf '%s\n' "${HOST_SMOKE_VENV}/bin/python"
}


save_vagrant_env() {
  mkdir -p "${PROJECT_ROOT}/.deployment"
  cat > "${VAGRANT_ENV_FILE}" <<EOF
HOST_DATA_DIR=${HOST_DATA_DIR}
GUEST_DATA_DIR=${GUEST_DATA_DIR}
HOST_APP_PORT=${HOST_APP_PORT}
EOF
  ok "Saved Vagrant host configuration: ${VAGRANT_ENV_FILE}"
}

run_host_smoke_tests() {
  local python_bin
  local base_url

  [[ -f "${PROJECT_ROOT}/scripts/smoke_tests.py" ]] || fail "Smoke test script not found: ${PROJECT_ROOT}/scripts/smoke_tests.py"

  python_bin="$(select_smoke_test_python)"
  base_url="http://127.0.0.1:${HOST_APP_PORT}"

  ok "Running host-side smoke tests against ${base_url}"
  BASE_URL="${base_url}" "${python_bin}" "${PROJECT_ROOT}/scripts/smoke_tests.py"
  ok "Host-side smoke tests completed"
}

require_command vagrant
require_command VBoxManage

if [[ -z "${HOST_DATA_DIR}" ]]; then
  load_saved_vagrant_env
fi

if [[ -z "${HOST_DATA_DIR}" ]]; then
  if [[ -t 0 ]]; then
    read -r -p "Host data directory to mount in the VM: " HOST_DATA_DIR
  else
    fail "HOST_DATA_DIR is required in non-interactive mode."
  fi
fi

[[ -n "${HOST_DATA_DIR}" ]] || fail "Host data directory cannot be empty."
HOST_DATA_DIR="$(abs_path "${HOST_DATA_DIR}")"
[[ -d "${HOST_DATA_DIR}" ]] || fail "Host data directory does not exist: ${HOST_DATA_DIR}"

export HOST_DATA_DIR
export GUEST_DATA_DIR
export HOST_APP_PORT

save_vagrant_env

cd "${PROJECT_ROOT}"
ok "Project root: ${PROJECT_ROOT}"
ok "Host data directory: ${HOST_DATA_DIR}"
ok "Guest data directory: ${GUEST_DATA_DIR}"
ok "Host app port: ${HOST_APP_PORT}"

vagrant up

ok "VirtualBox deployment completed"
ok "API should be reachable from the host at: http://127.0.0.1:${HOST_APP_PORT}"

if is_false "${RUN_SMOKE_TESTS}"; then
  ok "Host-side smoke tests skipped because RUN_SMOKE_TESTS=${RUN_SMOKE_TESTS}"
else
  run_host_smoke_tests
fi
