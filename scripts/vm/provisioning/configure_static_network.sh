#!/usr/bin/env bash
set -euo pipefail

VM_STATIC_IP="${VM_STATIC_IP:-192.168.140.45}"
VM_STATIC_NETMASK="${VM_STATIC_NETMASK:-255.255.255.0}"
VM_STATIC_GATEWAY="${VM_STATIC_GATEWAY:-192.168.140.1}"
VM_STATIC_DNS="${VM_STATIC_DNS:-192.168.110.11}"
NETPLAN_FILE="${NETPLAN_FILE:-/etc/netplan/60-meteo-static-network.yaml}"

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

ok() {
  echo "[OK] $*"
}

is_valid_ipv4() {
  local ip="$1"
  local octet
  local -a octets

  [[ "${ip}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1

  IFS='.' read -r -a octets <<< "${ip}"
  for octet in "${octets[@]}"; do
    [[ "${octet}" =~ ^[0-9]+$ ]] || return 1
    ((octet >= 0 && octet <= 255)) || return 1
  done
}

netmask_to_prefix() {
  local netmask="$1"
  local -a octets
  local octet
  local binary=""
  local prefix=0

  is_valid_ipv4 "${netmask}" || return 1

  IFS='.' read -r -a octets <<< "${netmask}"
  for octet in "${octets[@]}"; do
    case "${octet}" in
      255) binary+="11111111" ;;
      254) binary+="11111110" ;;
      252) binary+="11111100" ;;
      248) binary+="11111000" ;;
      240) binary+="11110000" ;;
      224) binary+="11100000" ;;
      192) binary+="11000000" ;;
      128) binary+="10000000" ;;
      0) binary+="00000000" ;;
      *) return 1 ;;
    esac
  done

  [[ "${binary}" =~ ^1*0*$ ]] || return 1
  prefix="${binary%%0*}"
  printf '%s\n' "${#prefix}"
}

find_static_interface() {
  local interface=""

  interface="$(ip -o -4 addr show | awk -v ip="${VM_STATIC_IP}" '$0 ~ ip {print $2; exit}')"
  if [[ -n "${interface}" ]]; then
    printf '%s\n' "${interface}"
    return 0
  fi

  interface="$(ip -o link show | awk -F': ' '$2 != "lo" {print $2}' | while read -r candidate; do
    if ! ip route show default | awk '{print $5}' | grep -qx "${candidate}"; then
      printf '%s\n' "${candidate}"
      break
    fi
  done)"

  if [[ -n "${interface}" ]]; then
    printf '%s\n' "${interface}"
    return 0
  fi

  ip -o link show | awk -F': ' '$2 != "lo" {print $2; exit}'
}

[[ "${EUID}" -eq 0 ]] || fail "This script must run as root."

is_valid_ipv4 "${VM_STATIC_IP}" || fail "Invalid VM_STATIC_IP: ${VM_STATIC_IP}"
is_valid_ipv4 "${VM_STATIC_NETMASK}" || fail "Invalid VM_STATIC_NETMASK: ${VM_STATIC_NETMASK}"
is_valid_ipv4 "${VM_STATIC_GATEWAY}" || fail "Invalid VM_STATIC_GATEWAY: ${VM_STATIC_GATEWAY}"
is_valid_ipv4 "${VM_STATIC_DNS}" || fail "Invalid VM_STATIC_DNS: ${VM_STATIC_DNS}"

PREFIX="$(netmask_to_prefix "${VM_STATIC_NETMASK}")" || fail "Invalid netmask: ${VM_STATIC_NETMASK}"
INTERFACE="$(find_static_interface)"

[[ -n "${INTERFACE}" ]] || fail "Unable to determine the VM static network interface."

ok "Writing static network configuration for interface ${INTERFACE}"
cat > "${NETPLAN_FILE}" <<EOF_NETPLAN
network:
  version: 2
  ethernets:
    ${INTERFACE}:
      dhcp4: false
      addresses:
        - ${VM_STATIC_IP}/${PREFIX}
      routes:
        - to: default
          via: ${VM_STATIC_GATEWAY}
      nameservers:
        addresses:
          - ${VM_STATIC_DNS}
EOF_NETPLAN

chmod 600 "${NETPLAN_FILE}"

ok "Applying static network configuration"
netplan apply

ok "Static VM network configured: ${VM_STATIC_IP}/${PREFIX}, gateway ${VM_STATIC_GATEWAY}, DNS ${VM_STATIC_DNS}"
