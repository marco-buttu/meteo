# Native Linux deployment with systemd

This document explains how to deploy the Meteo application directly on a Linux
host without Docker.

The deployment uses:

- the system Redis service
- one `systemd` service for the Flask API
- one `systemd` service for the RQ worker
- the project `.env` file for runtime configuration
- the shared `scripts/deployment/local/setup_app.sh` script for Python application setup

This procedure is intended for Debian, Ubuntu, Linux Mint, and closely related
APT-based distributions.

---

## Files involved

```text
scripts/deployment/local/install_system_deps_debian.sh
scripts/deployment/local/setup_app.sh
scripts/deployment/local/install_systemd_services.sh
scripts/deployment/local/uninstall_native_linux.sh
systemd/meteo-app.service
systemd/meteo-worker.service
docs/deployment-native-linux.md
```

`install_system_deps_debian.sh` installs only system packages.

`setup_app.sh` creates or updates the Python virtual environment, installs
Python dependencies, validates `.env`, and creates runtime directories.

`install_systemd_services.sh` renders and installs the `systemd` units using the
real project path, user, group, virtualenv Python interpreter, and `.env` path.

`uninstall_native_linux.sh` removes the native Linux deployment so that repeated
deployment tests can start from a clean state.

---

## 1. Install system dependencies

From the project root:

```bash
sudo scripts/deployment/local/install_system_deps_debian.sh
```

The script installs:

```text
python3
python3-venv
python3-pip
redis-server
octave
```

It also records which required packages were already installed before the
deployment script ran. The uninstall script uses this state file to avoid
removing packages that belonged to the machine before the test.

It also enables and starts the system Redis service when `systemctl` is
available.

To install Redis without enabling or starting it:

```bash
sudo scripts/deployment/local/install_system_deps_debian.sh --no-redis-enable
```

---

## 2. Configure `.env`

Edit `.env` before installing the services.

Example:

```env
REDIS_URL=redis://127.0.0.1:6379/0
RQ_QUEUE_NAME=default

JOB_STORAGE_DIR=./runtime_data/jobs
PLOT_STORAGE_DIR=./runtime_data/plots

OCTAVE_TIMEOUT_SECONDS=30
OCTAVE_BIN=octave-cli
ATM_SER_PATH=./octave/scripts/atm_ser
DATA_DIR=../data

FLASK_HOST=127.0.0.1
FLASK_PORT=5000
FLASK_DEBUG=0
```

For a `systemd` deployment, use `FLASK_DEBUG=0`. The debug reloader is useful
during local development, but it should not be used for a managed service.

Relative paths are resolved by the Python application from the project root.
The installed services also set `WorkingDirectory` to the project root, so the
same `.env` works consistently for manual runs and for `systemd` runs.

Make sure these paths exist and are readable or writable as appropriate:

- `DATA_DIR`
- `ATM_SER_PATH`
- `JOB_STORAGE_DIR`
- `PLOT_STORAGE_DIR`

If data are stored outside the repository, mount or place them somewhere on the
host and set `DATA_DIR` accordingly. For example:

```env
DATA_DIR=/dati/meteo
```

---

## 3. Prepare the Python application

Run the shared application setup script:

```bash
scripts/deployment/local/setup_app.sh
```

This creates `.venv`, installs the Python dependencies from `requirements.txt`,
validates `.env`, and creates runtime directories.

If the external data directory is not available yet, you can skip external path
checks temporarily:

```bash
scripts/deployment/local/setup_app.sh --skip-external-paths
```

Do not use this skip option for the final deployment check.

---

## 4. Preview the generated systemd units

Before installing the services, check what will be generated:

```bash
sudo scripts/deployment/local/install_systemd_services.sh --dry-run
```

The output should contain the real absolute paths for:

- `WorkingDirectory`
- `EnvironmentFile`
- `ExecStart`

It should also show the Linux user and group that will run the services.

---

## 5. Install the systemd services

Run:

```bash
sudo scripts/deployment/local/install_systemd_services.sh
```

By default, this installs the services and enables them at boot, but does not
start them immediately.

To install and start them immediately:

```bash
sudo scripts/deployment/local/install_systemd_services.sh --start
```

To install them without enabling them at boot:

