#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
HOST_DATA_DIR="${HOST_DATA_DIR:-}"
GUEST_DATA_DIR="${GUEST_DATA_DIR:-/dati}"
HOST_APP_IP="${HOST_APP_IP:-}"
HOST_APP_PORT="${HOST_APP_PORT:-5000}"
VM_NETWORK_MODE="${VM_NETWORK_MODE:-}"
VM_BRIDGE_INTERFACE="${VM_BRIDGE_INTERFACE:-}"
VM_STATIC_IP="${VM_STATIC_IP:-}"
VM_STATIC_NETMASK="${VM_STATIC_NETMASK:-}"
VM_STATIC_GATEWAY="${VM_STATIC_GATEWAY:-}"
VM_STATIC_DNS="${VM_STATIC_DNS:-}"
RUN_SMOKE_TESTS="${RUN_SMOKE_TESTS:-1}"
HOST_SMOKE_VENV="${HOST_SMOKE_VENV:-${PROJECT_ROOT}/.deployment/host-smoke-venv}"
SMOKE_TEST_PYTHON="${SMOKE_TEST_PYTHON:-}"
VAGRANT_ENV_FILE="${PROJECT_ROOT}/.deployment/vagrant.env"
SMOKE_PYTHON_HELPER="${PROJECT_ROOT}/scripts/host/vagrant/smoke_test_python.sh"
VAGRANT_RUNNER="${PROJECT_ROOT}/scripts/host/vagrant/run_vagrant_command.sh"

# shellcheck disable=SC1090
source "${SMOKE_PYTHON_HELPER}"

usage() {
  cat <<'USAGE'
Usage: scripts/host/vagrant/deploy_virtualbox.sh [options]

Create and provision a VirtualBox VM through Vagrant.

Options:
  -h, --help  Show this help message.

Environment variables:
  HOST_DATA_DIR      Required unless provided interactively or saved in
                     .deployment/vagrant.env. Data directory on host.
  GUEST_DATA_DIR     Directory where host data are mounted in the VM. Default: /dati
  HOST_APP_PORT      Host port forwarded to guest port 5000. Default: 5000
  HOST_APP_IP        Host IP where the forwarded app port is exposed in NAT mode.
                     Default: 127.0.0.1. Use 0.0.0.0 to listen on all host IPs.
  VM_NETWORK_MODE    VM network mode: nat or static. Default: nat
  VM_BRIDGE_INTERFACE
                     Optional host network interface used by Vagrant public_network.
  VM_STATIC_IP       Static VM IP used when VM_NETWORK_MODE=static.
                     Default: 192.168.140.45
  VM_STATIC_NETMASK  Static VM netmask. Default: 255.255.255.0
  VM_STATIC_GATEWAY  Static VM gateway. Default: 192.168.140.1
  VM_STATIC_DNS      Static VM DNS server. Default: 192.168.110.11
  VAGRANT_BOX        Ubuntu Vagrant box. Default: ubuntu/jammy64
  VM_MEMORY          VM memory in MB. Default: 4096
  VM_CPUS            VM CPU count. Default: 2
  RUN_SMOKE_TESTS    Run host-side smoke tests after deployment. Default: 1
                     Set to 0 to skip.
  SMOKE_TEST_PYTHON  Optional Python interpreter for smoke tests.
  HOST_SMOKE_VENV    Host virtualenv created when the system Python cannot
                     import requests and the user agrees to create it.
                     Default: .deployment/host-smoke-venv

Examples:
  HOST_DATA_DIR=/home/marco/wrf/data ./admin.sh virtualbox
  HOST_DATA_DIR=/home/marco/wrf/data HOST_APP_PORT=5001 ./admin.sh virtualbox
  HOST_DATA_DIR=/home/marco/wrf/data VM_NETWORK_MODE=nat HOST_APP_IP=192.168.1.50 ./admin.sh virtualbox
  HOST_DATA_DIR=/home/marco/wrf/data VM_NETWORK_MODE=static VM_STATIC_IP=192.168.140.45 ./admin.sh virtualbox
  HOST_DATA_DIR=/home/marco/wrf/data RUN_SMOKE_TESTS=0 ./admin.sh virtualbox

The selected host data directory and VM network configuration are saved in
.deployment/vagrant.env so that later commands such as `vagrant up` can reuse
them automatically.
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

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 was not found. Install it before running the VirtualBox deployment."
}

