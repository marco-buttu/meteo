from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Any, Dict, Optional

from app.domain.exceptions import QueueError


@dataclass(frozen=True)
class QueuePayload:
    job_id: str
    operation: str
    validated_parameters: Dict[str, Any]

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


class QueueService:
    """RQ-backed queue service used by the API layer."""

    def __init__(self, redis_url: str, queue_name: str) -> None:
        self._redis_url = redis_url
        self._queue_name = queue_name

    def submit_job(
        self,
        job_id: str,
        operation: str,
        validated_parameters: Dict[str, Any],
    ) -> QueuePayload:
        payload = QueuePayload(
            job_id=job_id,
            operation=operation,
            validated_parameters=validated_parameters,
        )

        try:
            from redis import Redis
            from rq import Queue
        except Exception as exc:
            raise QueueError('RQ dependencies are not installed.') from exc

        try:
            connection = Redis.from_url(self._redis_url)
            queue = Queue(name=self._queue_name, connection=connection)
            queue.enqueue_call(
            func='worker.execute_queued_job',
            kwargs={
                'job_id': payload.job_id,
                'operation': payload.operation,
                'validated_parameters': payload.validated_parameters,
            },
            job_id=payload.job_id,
        )
        except Exception as exc:
            raise QueueError(f"Failed to enqueue job '{job_id}'") from exc

        return payload
