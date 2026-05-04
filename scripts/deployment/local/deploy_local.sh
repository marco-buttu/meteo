#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

usage() {
  cat <<'USAGE'
Usage: scripts/deployment/local/deploy_local.sh [options]

Deploy the application on the current Debian/Ubuntu/Linux Mint machine.

Options:
  --no-start  Install and enable systemd services, but do not start them.
  -h, --help  Show this help message.

This script orchestrates the existing native deployment steps. It does not
contain package, Python, or systemd installation logic itself.
USAGE
}

START_SERVICES=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-start)
      START_SERVICES=0
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

ok() {
  echo "[OK] $*"
}

cd "${PROJECT_ROOT}"
ok "Project root: ${PROJECT_ROOT}"

ok "Installing system dependencies"
sudo bash "${PROJECT_ROOT}/scripts/deployment/local/install_system_deps_debian.sh"

ok "Preparing Python application"
bash "${PROJECT_ROOT}/scripts/deployment/local/setup_app.sh"

SYSTEMD_ARGS=()
if [[ "${START_SERVICES}" -eq 1 ]]; then
  SYSTEMD_ARGS+=(--start)
fi

ok "Installing systemd services"
sudo bash "${PROJECT_ROOT}/scripts/deployment/local/install_systemd_services.sh" "${SYSTEMD_ARGS[@]}"

ok "Local deployment completed"
if [[ "${START_SERVICES}" -eq 1 ]]; then
  ok "API service should be available according to FLASK_HOST and FLASK_PORT in .env"
else
  ok "Services installed but not started. Start them with: sudo systemctl start meteo-app meteo-worker"
fi