```bash
sudo scripts/deployment/local/install_systemd_services.sh --no-enable
```

To choose a specific runtime user and group:

```bash
sudo scripts/deployment/local/install_systemd_services.sh --user meteo --group meteo
```

---

## 6. Start, stop, restart, and inspect services

Start both services:

```bash
sudo systemctl start meteo-app meteo-worker
```

Stop both services:

```bash
sudo systemctl stop meteo-app meteo-worker
```

Restart both services:

```bash
sudo systemctl restart meteo-app meteo-worker
```

Check status:

```bash
systemctl status meteo-app
systemctl status meteo-worker
```

Show logs:

```bash
journalctl -u meteo-app -f
journalctl -u meteo-worker -f
```

Show recent logs without following:

```bash
journalctl -u meteo-app -n 100 --no-pager
journalctl -u meteo-worker -n 100 --no-pager
```

---

## 7. Verify Redis

Check the system Redis service:

```bash
systemctl status redis-server
```

Check that Redis is listening on the expected local port:

```bash
redis-cli ping
```

Expected output:

```text
PONG
```

---

## 8. Run smoke tests

After Redis, the API service, and the worker are running, execute:

```bash
source .venv/bin/activate
inv smoke
```

or directly:

```bash
.venv/bin/python scripts/smoke_tests.py
```

The smoke tests verify the main job flow through the running API and worker.

---

## 9. Update an existing deployment

From the project root:

```bash
git pull
scripts/deployment/local/setup_app.sh
sudo systemctl restart meteo-app meteo-worker
```

If the service templates changed, reinstall them:

```bash
sudo scripts/deployment/local/install_systemd_services.sh --start
```

---

## 10. Uninstall the native Linux deployment

To remove the installed `systemd` services and the local virtual environment:

```bash
sudo scripts/deployment/local/uninstall_native_linux.sh --yes
```

For a repeated test on a disposable VM, remove also the runtime job and plot
directories created from `.env`:

```bash
sudo scripts/deployment/local/uninstall_native_linux.sh --yes --remove-runtime-data
```

To get as close as possible to the initial state of a fresh test VM, also remove
the system packages that were installed by `install_system_deps_debian.sh` and
were not already present before that script ran:

```bash
sudo scripts/deployment/local/uninstall_native_linux.sh --yes --remove-runtime-data --remove-system-deps
```

Preview the uninstall without changing the system:

```bash
sudo scripts/deployment/local/uninstall_native_linux.sh --dry-run --remove-runtime-data --remove-system-deps
```

The uninstall script removes packages only when a deployment state file exists:

```text
.deployment/native-linux-state.env
```

That file is written by `install_system_deps_debian.sh` before installing
packages. This prevents the uninstall script from removing packages that were
already installed on the machine before the Meteo deployment test.

Redis data and configuration leftovers are not removed by default. On a
disposable VM only, you can add:

```bash
--remove-redis-data
```

Do not use `--remove-redis-data` on a machine where Redis may be used by other
applications.

---

## Troubleshooting

### The app service fails immediately

Check the logs:

```bash
journalctl -u meteo-app -n 100 --no-pager
```

Common causes:

- `.venv` was not created
- `.env` is missing
- `DATA_DIR` is wrong
- `ATM_SER_PATH` is wrong
- `FLASK_PORT` is already in use

### The worker service fails immediately

Check the logs:

```bash
journalctl -u meteo-worker -n 100 --no-pager
```

Common causes:

- Redis is not running
- `REDIS_URL` is wrong
- `.venv` was not created
- `.env` is missing
- the worker user cannot read the project files

### Jobs remain queued

The worker is probably not running or cannot connect to Redis.

Check:

```bash
systemctl status meteo-worker
journalctl -u meteo-worker -n 100 --no-pager
redis-cli ping
```

### Legacy jobs fail with missing files

Check:

```bash
grep -E '^(DATA_DIR|ATM_SER_PATH|OCTAVE_BIN)=' .env
scripts/deployment/common/check_env.sh
```

Make sure the service user can read `DATA_DIR` and `ATM_SER_PATH`.

### Changes to `.env` do not take effect

Restart both services after editing `.env`:

```bash
sudo systemctl restart meteo-app meteo-worker
```
