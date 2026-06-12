# System Administration Guide

This guide is for system administrators who need to install and operate the
application. It treats the application as a black box.

There are two installation scenarios:

1. local machine installation;
2. VirtualBox / Vagrant installation.

The main entrypoint is:

```bash
./admin.sh
```

## Deployment menu

The interactive menu is organized by installation scenario:

```text
Meteo application administration
================================

Local machine installation
--------------------------
  1) Deploy locally

VirtualBox / Vagrant installation
---------------------------------
  2) Provision host for shared VM management
  3) Unprovision host
  4) Deploy to VirtualBox VM
  5) Reinstall app inside existing VM
  6) Fresh VirtualBox VM deployment
  7) Start existing VM
  8) Stop existing VM

Other
-----
  0) Exit
```

The host provisioning options are inside the VirtualBox / Vagrant section
because they are only needed for VM-based deployments. They are not part of a
local machine installation.

## Local machine installation

Use local installation when the application must run directly on the current
Debian, Ubuntu, or Linux Mint machine.

Interactive mode:

```bash
./admin.sh
```

Then select:

```text
1) Deploy locally
```

Direct mode:

```bash
./admin.sh local
```

The local deployment installs the required system packages, prepares the
application, installs the `systemd` services, enables them at boot, and starts
them.

The installed application services are:

```text
meteo-app.service
meteo-worker.service
```

The deployment also uses the system Redis service:

```text
redis-server
```

After a successful local deployment, the API is available when the machine is
running and the services are active.

### Useful local service commands

Check service status:

```bash
systemctl status meteo-app
systemctl status meteo-worker
systemctl status redis-server
```

Restart the application services:

```bash
sudo systemctl restart meteo-app meteo-worker
```

Stop the application services:

```bash
sudo systemctl stop meteo-app meteo-worker
```

Show recent logs:

```bash
journalctl -u meteo-app -n 100 --no-pager
journalctl -u meteo-worker -n 100 --no-pager
```

Follow logs:

```bash
journalctl -u meteo-app -f
journalctl -u meteo-worker -f
```

## VirtualBox / Vagrant installation

Use the VirtualBox / Vagrant installation when the application must run inside a
VirtualBox VM managed through Vagrant.

Required host tools:

- VirtualBox;
- Vagrant;
- Python 3 for host-side smoke tests.

### Provision host for shared VM management

Use this option on a shared host where the VM should be owned and managed by a
single technical Linux user.

Interactive mode:

```bash
./admin.sh
```

Then select:

```text
2) Provision host for shared VM management
```

Direct mode:

```bash
sudo ./admin.sh host-provision
```

This option prepares the host for VM management. It can configure the technical
Vagrant user, shared permissions, local deployment state, and optional VM
autostart at host boot.

The provisioning prompt uses this shared directory as the default:

```text
/wff
```

Run this option with `sudo`.

### Unprovision host

Interactive mode:

```bash
./admin.sh
```

Then select:

```text
3) Unprovision host
```

Direct mode:

```bash
sudo ./admin.sh host-unprovision
```

This removes host provisioning artifacts, including the host-side VM autostart
service and the local Vagrant run-user configuration. The technical user is kept
by default.

Run this option with `sudo`.

### Deploy to VirtualBox VM

Interactive mode:

```bash
./admin.sh
```

Then select:

```text
4) Deploy to VirtualBox VM
```

Direct mode:

```bash
./admin.sh virtualbox
```

The deployment creates or starts the VM, configures it, installs the application
inside the VM, enables the application services inside the VM, starts them, and
runs host-side smoke tests unless disabled.

The deployment asks for the host data directory. Example:

```text
/home/meteo/data
```

The selected host data directory is mounted inside the VM. By default, the guest
mount point is:

```text
/dati
```

In NAT mode, the API is exposed through host port forwarding. The default URL is:

```text
http://192.168.140.45:5000
```

### Reinstall app inside existing VM

Use this when the VM already exists and only the application must be reinstalled
from the current checkout.

Interactive mode:

```bash
./admin.sh
```

Then select:

```text
5) Reinstall app inside existing VM
```

Direct mode:

```bash
./admin.sh vm-reinstall
```

This keeps the VM and reinstalls the application inside it.

### Fresh VirtualBox VM deployment

Use this when the existing Vagrant VM must be destroyed and recreated from
scratch.

Interactive mode:

```bash
./admin.sh
```

Then select:

```text
6) Fresh VirtualBox VM deployment
```

Direct mode:

```bash
./admin.sh vm-fresh
```

This is destructive for the Vagrant VM associated with the current project. The
script asks for confirmation before destroying the VM.

### Start existing VM

Interactive mode:

```bash
./admin.sh
```

Then select:

```text
7) Start existing VM
```

Direct mode:

```bash
./admin.sh vm-start
```

This starts the existing VM without provisioning it again. When the VM is up,
the services inside the VM are expected to start automatically, making the API
available again.

### Stop existing VM

Interactive mode:

```bash
./admin.sh
```

Then select:

```text
8) Stop existing VM
```

Direct mode:

```bash
./admin.sh vm-stop
```

This shuts down the existing VM.

## VM network configuration

The VirtualBox deployment supports NAT and static network modes.

Common variables:

```text
HOST_DATA_DIR
GUEST_DATA_DIR
HOST_APP_PORT
HOST_APP_IP
VM_NETWORK_MODE
VM_BRIDGE_INTERFACE
VM_STATIC_IP
VM_STATIC_NETMASK
VM_STATIC_GATEWAY
VM_STATIC_DNS
RUN_SMOKE_TESTS
```

Example NAT deployment with a custom host port:

```bash
HOST_DATA_DIR=/home/meteo/data HOST_APP_PORT=5001 ./admin.sh virtualbox
```

The API is then reachable at:

```text
http://192.168.140.45:5001
```

Example static network deployment:

```bash
HOST_DATA_DIR=/home/meteo/data \
VM_NETWORK_MODE=static \
VM_STATIC_IP=192.168.140.45 \
./admin.sh virtualbox
```

## Smoke tests

VM deployment and VM app reinstall run host-side smoke tests by default.

Disable them with:

```bash
RUN_SMOKE_TESTS=0 ./admin.sh virtualbox
RUN_SMOKE_TESTS=0 ./admin.sh vm-reinstall
```

Run smoke tests manually against a reachable API:

```bash
BASE_URL=http://192.168.140.45:5000 python scripts/smoke_tests.py
```

## Local uninstall

For a local machine test deployment, the repository includes this uninstall
script:

```bash
sudo scripts/app/deployment/uninstall_native_linux.sh --yes
```

For disposable test machines only, runtime data and packages installed by the
local deployment can also be removed:

```bash
sudo scripts/app/deployment/uninstall_native_linux.sh --yes --remove-runtime-data --remove-system-deps
```

Do not remove Redis data on a machine where Redis may be used by other
applications.

## Troubleshooting

### The API is not reachable after local installation

Check:

```bash
systemctl status meteo-app
systemctl status meteo-worker
systemctl status redis-server
journalctl -u meteo-app -n 100 --no-pager
```

### The API is not reachable after VM installation

Check that the VM is running:

```bash
./admin.sh vm-start
```

Then verify the configured URL and port. In NAT mode, check `HOST_APP_PORT`. In
static network mode, check `VM_STATIC_IP`.

### Jobs remain queued

The worker service is probably not running or cannot reach Redis. Check the
worker service logs on the machine where the application is installed.

### Legacy operations fail

Legacy operations require Octave and the legacy backend files and data. Check
that the configured data directory is mounted or available to the installed
application.
