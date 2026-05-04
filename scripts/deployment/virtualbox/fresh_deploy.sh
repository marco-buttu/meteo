#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ASSUME_YES="${ASSUME_YES:-0}"

usage() {
  cat <<'USAGE'
Usage: scripts/deployment/virtualbox/fresh_deploy.sh [options]

Destroy the existing Vagrant VM for this project, remove the local .vagrant
state directory, and run a new VirtualBox deployment from scratch.

Options:
  -y, --yes   Do not ask for confirmation.
  -h, --help  Show this help message.

Environment variables:
  HOST_DATA_DIR      Optional. If unset, deploy_virtualbox.sh asks for it.
  RUN_SMOKE_TESTS    Run host-side smoke tests after deployment. Default: 1
                     Set to 0 to skip.
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

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 was not found."
}

[[ -f "${PROJECT_ROOT}/Vagrantfile" ]] || fail "Vagrantfile not found in project root: ${PROJECT_ROOT}"
require_command vagrant
confirm

cd "${PROJECT_ROOT}"

ok "Destroying existing Vagrant VM, if any"
vagrant destroy -f || true

ok "Removing local Vagrant state directory"
rm -rf "${PROJECT_ROOT}/.vagrant"

ok "Running fresh VirtualBox deployment"
bash "${PROJECT_ROOT}/scripts/deployment/virtualbox/deploy_virtualbox.sh"
