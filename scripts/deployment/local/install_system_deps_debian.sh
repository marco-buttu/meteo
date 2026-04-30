#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/deployment/local/install_system_deps_debian.sh [--no-redis-enable]

Install the system packages required by the native Linux deployment.

Options:
  --no-redis-enable  Install Redis but do not enable or start redis-server.
  -h, --help         Show this help message.

This script is intended for Debian, Ubuntu, Linux Mint, and closely related
APT-based distributions. It does not install Python application dependencies.
Use scripts/deployment/local/setup_app.sh for the application setup.
USAGE
}

ENABLE_REDIS=1
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
STATE_DIR="${PROJECT_ROOT}/.deployment"
STATE_FILE="${STATE_DIR}/native-linux-state.env"
SYSTEM_PACKAGES=(
  python3
  python3-venv
  python3-pip
  redis-server
  octave
)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-redis-enable)
      ENABLE_REDIS=0
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

record_package_state() {
  local package
  local key

  mkdir -p "${STATE_DIR}"

  {
    echo "# Native Linux deployment state"
    echo "# Created before installing system dependencies."
    for package in "${SYSTEM_PACKAGES[@]}"; do
      key="PREEXISTING_PACKAGE_${package//-/_}"
      if dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q 'install ok installed'; then
        echo "${key}=1"
      else
        echo "${key}=0"
      fi
    done
  } > "${STATE_FILE}"

  ok "Recorded pre-existing package state: ${STATE_FILE}"
}

if [[ "${EUID}" -ne 0 ]]; then
  fail "This script must be run as root. Use sudo."
fi

if ! command -v apt-get >/dev/null 2>&1; then
  fail "apt-get was not found. This script supports Debian/Ubuntu/Linux Mint systems."
fi

record_package_state

ok "Updating APT package index"
apt-get update

ok "Installing required system packages"
apt-get install -y "${SYSTEM_PACKAGES[@]}"

if [[ "${ENABLE_REDIS}" -eq 1 ]]; then
  if command -v systemctl >/dev/null 2>&1; then
    ok "Enabling and starting redis-server"
    systemctl enable --now redis-server
  else
    ok "systemctl not found; skipping redis-server enable/start"
  fi
else
  ok "Redis enable/start skipped"
fi

ok "System dependency installation completed"
