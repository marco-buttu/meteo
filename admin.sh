#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST_DEP_CHECK="${PROJECT_ROOT}/scripts/host/vagrant/check_dependencies.sh"
VAGRANT_RUNNER="${PROJECT_ROOT}/scripts/host/vagrant/run_vagrant_command.sh"
HOST_PROVISIONER="${PROJECT_ROOT}/scripts/host/provisioning/provision_host.sh"
HOST_UNPROVISIONER="${PROJECT_ROOT}/scripts/host/provisioning/unprovision_host.sh"

usage() {
  cat <<'USAGE'
Usage: ./admin.sh [target]

Targets:
  local              Deploy on the current Debian/Ubuntu/Linux Mint machine.
  host-provision     Prepare the host for shared VM management. Must be run with sudo.
  host-unprovision   Remove host provisioning artifacts. Must be run with sudo.
  virtualbox|vm      Create or provision a VirtualBox VM through Vagrant.
  vm-reinstall       Reinstall the app inside the existing VirtualBox VM.
  vm-fresh           Destroy and recreate the VirtualBox VM, then deploy again.
  vm-start           Start the existing VirtualBox VM without provisioning.
  vm-stop            Stop the existing VirtualBox VM.
  help               Show this help message.

Common VirtualBox variables:
  HOST_DATA_DIR      Host data directory mounted in the VM. Asked interactively
                     during deployment and saved in .deployment/vagrant.env.
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
  RUN_SMOKE_TESTS    Run host-side smoke tests after VM deployment. Default: 1
                     Set to 0 to skip.

Examples:
  ./admin.sh local
  sudo ./admin.sh host-provision
  sudo ./admin.sh host-unprovision
  ./admin.sh virtualbox
  ./admin.sh vm-reinstall
  ./admin.sh vm-fresh
  ./admin.sh vm-start
  ./admin.sh vm-stop
USAGE
}

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

ok() {
  echo "[OK] $*"
}

require_vagrant_project() {
  [[ -f "${PROJECT_ROOT}/Vagrantfile" ]] || fail "Vagrantfile not found in project root: ${PROJECT_ROOT}"
}

run_vagrant() {
  require_vagrant_project
  [[ -x "${HOST_DEP_CHECK}" ]] || fail "Host dependency check script not found or not executable: ${HOST_DEP_CHECK}"
  [[ -x "${VAGRANT_RUNNER}" ]] || fail "Vagrant runner script not found or not executable: ${VAGRANT_RUNNER}"
  bash "${HOST_DEP_CHECK}" --virtualbox --no-smoke-tests
  bash "${VAGRANT_RUNNER}" "$@"
}

run_target() {
  local target="$1"
  shift || true

  case "${target}" in
    host-provision|provision-host)
      bash "${HOST_PROVISIONER}" "$@"
      ;;
    host-unprovision|unprovision-host|host-clean)
      bash "${HOST_UNPROVISIONER}" "$@"
      ;;
    local)
      [[ $# -eq 0 ]] || fail "Target ${target} does not accept extra arguments"
      bash "${PROJECT_ROOT}/scripts/app/deployment/deploy_local.sh"
      ;;
    virtualbox|vm)
      [[ $# -eq 0 ]] || fail "Target ${target} does not accept extra arguments"
      bash "${PROJECT_ROOT}/scripts/host/vagrant/deploy_virtualbox.sh"
      ;;
    vm-reinstall|reinstall-vm|reinstall)
      [[ $# -eq 0 ]] || fail "Target ${target} does not accept extra arguments"
      bash "${PROJECT_ROOT}/scripts/host/vagrant/reinstall_app.sh"
      ;;
    vm-fresh|fresh-vm|fresh)
      [[ $# -eq 0 ]] || fail "Target ${target} does not accept extra arguments"
      bash "${PROJECT_ROOT}/scripts/host/vagrant/fresh_deploy.sh"
      ;;
    vm-start|start-vm|start)
      [[ $# -eq 0 ]] || fail "Target ${target} does not accept extra arguments"
      ok "Starting existing VirtualBox VM without provisioning"
      run_vagrant up --no-provision
      ok "VM started"
      ;;
    vm-stop|stop-vm|stop)
      [[ $# -eq 0 ]] || fail "Target ${target} does not accept extra arguments"
      ok "Stopping existing VirtualBox VM"
      run_vagrant halt
      ok "VM stopped"
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown deployment target: ${target}"
      ;;
  esac
}

show_menu() {
  cat <<'MENU'
Meteo application administration
================================

Local machine installation
--------------------------
  1) Deploy locally
     Install dependencies, set up the app, install systemd services,
     and start the app on this machine.

VirtualBox / Vagrant installation
---------------------------------
  2) Provision host for shared VM management
     Create/configure the technical Vagrant user, shared permissions and
     optional VM autostart service. Must be run with sudo.

  3) Unprovision host
     Disable/remove the host VM autostart service and local Vagrant user
     configuration. Optionally remove the technical user. Must be run with sudo.

  4) Deploy to VirtualBox VM
     Create or start the VM and run the normal provisioning.

  5) Reinstall app inside existing VM
     Keep the VM, Ubuntu, Redis and system packages.
     Remove and reinstall only the app inside the VM.

  6) Fresh VirtualBox VM deployment
     Destroy the existing Vagrant VM and create it again from scratch.
     Use this when you want a completely clean VM deployment.

  7) Start existing VM
     Start the VM without provisioning.

  8) Stop existing VM
     Shut down the VM.

Other
-----
  0) Exit

MENU
}

if [[ $# -ge 1 ]]; then
  run_target "$@"
  exit 0
fi

show_menu
read -r -p "Select an option: " selection

case "${selection}" in
  1) run_target local ;;
  2) run_target host-provision ;;
  3) run_target host-unprovision ;;
  4) run_target virtualbox ;;
  5) run_target vm-reinstall ;;
  6) run_target vm-fresh ;;
  7) run_target vm-start ;;
  8) run_target vm-stop ;;
  0|q|Q) exit 0 ;;
  *) fail "Invalid selection: ${selection}" ;;
esac
