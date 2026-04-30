#!/usr/bin/env bash

set -euo pipefail

REMOVE_VAGRANT=0
ASSUME_YES=0
DRY_RUN=0

usage() {
    cat <<'USAGE'
Usage: ./clean_pycache.sh [options]

Options:
  --vagrant    Destroy the Vagrant VM associated with this project and remove .vagrant.
  --yes        Do not ask for confirmation when using --vagrant.
  --dry-run    Show what would be removed without removing anything.
  --help       Show this help message.

By default, the script removes these directories recursively from the current directory:
  .venv
  runtime_data
  __pycache__

With --vagrant, it also runs vagrant destroy -f and removes .vagrant.
USAGE
}

run_command() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        printf '[dry-run] '
        printf '%q ' "$@"
        printf '\n'
    else
        "$@"
    fi
}

confirm_vagrant_destroy() {
    if [[ "$ASSUME_YES" -eq 1 ]]; then
        return 0
    fi

    echo "This will destroy the Vagrant VM associated with this project."
    echo "Current directory: $(pwd)"
    read -r -p "Continue? Type 'yes' to proceed: " answer

    if [[ "$answer" != "yes" ]]; then
        echo "Vagrant cleanup cancelled."
        exit 1
    fi
}

remove_directories_by_name() {
    local directory_name="$1"
    local found=0

    while IFS= read -r -d '' dir; do
        echo "Removing: $dir"
        run_command rm -rf "$dir"
        found=1
    done < <(find . -type d -name "$directory_name" -prune -print0)

    if [[ "$found" -eq 0 ]]; then
        echo "No $directory_name directories to remove."
    fi
}

cleanup_vagrant() {
    if [[ ! -f "Vagrantfile" ]]; then
        echo "No Vagrantfile found in the current directory. Skipping Vagrant cleanup."
        return 0
    fi

    if ! command -v vagrant >/dev/null 2>&1; then
        echo "Vagrant is not installed or not available in PATH. Skipping Vagrant cleanup."
        return 0
    fi

    confirm_vagrant_destroy

    echo "Destroying Vagrant VM for this project, if present..."
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "[dry-run] HOST_DATA_DIR=${HOST_DATA_DIR:-/tmp} vagrant destroy -f"
    else
        HOST_DATA_DIR="${HOST_DATA_DIR:-/tmp}" vagrant destroy -f || true
    fi

    if [[ -d ".vagrant" ]]; then
        echo "Removing: ./.vagrant"
        run_command rm -rf .vagrant
    else
        echo "No .vagrant directory to remove."
    fi
}

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --vagrant)
            REMOVE_VAGRANT=1
            shift
            ;;
        --yes)
            ASSUME_YES=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [[ "$REMOVE_VAGRANT" -eq 1 ]]; then
    cleanup_vagrant
fi

remove_directories_by_name ".venv"
remove_directories_by_name "runtime_data"
remove_directories_by_name "__pycache__"
