from __future__ import annotations

import sys
from pathlib import Path

if __package__ in {None, ''}:
    sys.path.insert(0, str(Path(__file__).resolve().parent))

from app.config import JOB_STORAGE_DIR, PLOT_STORAGE_DIR, REDIS_URL, RQ_QUEUE_NAME
from app.services.storage_service import StorageService
from app.workers.job_worker import JobWorker


def execute_queued_job(job_id: str, operation: str, validated_parameters: dict) -> None:
    """Entry function executed by the queue backend."""
    storage_service = StorageService(
        root_dir=JOB_STORAGE_DIR,
        plot_dir=PLOT_STORAGE_DIR,
    )
    worker = JobWorker(storage_service=storage_service)
    worker.execute_job(
        job_id=job_id,
        operation=operation,
        validated_parameters=validated_parameters,
    )


def main() -> None:
    """Start a real RQ worker process."""
    from redis import Redis
    from rq import Queue, Worker

    connection = Redis.from_url(REDIS_URL)
    queue = Queue(name=RQ_QUEUE_NAME, connection=connection)
    worker = Worker([queue], connection=connection)
    worker.work()


if __name__ == '__main__':
    main()