load_saved_vagrant_env() {
  local line=""
  local key=""
  local value=""
  local current_value=""

  if [[ ! -f "${VAGRANT_ENV_FILE}" ]]; then
    return 0
  fi

  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"

    [[ -z "${line}" || "${line}" == \#* ]] && continue
    [[ "${line}" == *=* ]] || continue

    key="${line%%=*}"
    value="${line#*=}"

    [[ "${key}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue

    current_value="${!key:-}"
    if [[ -z "${current_value}" ]]; then
      printf -v "${key}" '%s' "${value}"
    fi
  done < "${VAGRANT_ENV_FILE}"
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

is_valid_ipv4() {
  local ip="$1"
  local octet
  local -a octets

  [[ "${ip}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1

  IFS='.' read -r -a octets <<< "${ip}"
  for octet in "${octets[@]}"; do
    [[ "${octet}" =~ ^[0-9]+$ ]] || return 1
    ((octet >= 0 && octet <= 255)) || return 1
  done
}

ask_vm_network_mode() {
  local selected_mode=""

  if [[ -n "${VM_NETWORK_MODE}" ]]; then
    return 0
  fi

  if [[ ! -t 0 ]]; then
    VM_NETWORK_MODE="nat"
    return 0
  fi

  cat <<'PROMPT'
How should the VM network be configured?

1) NAT with host port forwarding
2) Static VM network

PROMPT

  read -r -p "Select an option [1]: " selected_mode
  selected_mode="${selected_mode:-1}"

  case "${selected_mode}" in
    1)
      VM_NETWORK_MODE="nat"
      ;;
    2)
      VM_NETWORK_MODE="static"
      ;;
    *)
      fail "Invalid VM network mode option: ${selected_mode}"
      ;;
  esac
}

ask_host_app_ip() {
  local exposure_choice=""
  local selected_ip=""

  if [[ "${VM_NETWORK_MODE}" != "nat" ]]; then
    return 0
  fi

  if [[ -n "${HOST_APP_IP}" ]]; then
    return 0
  fi

  if [[ ! -t 0 ]]; then
    HOST_APP_IP="127.0.0.1"
    return 0
  fi

  cat <<'PROMPT'
How should the VM application port be exposed?

1) Only on a specific host IP
2) On all host IPs, less restrictive

PROMPT

  read -r -p "Select an option [1]: " exposure_choice
  exposure_choice="${exposure_choice:-1}"

  case "${exposure_choice}" in
    1)
      read -r -p "Host IP to expose the application on [127.0.0.1]: " selected_ip
      selected_ip="${selected_ip:-127.0.0.1}"
      ;;
    2)
      selected_ip="0.0.0.0"
      ;;
    *)
      fail "Invalid host app exposure option: ${exposure_choice}"
      ;;
  esac

  is_valid_ipv4 "${selected_ip}" || fail "Invalid IPv4 address for HOST_APP_IP: ${selected_ip}"
  HOST_APP_IP="${selected_ip}"
}

ask_static_vm_network() {
  local value=""

  if [[ "${VM_NETWORK_MODE}" != "static" ]]; then
    return 0
  fi

  if [[ ! -t 0 ]]; then
    VM_STATIC_IP="${VM_STATIC_IP:-192.168.140.45}"
    VM_STATIC_NETMASK="${VM_STATIC_NETMASK:-255.255.255.0}"
    VM_STATIC_GATEWAY="${VM_STATIC_GATEWAY:-192.168.140.1}"
    VM_STATIC_DNS="${VM_STATIC_DNS:-192.168.110.11}"
    return 0
  fi

  read -r -p "VM static IP [${VM_STATIC_IP:-192.168.140.45}]: " value
  VM_STATIC_IP="${value:-${VM_STATIC_IP:-192.168.140.45}}"

  read -r -p "VM netmask [${VM_STATIC_NETMASK:-255.255.255.0}]: " value
  VM_STATIC_NETMASK="${value:-${VM_STATIC_NETMASK:-255.255.255.0}}"

  read -r -p "VM gateway [${VM_STATIC_GATEWAY:-192.168.140.1}]: " value
  VM_STATIC_GATEWAY="${value:-${VM_STATIC_GATEWAY:-192.168.140.1}}"

  read -r -p "VM DNS [${VM_STATIC_DNS:-192.168.110.11}]: " value
  VM_STATIC_DNS="${value:-${VM_STATIC_DNS:-192.168.110.11}}"

  read -r -p "Host bridge interface, leave empty to let Vagrant ask/select automatically [${VM_BRIDGE_INTERFACE:-}]: " value
  VM_BRIDGE_INTERFACE="${value:-${VM_BRIDGE_INTERFACE:-}}"
}

