#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
INSTALLER="${PROJECT_ROOT}/scripts/deployment/host/install_dependencies_debian.sh"
HOST_ENV_FILE="${PROJECT_ROOT}/.deployment/host.env"
REQUIRE_VAGRANT=0
REQUIRE_VIRTUALBOX=0
REQUIRE_SMOKE_PYTHON=0
ASSUME_YES="${INSTALL_HOST_DEPS:-prompt}"
RUN_SMOKE_TESTS="${RUN_SMOKE_TESTS:-1}"
SMOKE_TEST_PYTHON="${SMOKE_TEST_PYTHON:-}"
HOST_SMOKE_VENV="${HOST_SMOKE_VENV:-${PROJECT_ROOT}/.deployment/host-smoke-venv}"

usage() {
  cat <<'USAGE'
Usage: scripts/deployment/host/check_dependencies.sh [options]

Check host-side dependencies required to orchestrate deployment tasks.

Options:
  --virtualbox       Require Vagrant and VirtualBox/VBoxManage.
  --smoke-tests      Require a Python interpreter usable for host-side smoke tests.
  --no-smoke-tests   Do not check smoke-test Python dependencies.
  -h, --help         Show this help message.

Environment variables:
  INSTALL_HOST_DEPS  Controls automatic installation of missing host packages.
                     Values:
                       1     install missing apt packages without prompting
                       0     do not install; fail if something is missing
                       unset prompt interactively

  RUN_SMOKE_TESTS    If set to 0/false/no/off, smoke-test Python checks are skipped.
  SMOKE_TEST_PYTHON  Optional Python interpreter to use for smoke tests.
  HOST_SMOKE_VENV    Dedicated virtualenv used when system Python lacks requests.
                     Default: .deployment/host-smoke-venv

This script checks host orchestration dependencies only. It does not install
application runtime dependencies inside the target machine.
USAGE
}

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

ok() {
  echo "[OK] $*" >&2
}

is_false() {
  case "${1,,}" in
    0|false|no|off) return 0 ;;
    *) return 1 ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --virtualbox)
      REQUIRE_VAGRANT=1
      REQUIRE_VIRTUALBOX=1
      shift
      ;;
    --smoke-tests)
      REQUIRE_SMOKE_PYTHON=1
      shift
      ;;
    --no-smoke-tests)
      REQUIRE_SMOKE_PYTHON=0
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

if is_false "$RUN_SMOKE_TESTS"; then
  REQUIRE_SMOKE_PYTHON=0
fi

missing=()

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

add_missing() {
  local dep="$1"
  for existing in "${missing[@]:-}"; do
    [[ "$existing" == "$dep" ]] && return 0
  done
  missing+=("$dep")
}

check_basic_dependencies() {
  if [[ "$REQUIRE_VAGRANT" == "1" ]] && ! command_exists vagrant; then
    add_missing vagrant
  fi

  if [[ "$REQUIRE_VIRTUALBOX" == "1" ]] && ! command_exists VBoxManage; then
    add_missing virtualbox
  fi

  if [[ "$REQUIRE_SMOKE_PYTHON" == "1" ]] && ! command_exists python3 && [[ -z "$SMOKE_TEST_PYTHON" ]]; then
    add_missing python3
  fi
}

install_missing_packages_if_requested() {
  [[ "${#missing[@]}" -eq 0 ]] && return 0

  echo "Missing host dependencies:"
  for dep in "${missing[@]}"; do
    echo "- $dep"
  done

  case "$ASSUME_YES" in
    1|yes|YES|true|TRUE)
      bash "$INSTALLER" "${missing[@]}"
      ;;
    0|no|NO|false|FALSE)
      fail "Missing host dependencies. Install them manually or set INSTALL_HOST_DEPS=1 to allow automatic installation."
      ;;
    prompt)
      if [[ -t 0 ]]; then
        read -r -p "Install missing host dependencies now? [y/N]: " answer
        case "$answer" in
          y|Y|yes|YES)
            bash "$INSTALLER" "${missing[@]}"
            ;;
          *)
            fail "Missing host dependencies. Deployment stopped."
            ;;
        esac
      else
        fail "Missing host dependencies in non-interactive mode. Set INSTALL_HOST_DEPS=1 to install them automatically."
      fi
      ;;
    *)
      fail "Invalid INSTALL_HOST_DEPS value: $ASSUME_YES"
      ;;
  esac

  missing=()
}

