#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ASSUME_YES="${ASSUME_YES:-0}"
HOST_DEP_CHECK="${PROJECT_ROOT}/scripts/host/vagrant/check_dependencies.sh"
VAGRANT_ENV_FILE="${PROJECT_ROOT}/.deployment/vagrant.env"
VAGRANT_RUNNER="${PROJECT_ROOT}/scripts/host/vagrant/run_vagrant_command.sh"
VAGRANT_USER_HELPER="${PROJECT_ROOT}/scripts/host/vagrant/vagrant_user.sh"
VM_NETWORK_MODE="${VM_NETWORK_MODE:-}"

usage() {
  cat <<'USAGE'
Usage: scripts/host/vagrant/fresh_deploy.sh [options]

Destroy the existing Vagrant VM for this project, remove the local .vagrant
state directory, and run a new VirtualBox deployment from scratch.

Options:
  -y, --yes   Do not ask for confirmation.
  -h, --help  Show this help message.

Environment variables:
  HOST_DATA_DIR      Optional. If unset, deploy_virtualbox.sh asks for it or
                     reads it from .deployment/vagrant.env when compatible.
  VM_NETWORK_MODE    Optional. VM network mode: nat or static.
  HOST_APP_IP        Optional. NAT mode host IP for the forwarded app port.
  HOST_APP_PORT      Host port forwarded to guest port 5000. Default: 5000
  VM_STATIC_IP       Optional. Static VM IP used when VM_NETWORK_MODE=static.
  VM_STATIC_NETMASK  Optional. Static VM netmask.
  VM_STATIC_GATEWAY  Optional. Static VM gateway.
  VM_STATIC_DNS      Optional. Static VM DNS server.
  RUN_SMOKE_TESTS    Run host-side smoke tests after deployment. Default: 1
                     Set to 0 to skip.
  INSTALL_HOST_DEPS  Host dependency installation mode:
                       unset  ask interactively if something is missing
                       1      install missing host packages automatically
                       0      never install, fail if something is missing
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
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

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

ok() {
  echo "[OK] $*"
}

# shellcheck disable=SC1090
source "${VAGRANT_USER_HELPER}"

remove_vagrant_state_dir() {
  [[ -d "${PROJECT_ROOT}/.vagrant" ]] || return 0

  load_vagrant_run_user
  if vagrant_run_user_is_configured && [[ "$(id -un)" != "${VAGRANT_RUN_USER}" ]]; then
    ok "Removing local Vagrant state directory as ${VAGRANT_RUN_USER}"
    sudo -H -u "${VAGRANT_RUN_USER}" rm -rf "${PROJECT_ROOT}/.vagrant"
  else
    ok "Removing local Vagrant state directory"
    rm -rf "${PROJECT_ROOT}/.vagrant"
  fi
}

read_saved_value() {
  local key="$1"
  local line=""

  [[ -f "${VAGRANT_ENV_FILE}" ]] || return 1

  while IFS= read -r line || [[ -n "${line}" ]]; do
    [[ "${line}" == "${key}="* ]] || continue
    printf '%s\n' "${line#*=}"
    return 0
  done < "${VAGRANT_ENV_FILE}"

  return 1
}

saved_config_has_key() {
  local key="$1"
  [[ -f "${VAGRANT_ENV_FILE}" ]] || return 1
  grep -q "^${key}=" "${VAGRANT_ENV_FILE}"
}

confirm() {
  if [[ "${ASSUME_YES}" == "1" ]]; then
    return 0
  fi

  cat <<'WARNING'
This will destroy and recreate the Vagrant VM for this project.
The VM will be removed, then provisioned again from scratch.
WARNING
  read -r -p "Continue? [y/N]: " answer
  case "${answer}" in
    y|Y|yes|YES) return 0 ;;
    *) fail "Fresh deployment cancelled." ;;
  esac
}

ask_vm_network_mode() {
  local selected_mode=""

  if [[ -n "${VM_NETWORK_MODE}" ]]; then
    case "${VM_NETWORK_MODE}" in
      nat|static) return 0 ;;
      *) fail "Unsupported VM_NETWORK_MODE: ${VM_NETWORK_MODE}. Expected 'nat' or 'static'." ;;
    esac
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

