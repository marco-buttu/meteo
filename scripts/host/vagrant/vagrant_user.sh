#!/usr/bin/env bash
# shellcheck shell=bash

# Shared helpers for running Vagrant with a stable technical user.
# This file is meant to be sourced by host-side Vagrant scripts.

VAGRANT_USER_ENV_FILE="${VAGRANT_USER_ENV_FILE:-${PROJECT_ROOT}/.deployment/host-vagrant-user.env}"

load_vagrant_run_user() {
  if [[ -f "${VAGRANT_USER_ENV_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${VAGRANT_USER_ENV_FILE}"
  fi
  VAGRANT_RUN_USER="${VAGRANT_RUN_USER:-}"
}

current_username() {
  id -un
}

vagrant_run_user_is_configured() {
  [[ -n "${VAGRANT_RUN_USER:-}" ]]
}

ensure_vagrant_run_user_exists() {
  if vagrant_run_user_is_configured && ! id "${VAGRANT_RUN_USER}" >/dev/null 2>&1; then
    echo "[FAIL] Configured VAGRANT_RUN_USER does not exist: ${VAGRANT_RUN_USER}" >&2
    echo "Run host provisioning first: sudo ./deploy.sh host-provision" >&2
    exit 1
  fi
}