resolve_python_command() {
  local candidate="$1"
  if [[ -z "$candidate" ]]; then
    return 1
  fi
  if [[ -x "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi
  if command_exists "$candidate"; then
    command -v "$candidate"
    return 0
  fi
  return 1
}

resolve_smoke_python() {
  if [[ -n "$SMOKE_TEST_PYTHON" ]]; then
    resolve_python_command "$SMOKE_TEST_PYTHON" || fail "SMOKE_TEST_PYTHON was not found or is not executable: $SMOKE_TEST_PYTHON"
    return 0
  fi

  if [[ -n "${VIRTUAL_ENV:-}" && -x "${VIRTUAL_ENV}/bin/python" ]]; then
    printf '%s\n' "${VIRTUAL_ENV}/bin/python"
    return 0
  fi

  if [[ -x "${PROJECT_ROOT}/.venv/bin/python" ]]; then
    printf '%s\n' "${PROJECT_ROOT}/.venv/bin/python"
    return 0
  fi

  command_exists python3 || fail "python3 was not found after dependency installation."
  command -v python3
}

python_can_import_requests() {
  local python_bin="$1"
  "$python_bin" - <<'PY' >/dev/null 2>&1
import requests
PY
}

python_has_pip() {
  local python_bin="$1"
  "$python_bin" -m pip --version >/dev/null 2>&1
}

is_system_python() {
  local python_bin="$1"
  local resolved
  resolved="$(readlink -f "$python_bin" 2>/dev/null || printf '%s\n' "$python_bin")"
  case "$resolved" in
    /usr/bin/python3*|/bin/python3*) return 0 ;;
    *) return 1 ;;
  esac
}

create_host_smoke_venv() {
  command_exists python3 || fail "python3 is required to create the host smoke-test virtual environment."
  ok "Creating host smoke-test virtual environment: $HOST_SMOKE_VENV"
  python3 -m venv "$HOST_SMOKE_VENV" || fail "Failed to create host smoke-test virtual environment. Install python3-venv, or set SMOKE_TEST_PYTHON to an interpreter with pip."
  "$HOST_SMOKE_VENV/bin/python" -m pip install --upgrade pip >&2
  "$HOST_SMOKE_VENV/bin/python" -m pip install requests >&2
  printf '%s\n' "$HOST_SMOKE_VENV/bin/python"
}

ensure_requests_for_smoke_python() {
  local python_bin="$1"

  if python_can_import_requests "$python_bin"; then
    printf '%s\n' "$python_bin"
    return 0
  fi

  if is_system_python "$python_bin"; then
    ok "System Python cannot import requests; using a dedicated smoke-test virtual environment instead."
    create_host_smoke_venv
    return 0
  fi

  python_has_pip "$python_bin" || fail "pip is not available for the smoke-test Python interpreter: $python_bin"

  ok "Installing requests into the smoke-test Python environment: $python_bin"
  "$python_bin" -m pip install requests >&2

  python_can_import_requests "$python_bin" || fail "requests is still not importable with: $python_bin"
  printf '%s\n' "$python_bin"
}

write_host_env() {
  local python_bin="$1"
  mkdir -p "$(dirname "$HOST_ENV_FILE")"
  cat > "$HOST_ENV_FILE" <<EOF_ENV
SMOKE_TEST_PYTHON=$python_bin
EOF_ENV
  ok "Saved host deployment configuration: $HOST_ENV_FILE"
}

check_basic_dependencies
install_missing_packages_if_requested
check_basic_dependencies
[[ "${#missing[@]}" -eq 0 ]] || fail "Some host dependencies are still missing after installation: ${missing[*]}"

if [[ "$REQUIRE_SMOKE_PYTHON" == "1" ]]; then
  smoke_python="$(resolve_smoke_python)"
  smoke_python="$(ensure_requests_for_smoke_python "$smoke_python")"
  write_host_env "$smoke_python"
  ok "Smoke-test Python: $smoke_python"
fi

ok "Host dependency check completed"
