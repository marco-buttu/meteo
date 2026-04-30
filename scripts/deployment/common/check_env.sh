#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ENV_FILE="${ENV_FILE:-${PROJECT_ROOT}/.env}"
SKIP_EXTERNAL_PATHS=0

usage() {
  cat <<'USAGE'
Usage: scripts/deployment/common/check_env.sh [--skip-external-paths]

Validate the application environment file and the paths required by the app.

Options:
  --skip-external-paths  Do not require DATA_DIR, ATM_SER_PATH, or OCTAVE_BIN to exist.
                         Useful during image builds where external volumes are not mounted yet.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-external-paths)
      SKIP_EXTERNAL_PATHS=1
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

require_var() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    fail "Required environment variable is missing or empty: ${name}"
  fi
  ok "${name} is set"
}

require_int() {
  local name="$1"
  require_var "$name"
  if ! [[ "${!name}" =~ ^[0-9]+$ ]]; then
    fail "Environment variable ${name} must be a non-negative integer: ${!name}"
  fi
  ok "${name} is a valid integer"
}

resolve_path() {
  local raw_path="$1"
  local path
  local dir
  local base

  if [[ "$raw_path" == /* ]]; then
    path="$raw_path"
  elif [[ "$raw_path" == ~* ]]; then
    path="${raw_path/#\~/$HOME}"
  else
    path="${PROJECT_ROOT}/${raw_path}"
  fi

  dir="$(dirname "$path")"
  base="$(basename "$path")"

  if [[ -d "$dir" ]]; then
    printf '%s/%s\n' "$(cd "$dir" && pwd -P)" "$base"
  else
    printf '%s\n' "$path"
  fi
}

check_writable_dir() {
  local label="$1"
  local raw_path="$2"
  local resolved
  resolved="$(resolve_path "$raw_path")"

  mkdir -p "$resolved" || fail "Cannot create ${label}: ${resolved}"
  [[ -d "$resolved" ]] || fail "${label} is not a directory: ${resolved}"
  [[ -w "$resolved" ]] || fail "${label} is not writable: ${resolved}"
  ok "${label} is writable: ${resolved}"
}

check_readable_dir() {
  local label="$1"
  local raw_path="$2"
  local resolved
  resolved="$(resolve_path "$raw_path")"

  [[ -d "$resolved" ]] || fail "${label} does not exist or is not a directory: ${resolved}"
  [[ -r "$resolved" ]] || fail "${label} is not readable: ${resolved}"
  ok "${label} is readable: ${resolved}"
}

check_readable_file() {
  local label="$1"
  local raw_path="$2"
  local resolved
  resolved="$(resolve_path "$raw_path")"

  [[ -f "$resolved" ]] || fail "${label} does not exist or is not a file: ${resolved}"
  [[ -r "$resolved" ]] || fail "${label} is not readable: ${resolved}"
  ok "${label} is readable: ${resolved}"
}

[[ -f "$ENV_FILE" ]] || fail "Environment file not found: ${ENV_FILE}"
ok "Environment file exists: ${ENV_FILE}"

set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

require_var REDIS_URL
require_var RQ_QUEUE_NAME
require_var JOB_STORAGE_DIR
require_var PLOT_STORAGE_DIR
require_var DATA_DIR
require_var ATM_SER_PATH
require_var OCTAVE_BIN
require_int OCTAVE_TIMEOUT_SECONDS
require_var FLASK_HOST
require_int FLASK_PORT
require_var FLASK_DEBUG

check_writable_dir "JOB_STORAGE_DIR" "$JOB_STORAGE_DIR"
check_writable_dir "PLOT_STORAGE_DIR" "$PLOT_STORAGE_DIR"

if [[ "$SKIP_EXTERNAL_PATHS" -eq 1 ]]; then
  ok "External path checks skipped"
else
  check_readable_dir "DATA_DIR" "$DATA_DIR"
  check_readable_file "ATM_SER_PATH" "$ATM_SER_PATH"
  command -v "$OCTAVE_BIN" >/dev/null 2>&1 || fail "OCTAVE_BIN not found in PATH: ${OCTAVE_BIN}"
  ok "OCTAVE_BIN is available: ${OCTAVE_BIN}"
fi

ok "Environment validation completed"
