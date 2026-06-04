#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

ok() {
  echo "[OK] $*"
}

require_root() {
  [[ "${EUID}" -eq 0 ]] || fail "Host provisioning must be run as root. Use sudo."
}

require_project_root() {
  [[ -f "${PROJECT_ROOT}/deploy.sh" ]] || fail "deploy.sh not found in project root: ${PROJECT_ROOT}"
  [[ -f "${PROJECT_ROOT}/Vagrantfile" ]] || fail "Vagrantfile not found in project root: ${PROJECT_ROOT}"
  ok "Project root: ${PROJECT_ROOT}"
}

require_command_if_available() {
  local command_name="$1"
  if command -v "${command_name}" >/dev/null 2>&1; then
    ok "${command_name} is available: $(command -v "${command_name}")"
  else
    echo "[WARNING] ${command_name} was not found. The normal deployment preflight can install/check it later." >&2
  fi
}

require_root
require_project_root
require_command_if_available vagrant
require_command_if_available VBoxManage
