from __future__ import annotations

import socket
import subprocess
from pathlib import Path

from invoke import task


PROJECT_ROOT = Path(__file__).resolve().parent
SCRIPTS_DIR = PROJECT_ROOT / 'scripts'


def _is_redis_running(host: str = '127.0.0.1', port: int = 6379) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex((host, port)) == 0


def _run_script(c, script_name: str, args: str = '') -> None:
    script_path = SCRIPTS_DIR / script_name
    c.run(f'bash {script_path} {args}'.strip(), pty=True)


@task
def install(c) -> None:
    """Install project dependencies."""
    _run_script(c, 'setup_app.sh', '--skip-env-check')


@task
def setup(c) -> None:
    """Prepare local environment without reinstalling dependencies."""
    _run_script(c, 'setup_app.sh', '--skip-install')


@task
def check(c) -> None:
    """Run quick project checks."""
    _run_script(c, 'check_env.sh')

    checks = {
        'run.py exists': (PROJECT_ROOT / 'run.py').exists(),
        'worker.py exists': (PROJECT_ROOT / 'worker.py').exists(),
        '.env exists': (PROJECT_ROOT / '.env').exists(),
        'app package exists': (PROJECT_ROOT / 'app').is_dir(),
        'redis running': _is_redis_running(),
    }

    for label, ok in checks.items():
        print(f'{label}: {"OK" if ok else "FAIL"}')


@task
def redis(c) -> None:
    """Start Redis only if not already running."""
    if _is_redis_running():
        print('Redis already running on 127.0.0.1:6379')
        return

    print('Starting Redis...')
    c.run('redis-server', pty=True)


@task(pre=[setup])
def app(c) -> None:
    """Start Flask app."""
    c.run('python run.py', pty=True)


@task(pre=[setup])
def worker(c) -> None:
    """Start RQ worker."""
    c.run('python worker.py', pty=True)


@task
def smoke(c) -> None:
    """Run end-to-end smoke tests (requires app, worker, redis already running)."""
    print('Running smoke tests...')
    c.run('python scripts/smoke_tests.py', pty=True)


@task(pre=[setup])
def up(c) -> None:
    """Start full system (Redis if needed + app + worker)."""
    if not _is_redis_running():
        print('Redis not running, starting it...')
        subprocess.Popen(['redis-server'])
    else:
        print('Redis already running.')

    print('Starting app and worker with honcho...')
    c.run('python -m honcho start', pty=True)


@task
def down(c) -> None:
    """Stop system started with honcho."""
    print('Stopping system (Ctrl+C equivalent)...')
    c.run("pkill -f honcho || true", warn=True)
