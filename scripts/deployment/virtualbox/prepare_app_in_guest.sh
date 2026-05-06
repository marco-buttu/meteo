#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/meteo}"
SOURCE_DIR="${SOURCE_DIR:-/vagrant}"
GUEST_DATA_DIR="${GUEST_DATA_DIR:-/dati}"
RUN_USER="${METEO_RUN_USER:-vagrant}"
RUN_GROUP="${METEO_RUN_GROUP:-vagrant}"

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

ok() {
  echo "[OK] $*"
}

set_env_value() {
  local file="$1"
  local key="$2"
  local value="$3"

  if grep -q "^${key}=" "$file"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$file"
  else
    printf '%s=%s\n' "$key" "$value" >> "$file"
  fi
}

require_root() {
  [[ "${EUID}" -eq 0 ]] || fail "This script must run as root. Use sudo."
}

install_rsync_if_missing() {
  if command -v rsync >/dev/null 2>&1; then
    return 0
  fi

  ok "Installing rsync"
  apt-get update
  apt-get install -y rsync
}

validate_guest_context() {
  [[ -d "${SOURCE_DIR}" ]] || fail "Source directory not found: ${SOURCE_DIR}"
  [[ -d "${GUEST_DATA_DIR}" ]] || fail "Guest data directory not mounted: ${GUEST_DATA_DIR}"
  id "${RUN_USER}" >/dev/null 2>&1 || fail "Runtime user does not exist: ${RUN_USER}"
  getent group "${RUN_GROUP}" >/dev/null 2>&1 || fail "Runtime group does not exist: ${RUN_GROUP}"
}

copy_project() {
  ok "Copying application from ${SOURCE_DIR} to ${APP_DIR}"
  mkdir -p "${APP_DIR}"
  rsync -a --delete \
    --exclude '.git' \
    --exclude '.venv' \
    --exclude '.vagrant' \
    --exclude '.deployment' \
    --exclude 'runtime_data' \
    --exclude '__pycache__' \
    "${SOURCE_DIR}/" "${APP_DIR}/"
  chown -R "${RUN_USER}:${RUN_GROUP}" "${APP_DIR}"
}

configure_env() {
  cd "${APP_DIR}"
  [[ -f ".env" ]] || fail ".env not found in ${APP_DIR}"

  ok "Configuring .env for the VM"
  set_env_value ".env" "DATA_DIR" "${GUEST_DATA_DIR}"
  set_env_value ".env" "FLASK_HOST" "0.0.0.0"
  set_env_value ".env" "FLASK_PORT" "5000"
  set_env_value ".env" "FLASK_DEBUG" "0"
  set_env_value ".env" "REDIS_URL" "redis://127.0.0.1:6379/0"
  set_env_value ".env" "JOB_STORAGE_DIR" "./runtime_data/jobs"
  set_env_value ".env" "PLOT_STORAGE_DIR" "./runtime_data/plots"
}

require_root
validate_guest_context
install_rsync_if_missing
copy_project
configure_env

ok "Guest application tree is ready at ${APP_DIR}"
