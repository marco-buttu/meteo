#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
RUN_USER="${1:?run user is required}"
SHARED_GROUP="${2:?shared group is required}"
SHARED_DIR="${3:?shared directory is required}"
DATA_DIR="${4:-}"
ASSUME_YES="${ASSUME_YES:-0}"
VAGRANT_USER_ENV_FILE="${PROJECT_ROOT}/.deployment/host-vagrant-user.env"

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

ok() {
  echo "[OK] $*"
}

warn() {
  echo "[WARNING] $*" >&2
}

confirm_permission_update() {
  if [[ "${ASSUME_YES}" == "1" ]]; then
    return 0
  fi
  if [[ ! -t 0 ]]; then
    return 1
  fi

  cat <<EOF_PROMPT
The provisioning can make the project tree group-writable for ${SHARED_GROUP}
and keep group ownership on newly created files/directories.

Project root:
  ${PROJECT_ROOT}

Shared directory:
  ${SHARED_DIR}

EOF_PROMPT
  read -r -p "Apply group permissions now? [Y/n]: " answer
  case "${answer}" in
    ""|y|Y|yes|YES|Yes) return 0 ;;
    *) return 1 ;;
  esac
}

check_access_as_run_user() {
  local label="$1"
  local path="$2"
  local mode="$3"

  [[ -e "${path}" ]] || fail "${label} does not exist: ${path}"

  case "${mode}" in
    read)
      runuser -u "${RUN_USER}" -- test -r "${path}" || fail "${RUN_USER} cannot read ${label}: ${path}"
      ;;
    write)
      runuser -u "${RUN_USER}" -- test -w "${path}" || fail "${RUN_USER} cannot write ${label}: ${path}"
      ;;
    execute)
      runuser -u "${RUN_USER}" -- test -x "${path}" || fail "${RUN_USER} cannot access ${label}: ${path}"
      ;;
    *)
      fail "Unsupported access mode: ${mode}"
      ;;
  esac
  ok "${RUN_USER} can ${mode} ${label}: ${path}"
}

[[ "${EUID}" -eq 0 ]] || fail "This script must be run as root. Use sudo."
[[ -d "${SHARED_DIR}" ]] || fail "Shared directory does not exist: ${SHARED_DIR}"
[[ "${PROJECT_ROOT}" == "${SHARED_DIR}" || "${PROJECT_ROOT}" == "${SHARED_DIR}"/* ]] || \
  warn "Project root is not inside the shared directory: ${PROJECT_ROOT} not under ${SHARED_DIR}"

mkdir -p "${PROJECT_ROOT}/.deployment"

if confirm_permission_update; then
  ok "Setting group ownership and permissions for project tree"
  chgrp -R "${SHARED_GROUP}" "${PROJECT_ROOT}"
  chmod -R g+rwX "${PROJECT_ROOT}"
  find "${PROJECT_ROOT}" -type d -exec chmod g+s {} +
else
  warn "Permission update skipped. Existing permissions must already allow ${RUN_USER} to manage Vagrant state."
fi

cat > "${VAGRANT_USER_ENV_FILE}" <<EOF_ENV
VAGRANT_RUN_USER=${RUN_USER}
EOF_ENV
chgrp "${SHARED_GROUP}" "${VAGRANT_USER_ENV_FILE}"
chmod 664 "${VAGRANT_USER_ENV_FILE}"
ok "Saved Vagrant run user configuration: ${VAGRANT_USER_ENV_FILE}"

check_access_as_run_user "shared directory" "${SHARED_DIR}" execute
check_access_as_run_user "project root" "${PROJECT_ROOT}" read
check_access_as_run_user "project root" "${PROJECT_ROOT}" write
check_access_as_run_user "deployment state directory" "${PROJECT_ROOT}/.deployment" write

if [[ -n "${DATA_DIR}" ]]; then
  [[ -d "${DATA_DIR}" ]] || fail "Data directory does not exist: ${DATA_DIR}"
  check_access_as_run_user "data directory" "${DATA_DIR}" read
fi
