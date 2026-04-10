from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Dict, Optional

from app.domain.exceptions import (
    OperationError,
    OperationExecutionError,
    OperationOutputError,
    OperationTimeoutError,
)
from app.domain.job_models import JobError, JobMetadata, OperationOutput
from app.services.operation_service import get_operation_handler
from app.services.storage_service import StorageService


class JobWorker:
    """Worker-side orchestrator for queued job execution."""

    def __init__(self, storage_service: Optional[StorageService] = None) -> None:
        self._storage = storage_service or StorageService()

    def execute_job(
        self,
        job_id: str,
        operation: str,
        validated_parameters: Dict[str, Any],
    ) -> None:
        metadata = self._storage.load_job_metadata(job_id)
        started_metadata = self._mark_started(metadata)
        self._storage.update_job_metadata(started_metadata)

        try:
            handler = get_operation_handler(operation)
            raw_output = handler(validated_parameters)
            output = self._validate_output(raw_output)

            if output.result is not None:
                self._storage.save_job_result(job_id, output.result)

            if output.plot_bytes is not None:
                self._storage.save_job_plot(job_id, output.plot_bytes)

            finished_metadata = self._mark_finished(
                metadata=started_metadata,
                has_result=output.result is not None,
                has_plot=output.plot_bytes is not None,
            )
            self._storage.update_job_metadata(finished_metadata)

        except Exception as exc:
            failed_metadata = self._build_failed_metadata(
                metadata=started_metadata,
                exception=exc,
            )
            self._storage.update_job_metadata(failed_metadata)

    def _validate_output(self, raw_output: Any) -> OperationOutput:
        if not isinstance(raw_output, dict):
            raise OperationOutputError("Handler output must be a dictionary.")

        if "result" not in raw_output or "plot_bytes" not in raw_output:
            raise OperationOutputError("Missing required keys in handler output.")

        output = OperationOutput(
            result=raw_output.get("result"),
            plot_bytes=raw_output.get("plot_bytes"),
        )

        if not output.is_valid():
            raise OperationOutputError("Handler output does not match the internal contract.")

        return output

    def _mark_started(self, metadata: JobMetadata) -> JobMetadata:
        return JobMetadata(
            job_id=metadata.job_id,
            status="started",
            operation=metadata.operation,
            validated_parameters=metadata.validated_parameters,
            created_at=metadata.created_at,
            started_at=self._now(),
            finished_at=None,
            has_result=False,
            has_plot=False,
            error=None,
        )

    def _mark_finished(
        self,
        metadata: JobMetadata,
        has_result: bool,
        has_plot: bool,
    ) -> JobMetadata:
        return JobMetadata(
            job_id=metadata.job_id,
            status="finished",
            operation=metadata.operation,
            validated_parameters=metadata.validated_parameters,
            created_at=metadata.created_at,
            started_at=metadata.started_at,
            finished_at=self._now(),
            has_result=has_result,
            has_plot=has_plot,
            error=None,
        )

    def _build_failed_metadata(
        self,
        metadata: JobMetadata,
        exception: Exception,
    ) -> JobMetadata:
        error = self._map_exception(exception)
        return JobMetadata(
            job_id=metadata.job_id,
            status="failed",
            operation=metadata.operation,
            validated_parameters=metadata.validated_parameters,
            created_at=metadata.created_at,
            started_at=metadata.started_at,
            finished_at=self._now(),
            has_result=False,
            has_plot=False,
            error=error,
        )

    def _map_exception(self, exc: Exception) -> JobError:
        if isinstance(exc, OperationError):
            return JobError(code=exc.code, message=str(exc))

        if isinstance(exc, OperationExecutionError):
            return JobError(code="OPERATION_EXECUTION_FAILED", message=str(exc))

        if isinstance(exc, OperationTimeoutError):
            return JobError(code="OPERATION_TIMEOUT", message=str(exc))

        if isinstance(exc, OperationOutputError):
            return JobError(code="INVALID_OPERATION_OUTPUT", message=str(exc))

        return JobError(code="INTERNAL_ERROR", message="Unexpected execution error.")

    @staticmethod
    def _now() -> str:
        ts = datetime.now(timezone.utc).replace(microsecond=0)
        return ts.strftime("%Y-%m-%dT%H:%M:%SZ")


def execute_job(job_id: str, operation: str, validated_parameters: Dict[str, Any]) -> None:
    worker = JobWorker()
    worker.execute_job(
        job_id=job_id,
        operation=operation,
        validated_parameters=validated_parameters,
    )
