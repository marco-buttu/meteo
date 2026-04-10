from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Optional
from uuid import uuid4

from app.domain.exceptions import (
    JobFailedError,
    PlotNotAvailableError,
    QueueError,
    QueueSubmissionError,
    ResultNotAvailableError,
    ResultNotReadyError,
)
from app.domain.job_models import JobError, JobMetadata, JobResult
from app.services.operation_service import (
    check_operation_exists,
    validate_and_normalize_parameters,
)
from app.services.queue_service import QueueService
from app.services.storage_service import StorageService


class JobService:
    """Application service responsible for job lifecycle orchestration."""

    def __init__(
        self,
        storage_service: StorageService,
        queue_service: QueueService,
    ) -> None:
        self._storage_service = storage_service
        self._queue_service = queue_service

    def create_job(self, operation: str, parameters: Any) -> JobMetadata:
        check_operation_exists(operation)
        validated_parameters = validate_and_normalize_parameters(operation, parameters)

        metadata = JobMetadata(
            job_id=self._generate_job_id(),
            status='queued',
            operation=operation,
            validated_parameters=validated_parameters,
            created_at=self._current_timestamp(),
            started_at=None,
            finished_at=None,
            has_result=False,
            has_plot=False,
            error=None,
        )

        self._storage_service.save_job_metadata(metadata)

        try:
            self._queue_service.submit_job(
                job_id=metadata.job_id,
                operation=metadata.operation,
                validated_parameters=metadata.validated_parameters,
            )
        except QueueError as exc:
            failed_metadata = self._build_queue_failure_metadata(
                metadata=metadata,
                message=str(exc),
            )
            self._storage_service.update_job_metadata(failed_metadata)
            raise QueueSubmissionError(
                job_id=metadata.job_id,
                message=(
                    f"Queue submission failed for job '{metadata.job_id}': "
                    f'{exc}'
                ),
            ) from exc

        return metadata

    def get_job_metadata(self, job_id: str) -> JobMetadata:
        return self._storage_service.load_job_metadata(job_id)

    def get_job_result(self, job_id: str) -> JobResult:
        metadata = self._storage_service.load_job_metadata(job_id)

        if metadata.status in ('queued', 'started'):
            raise ResultNotReadyError(f"Result is not ready for job '{job_id}'")

        if metadata.status == 'failed':
            raise JobFailedError(self._build_job_failed_message(metadata))

        if not metadata.has_result:
            raise ResultNotAvailableError(f"Result is not available for job '{job_id}'")

        result = self._storage_service.load_job_result(job_id)
        return JobResult(
            job_id=metadata.job_id,
            status=metadata.status,
            operation=metadata.operation,
            result=result,
        )

    def get_job_plot(self, job_id: str) -> bytes:
        metadata = self._storage_service.load_job_metadata(job_id)

        if metadata.status in ('queued', 'started'):
            raise PlotNotAvailableError(
                f"Plot is not available yet for job '{job_id}'",
                reason='not_ready',
            )

        if metadata.status == 'failed':
            raise JobFailedError(self._build_job_failed_message(metadata))

        if not metadata.has_plot:
            raise PlotNotAvailableError(
                f"Plot is not available for job '{job_id}'",
                reason='not_supported',
            )

        return self._storage_service.load_job_plot(job_id)

    def has_job_result(self, job_id: str) -> bool:
        metadata = self._storage_service.load_job_metadata(job_id)
        return metadata.status == 'finished' and metadata.has_result

    def has_job_plot(self, job_id: str) -> bool:
        metadata = self._storage_service.load_job_metadata(job_id)
        return metadata.status == 'finished' and metadata.has_plot

    @staticmethod
    def _generate_job_id() -> str:
        return f'job-{uuid4().hex}'

    @staticmethod
    def _current_timestamp() -> str:
        timestamp = datetime.now(timezone.utc).replace(microsecond=0)
        return timestamp.strftime('%Y-%m-%dT%H:%M:%SZ')

    @classmethod
    def _build_queue_failure_metadata(
        cls,
        metadata: JobMetadata,
        message: str,
    ) -> JobMetadata:
        return JobMetadata(
            job_id=metadata.job_id,
            status='failed',
            operation=metadata.operation,
            validated_parameters=metadata.validated_parameters,
            created_at=metadata.created_at,
            started_at=None,
            finished_at=cls._current_timestamp(),
            has_result=False,
            has_plot=False,
            error=JobError(
                code='QUEUE_SUBMISSION_FAILED',
                message=message,
            ),
        )

    @staticmethod
    def _build_job_failed_message(metadata: JobMetadata) -> str:
        if metadata.error is None:
            return f"Job '{metadata.job_id}' failed"
        return (
            f"Job '{metadata.job_id}' failed: "
            f'{metadata.error.code} - {metadata.error.message}'
        )
