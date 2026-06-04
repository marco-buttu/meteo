#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/host/vagrant/install_dependencies_debian.sh [packages...]

Install host-side dependencies required to orchestrate VirtualBox/Vagrant
deployments on Debian/Ubuntu/Linux Mint systems.

Supported logical package names:
  python3
  python3-pip
  vagrant
  virtualbox

Notes:
  - This script installs host orchestration dependencies only.
  - It does not install target/app dependencies such as Redis or Octave.
  - Python module dependencies for smoke tests, such as requests, are installed
    by check_dependencies.sh into the Python interpreter used for smoke tests.

Options:
  -h, --help  Show this help message.
USAGE
}

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

ok() {
  echo "[OK] $*"
}

if [[ $# -eq 0 ]]; then
  usage >&2
  exit 2
fi

for arg in "$@"; do
  case "$arg" in
    -h|--help)
      usage
      exit 0
      ;;
  esac
done

command -v apt-get >/dev/null 2>&1 || fail "apt-get was not found. Automatic host dependency installation is supported only on Debian/Ubuntu/Linux Mint."
command -v sudo >/dev/null 2>&1 || fail "sudo was not found. Install the missing host dependencies manually."

apt_packages=()
need_hashicorp_repo=0

add_apt_package() {
  local package="$1"
  for existing in "${apt_packages[@]:-}"; do
    [[ "$existing" == "$package" ]] && return 0
  done
  apt_packages+=("$package")
}

for dep in "$@"; do
  case "$dep" in
    python3)
      add_apt_package python3
      ;;
    python3-pip)
      add_apt_package python3-pip
      ;;
    vagrant)
      add_apt_package vagrant
      need_hashicorp_repo=1
      ;;
    virtualbox|VBoxManage)
      add_apt_package virtualbox
      ;;
    *)
      fail "Unsupported host dependency: $dep"
      ;;
  esac
done

if [[ "$need_hashicorp_repo" == "1" ]]; then
  ok "Preparing HashiCorp APT repository for Vagrant"
  sudo apt-get update
  sudo apt-get install -y wget gpg lsb-release ca-certificates

  sudo install -d -m 0755 /usr/share/keyrings
  if [[ ! -f /usr/share/keyrings/hashicorp-archive-keyring.gpg ]]; then
    wget -O- https://apt.releases.hashicorp.com/gpg | \
      sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  fi

  ubuntu_codename=""
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    ubuntu_codename="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
  fi

  [[ -n "$ubuntu_codename" ]] || ubuntu_codename="$(lsb_release -cs)"
  [[ -n "$ubuntu_codename" ]] || fail "Could not detect Ubuntu/Debian codename for HashiCorp repository."

  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com ${ubuntu_codename} main" | \
    sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
fi

ok "Installing host dependencies: ${apt_packages[*]}"
sudo apt-get update
sudo apt-get install -y "${apt_packages[@]}"
ok "Host dependency installation completed"
