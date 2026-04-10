import socket
import subprocess


def is_redis_running(host='127.0.0.1', port=6379):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex((host, port)) == 0


if not is_redis_running():
    subprocess.run(['redis-server'])
