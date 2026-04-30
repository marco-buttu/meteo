#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
Usage: ./deploy.sh [local|virtualbox|docker]

Choose and run a deployment target.

Targets:
  local       Deploy on the current Debian/Ubuntu/Linux Mint machine.
  virtualbox  Create/provision a VirtualBox VM through Vagrant.
  docker      Placeholder only. Docker deployment is not implemented yet.

For non-interactive VirtualBox deployment, set HOST_DATA_DIR first:

  HOST_DATA_DIR=/path/to/data ./deploy.sh virtualbox
USAGE
}

fail() {
  echo "[FAIL] $*" >&2
  exit 1
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

if [[ $# -gt 1 ]]; then
  usage >&2
  exit 2
fi

if [[ $# -eq 1 ]]; then
  run_target "$1"
fi

cat <<'MENU'
Choose deployment target:

  1) Local machine
  2) VirtualBox VM through Vagrant
  3) Docker - not implemented yet

MENU

read -r -p "Selection [1-3]: " selection

case "${selection}" in
  1) run_target local ;;
  2) run_target virtualbox ;;
  3) run_target docker ;;
  *) fail "Invalid selection: ${selection}" ;;
esac