saved_config_is_compatible() {
  local saved_mode=""

  [[ -f "${VAGRANT_ENV_FILE}" ]] || return 1

  saved_mode="$(read_saved_value VM_NETWORK_MODE || true)"

  case "${VM_NETWORK_MODE}" in
    nat)
      # Backward compatibility: older saved configurations without
      # VM_NETWORK_MODE are considered NAT configurations.
      if [[ -z "${saved_mode}" || "${saved_mode}" == "nat" ]]; then
        saved_config_has_key HOST_DATA_DIR || return 1
        saved_config_has_key HOST_APP_PORT || return 1
        return 0
      fi
      return 1
      ;;
    static)
      [[ "${saved_mode}" == "static" ]] || return 1
      saved_config_has_key HOST_DATA_DIR || return 1
      saved_config_has_key VM_STATIC_IP || return 1
      saved_config_has_key VM_STATIC_NETMASK || return 1
      saved_config_has_key VM_STATIC_GATEWAY || return 1
      saved_config_has_key VM_STATIC_DNS || return 1
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

handle_saved_vagrant_env() {
  local answer=""
  local mode_label=""

  if [[ ! -f "${VAGRANT_ENV_FILE}" ]]; then
    return 0
  fi

  case "${VM_NETWORK_MODE}" in
    nat) mode_label="NAT with host port forwarding" ;;
    static) mode_label="Static VM network" ;;
    *) fail "Unsupported VM_NETWORK_MODE: ${VM_NETWORK_MODE}" ;;
  esac

  if ! saved_config_is_compatible; then
    ok "Saved Vagrant configuration is not compatible with selected mode: ${mode_label}"
    ok "Deleting saved Vagrant deployment configuration"
    rm -f "${VAGRANT_ENV_FILE}"
    return 0
  fi

  if [[ "${ASSUME_YES}" == "1" ]]; then
    ok "Reusing compatible saved Vagrant deployment configuration: ${VAGRANT_ENV_FILE}"
    return 0
  fi

  cat <<EOF_PROMPT
A compatible saved Vagrant deployment configuration was found for:
  ${mode_label}

Configuration file:
  ${VAGRANT_ENV_FILE}

How should the fresh deployment proceed?

1) Reuse the saved configuration for this mode
2) Delete the saved configuration and ask again

EOF_PROMPT

  read -r -p "Select an option [1]: " answer
  answer="${answer:-1}"

  case "${answer}" in
    1)
      ok "Reusing compatible saved Vagrant deployment configuration: ${VAGRANT_ENV_FILE}"
      ;;
    2)
      ok "Deleting saved Vagrant deployment configuration"
      rm -f "${VAGRANT_ENV_FILE}"
      ;;
    *)
      fail "Invalid saved configuration option: ${answer}"
      ;;
  esac
}

[[ -f "${PROJECT_ROOT}/Vagrantfile" ]] || fail "Vagrantfile not found in project root: ${PROJECT_ROOT}"
[[ -x "${HOST_DEP_CHECK}" ]] || fail "Host dependency check script not found or not executable: ${HOST_DEP_CHECK}"
[[ -x "${VAGRANT_RUNNER}" ]] || fail "Vagrant runner script not found or not executable: ${VAGRANT_RUNNER}"

bash "${HOST_DEP_CHECK}" --virtualbox --no-smoke-tests
confirm

cd "${PROJECT_ROOT}"

ok "Stopping existing VirtualBox VM before fresh deployment, if any"
bash "${VAGRANT_RUNNER}" halt || true

ok "Destroying existing Vagrant VM, if any"
bash "${VAGRANT_RUNNER}" destroy -f || true

remove_vagrant_state_dir

ask_vm_network_mode
handle_saved_vagrant_env

ok "Running fresh VirtualBox deployment"
VM_NETWORK_MODE="${VM_NETWORK_MODE}" bash "${PROJECT_ROOT}/scripts/host/vagrant/deploy_virtualbox.sh"