validate_network_configuration() {
  case "${VM_NETWORK_MODE}" in
    nat)
      HOST_APP_IP="${HOST_APP_IP:-127.0.0.1}"
      is_valid_ipv4 "${HOST_APP_IP}" || fail "Invalid IPv4 address for HOST_APP_IP: ${HOST_APP_IP}"
      ;;
    static)
      VM_STATIC_IP="${VM_STATIC_IP:-192.168.140.45}"
      VM_STATIC_NETMASK="${VM_STATIC_NETMASK:-255.255.255.0}"
      VM_STATIC_GATEWAY="${VM_STATIC_GATEWAY:-192.168.140.1}"
      VM_STATIC_DNS="${VM_STATIC_DNS:-192.168.110.11}"

      is_valid_ipv4 "${VM_STATIC_IP}" || fail "Invalid IPv4 address for VM_STATIC_IP: ${VM_STATIC_IP}"
      is_valid_ipv4 "${VM_STATIC_NETMASK}" || fail "Invalid IPv4 address for VM_STATIC_NETMASK: ${VM_STATIC_NETMASK}"
      is_valid_ipv4 "${VM_STATIC_GATEWAY}" || fail "Invalid IPv4 address for VM_STATIC_GATEWAY: ${VM_STATIC_GATEWAY}"
      is_valid_ipv4 "${VM_STATIC_DNS}" || fail "Invalid IPv4 address for VM_STATIC_DNS: ${VM_STATIC_DNS}"
      ;;
    *)
      fail "Unsupported VM_NETWORK_MODE: ${VM_NETWORK_MODE}. Expected 'nat' or 'static'."
      ;;
  esac
}

get_host_smoke_test_base_url() {
  case "${VM_NETWORK_MODE}" in
    static)
      printf 'http://%s:5000\n' "${VM_STATIC_IP}"
      ;;
    nat)
      if [[ "${HOST_APP_IP}" == "0.0.0.0" ]]; then
        printf 'http://127.0.0.1:%s\n' "${HOST_APP_PORT}"
      else
        printf 'http://%s:%s\n' "${HOST_APP_IP}" "${HOST_APP_PORT}"
      fi
      ;;
    *)
      fail "Unsupported VM_NETWORK_MODE for smoke tests: ${VM_NETWORK_MODE}"
      ;;
  esac
}

save_vagrant_env() {
  mkdir -p "${PROJECT_ROOT}/.deployment"
  cat > "${VAGRANT_ENV_FILE}" <<EOF_ENV
HOST_DATA_DIR=${HOST_DATA_DIR}
GUEST_DATA_DIR=${GUEST_DATA_DIR}
HOST_APP_IP=${HOST_APP_IP}
HOST_APP_PORT=${HOST_APP_PORT}
VM_NETWORK_MODE=${VM_NETWORK_MODE}
VM_BRIDGE_INTERFACE=${VM_BRIDGE_INTERFACE}
VM_STATIC_IP=${VM_STATIC_IP}
VM_STATIC_NETMASK=${VM_STATIC_NETMASK}
VM_STATIC_GATEWAY=${VM_STATIC_GATEWAY}
VM_STATIC_DNS=${VM_STATIC_DNS}
EOF_ENV
  ok "Saved Vagrant host configuration: ${VAGRANT_ENV_FILE}"
}

