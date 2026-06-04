#!/usr/bin/env bash
# shellcheck shell=bash

# Helper functions for selecting the Python interpreter used by host-side smoke
# tests and ensuring that the same interpreter can import requests.
# This file is meant to be sourced by deployment scripts.

_host_color_enabled() {
  [[ -t 2 ]] && [[ -z "${NO_COLOR:-}" ]]
}

_host_yellow() {
  if _host_color_enabled; then
    printf '\033[33m%s\033[0m\n' "$*" >&2
  else
    printf '%s\n' "$*" >&2
  fi
}

_host_ok() {
  printf '[OK] %s\n' "$*" >&2
}

_host_warn() {
  _host_yellow "[WARNING] $*"
}

_host_fail() {
  printf '[FAIL] %s\n' "$*" >&2
}

_host_python_can_import_requests() {
  local python_bin="$1"
  "${python_bin}" - <<'PY' >/dev/null 2>&1
import requests
PY
}

_host_python_has_pip() {
  local python_bin="$1"
  "${python_bin}" -m pip --version >/dev/null 2>&1
}

_host_is_system_python() {
  local python_bin="$1"
  local resolved=""

  resolved="$(readlink -f "${python_bin}" 2>/dev/null || printf '%s' "${python_bin}")"
  case "${resolved}" in
    /usr/bin/python*|/bin/python*) return 0 ;;
    *) return 1 ;;
  esac
}

_host_prompt_yes_default() {
  local prompt="$1"
  local answer=""

  if [[ ! -t 0 ]]; then
    return 1
  fi

  read -r -p "${prompt} [Y/n]: " answer
  case "${answer}" in
    ""|y|Y|yes|YES|Yes) return 0 ;;
    *) return 1 ;;
  esac
}

_host_install_requests_with_pip() {
  local python_bin="$1"

  if ! _host_python_has_pip "${python_bin}"; then
    _host_ok "pip is not available for ${python_bin}; trying ensurepip"
    "${python_bin}" -m ensurepip --upgrade >/dev/null 2>&1 || return 1
  fi

  "${python_bin}" -m pip install requests >&2
}

_host_prepare_dedicated_smoke_venv() {
  local project_root="$1"
  local venv_path="$2"

  mkdir -p "$(dirname "${venv_path}")"
  python3 -m venv "${venv_path}" || return 1
  "${venv_path}/bin/python" -m pip install --upgrade pip >&2
  "${venv_path}/bin/python" -m pip install requests >&2
  printf '%s\n' "${venv_path}/bin/python"
}

_host_ensure_requests_or_skip() {
  local python_bin="$1"
  local label="$2"

  if _host_python_can_import_requests "${python_bin}"; then
    printf '%s\n' "${python_bin}"
    return 0
  fi

  _host_warn "Python module 'requests' is missing for host-side smoke tests."
  _host_warn "Python interpreter: ${python_bin} (${label})"

  if _host_prompt_yes_default "Install requests in this Python environment?"; then
    if _host_install_requests_with_pip "${python_bin}"; then
      _host_python_can_import_requests "${python_bin}" || {
        _host_warn "requests still cannot be imported after installation. Host-side smoke tests will be skipped."
        return 1
      }
      printf '%s\n' "${python_bin}"
      return 0
    fi

    _host_warn "Could not install requests in ${python_bin}. Host-side smoke tests will be skipped."
    return 1
  fi

  _host_warn "requests was not installed. Host-side smoke tests will be skipped."
  return 1
}

# Select the Python interpreter for smoke tests.
# Prints the interpreter path on stdout and returns 0 when smoke tests can run.
# Returns 1 when smoke tests should be skipped.
select_or_prepare_smoke_test_python() {
  local project_root="${1:?project root is required}"
  local smoke_test_python="${SMOKE_TEST_PYTHON:-}"
  local host_smoke_venv="${HOST_SMOKE_VENV:-${project_root}/.deployment/host-smoke-venv}"
  local python_bin=""

  if [[ -n "${smoke_test_python}" ]]; then
    [[ -x "${smoke_test_python}" ]] || {
      _host_warn "SMOKE_TEST_PYTHON is not executable: ${smoke_test_python}. Host-side smoke tests will be skipped."
      return 1
    }
    _host_ensure_requests_or_skip "${smoke_test_python}" "SMOKE_TEST_PYTHON"
    return $?
  fi

  if [[ -n "${VIRTUAL_ENV:-}" ]] && [[ -x "${VIRTUAL_ENV}/bin/python" ]]; then
    _host_ensure_requests_or_skip "${VIRTUAL_ENV}/bin/python" "active virtual environment"
    return $?
  fi

  if command -v python3 >/dev/null 2>&1; then
    python_bin="$(command -v python3)"

    if _host_python_can_import_requests "${python_bin}"; then
      printf '%s\n' "${python_bin}"
      return 0
    fi

    if _host_is_system_python "${python_bin}"; then
      _host_warn "The host system Python cannot import requests."
      _host_warn "Python interpreter: ${python_bin}"
      _host_warn "A dedicated smoke-test virtual environment can be created at: ${host_smoke_venv}"
      if _host_prompt_yes_default "Create this virtual environment and install requests there?"; then
        _host_prepare_dedicated_smoke_venv "${project_root}" "${host_smoke_venv}" || {
          _host_warn "Could not create the dedicated smoke-test virtual environment. Host-side smoke tests will be skipped."
          return 1
        }
        return 0
      fi

      _host_warn "Dedicated smoke-test virtual environment was not created. Host-side smoke tests will be skipped."
      return 1
    fi

    _host_ensure_requests_or_skip "${python_bin}" "python3 from PATH"
    return $?
  fi

  _host_warn "python3 was not found. Host-side smoke tests will be skipped."
  return 1
}
