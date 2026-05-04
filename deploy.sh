#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
Usage: ./deploy.sh [target]

Targets:
  local              Deploy on the current Debian/Ubuntu/Linux Mint machine.
  virtualbox|vm      Create or provision a VirtualBox VM through Vagrant.
  vm-reinstall       Reinstall the app inside the existing VirtualBox VM.
  vm-fresh           Destroy and recreate the VirtualBox VM, then deploy again.
  vm-start           Start the existing VirtualBox VM without provisioning.
  vm-stop            Stop the existing VirtualBox VM.
  docker             Placeholder only. Docker deployment is not implemented yet.
  help               Show this help message.

Common VirtualBox variables:
  HOST_DATA_DIR      Host data directory mounted in the VM. Asked interactively
                     during deployment and saved in .deployment/vagrant.env.
  GUEST_DATA_DIR     Directory where host data are mounted in the VM. Default: /dati
  HOST_APP_PORT      Host port forwarded to guest port 5000. Default: 5000
  RUN_SMOKE_TESTS    Run host-side smoke tests after VM deployment. Default: 1
                     Set to 0 to skip.

Examples:
  ./deploy.sh local
  ./deploy.sh virtualbox
  ./deploy.sh vm-reinstall
  ./deploy.sh vm-fresh
  ./deploy.sh vm-start
  ./deploy.sh vm-stop
  ./deploy.sh docker
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
  cd "${PROJECT_ROOT}"
  vagrant "$@"
}

run_target() {
  local target="$1"
  case "${target}" in
    local)
      bash "${PROJECT_ROOT}/scripts/deployment/local/deploy_local.sh"
      ;;
    virtualbox|vm)
      bash "${PROJECT_ROOT}/scripts/deployment/virtualbox/deploy_virtualbox.sh"
      ;;
    vm-reinstall|reinstall-vm|reinstall)
      bash "${PROJECT_ROOT}/scripts/deployment/virtualbox/reinstall_app.sh"
      ;;
    vm-fresh|fresh-vm|fresh)
      bash "${PROJECT_ROOT}/scripts/deployment/virtualbox/fresh_deploy.sh"
      ;;
    vm-start|start-vm|start)
      ok "Starting existing VirtualBox VM without provisioning"
      run_vagrant up --no-provision
      ok "VM started"
      ;;
    vm-stop|stop-vm|stop)
      ok "Stopping existing VirtualBox VM"
      run_vagrant halt
      ok "VM stopped"
      ;;
    docker)
      echo "Docker deployment is not implemented yet."
      exit 0
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
Meteo deployment manager
========================

Local machine
-------------
  1) Deploy locally
     Install dependencies, set up the app, install systemd services,
     and start the app on this machine.

VirtualBox / Vagrant
--------------------
  2) Deploy to VirtualBox VM
     Create or start the VM and run the normal provisioning.

  3) Reinstall app inside existing VM
     Keep the VM, Ubuntu, Redis and system packages.
     Remove and reinstall only the app inside the VM.

  4) Fresh VirtualBox VM deployment
     Destroy the existing Vagrant VM and create it again from scratch.
     Use this when you want a completely clean VM deployment.

  5) Start existing VM
     Start the VM without provisioning.

  6) Stop existing VM
     Shut down the VM.

Docker
------
  7) Docker deployment
     Not implemented yet.

Other
-----
  q) Quit

MENU
}

if [[ $# -gt 1 ]]; then
  usage >&2
  exit 2
fi

if [[ $# -eq 1 ]]; then
  run_target "$1"
fi

show_menu
read -r -p "Select an option: " selection

case "${selection}" in
  1) run_target local ;;
  2) run_target virtualbox ;;
  3) run_target vm-reinstall ;;
  4) run_target vm-fresh ;;
  5) run_target vm-start ;;
  6) run_target vm-stop ;;
  7) run_target docker ;;
  q|Q) exit 0 ;;
  *) fail "Invalid selection: ${selection}" ;;
esac