run_host_smoke_tests() {
  local python_bin=""
  local base_url=""

  [[ -f "${PROJECT_ROOT}/scripts/smoke_tests.py" ]] || fail "Smoke test script not found: ${PROJECT_ROOT}/scripts/smoke_tests.py"

  base_url="$(get_host_smoke_test_base_url)"

  if ! python_bin="$(select_or_prepare_smoke_test_python "${PROJECT_ROOT}")"; then
    warn "Host-side smoke tests skipped."
    return 0
  fi

  ok "Running host-side smoke tests with: ${python_bin}"
  ok "Smoke test base URL: ${base_url}"
  BASE_URL="${base_url}" "${python_bin}" "${PROJECT_ROOT}/scripts/smoke_tests.py"
  ok "Host-side smoke tests completed"
}

[[ -f "${SMOKE_PYTHON_HELPER}" ]] || fail "Smoke-test Python helper not found: ${SMOKE_PYTHON_HELPER}"
[[ -x "${VAGRANT_RUNNER}" ]] || fail "Vagrant runner script not found or not executable: ${VAGRANT_RUNNER}"
require_command VBoxManage

if [[ -z "${HOST_DATA_DIR}" || -z "${VM_NETWORK_MODE}" ]]; then
  load_saved_vagrant_env
fi

if [[ -z "${HOST_DATA_DIR}" ]]; then
  if [[ -t 0 ]]; then
    read -r -p "Host data directory to mount in the VM: " HOST_DATA_DIR
  else
    fail "HOST_DATA_DIR is required in non-interactive mode."
  fi
fi

ask_vm_network_mode
ask_host_app_ip
ask_static_vm_network
validate_network_configuration

[[ -n "${HOST_DATA_DIR}" ]] || fail "Host data directory cannot be empty."

HOST_DATA_DIR="$(abs_path "${HOST_DATA_DIR}")"
[[ -d "${HOST_DATA_DIR}" ]] || fail "Host data directory does not exist: ${HOST_DATA_DIR}"

export HOST_DATA_DIR
export GUEST_DATA_DIR
export HOST_APP_IP
export HOST_APP_PORT
export VM_NETWORK_MODE
export VM_BRIDGE_INTERFACE
export VM_STATIC_IP
export VM_STATIC_NETMASK
export VM_STATIC_GATEWAY
export VM_STATIC_DNS

save_vagrant_env

cd "${PROJECT_ROOT}"
ok "Project root: ${PROJECT_ROOT}"
ok "Host data directory: ${HOST_DATA_DIR}"
ok "Guest data directory: ${GUEST_DATA_DIR}"
ok "VM network mode: ${VM_NETWORK_MODE}"

if [[ "${VM_NETWORK_MODE}" == "static" ]]; then
  ok "VM static IP: ${VM_STATIC_IP}"
  ok "VM static netmask: ${VM_STATIC_NETMASK}"
  ok "VM static gateway: ${VM_STATIC_GATEWAY}"
  ok "VM static DNS: ${VM_STATIC_DNS}"
  if [[ -n "${VM_BRIDGE_INTERFACE}" ]]; then
    ok "Host bridge interface: ${VM_BRIDGE_INTERFACE}"
  else
    ok "Host bridge interface: automatic or Vagrant prompt"
  fi
else
  ok "Host app IP: ${HOST_APP_IP}"
  ok "Host app port: ${HOST_APP_PORT}"
fi

ok "Stopping existing VirtualBox VM before deployment, if any"
bash "${VAGRANT_RUNNER}" halt || true

bash "${VAGRANT_RUNNER}" up

ok "VirtualBox deployment completed"
ok "API should be reachable for smoke tests at: $(get_host_smoke_test_base_url)"

if [[ "${VM_NETWORK_MODE}" == "nat" && "${HOST_APP_IP}" == "0.0.0.0" ]]; then
  ok "API should also be reachable from clients through any allowed host IP on port ${HOST_APP_PORT}"
elif [[ "${VM_NETWORK_MODE}" == "nat" && "${HOST_APP_IP}" != "127.0.0.1" ]]; then
  ok "API should also be reachable from clients at: http://${HOST_APP_IP}:${HOST_APP_PORT}"
elif [[ "${VM_NETWORK_MODE}" == "static" ]]; then
  ok "API should be reachable at the static VM endpoint if routing and firewall allow it: http://${VM_STATIC_IP}:5000"
fi

if is_false "${RUN_SMOKE_TESTS}"; then
  ok "Host-side smoke tests skipped because RUN_SMOKE_TESTS=${RUN_SMOKE_TESTS}"
else
  run_host_smoke_tests
fi
