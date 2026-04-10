from __future__ import annotations

from copy import deepcopy
from dataclasses import asdict, dataclass
from typing import Any, Dict, Optional


@dataclass(frozen=True)
class JobError:
    code: str
    message: str

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "JobError":
        return cls(
            code=data["code"],
            message=data["message"],
        )


@dataclass(frozen=True)
class JobMetadata:
    job_id: str
    status: str
    operation: str
    validated_parameters: Dict[str, Any]
    created_at: str
    started_at: Optional[str]
    finished_at: Optional[str]
    has_result: bool
    has_plot: bool
    error: Optional[JobError]

    def to_dict(self) -> Dict[str, Any]:
        return {
            "job_id": self.job_id,
            "status": self.status,
            "operation": self.operation,
            "validated_parameters": deepcopy(self.validated_parameters),
            "created_at": self.created_at,
            "started_at": self.started_at,
            "finished_at": self.finished_at,
            "has_result": self.has_result,
            "has_plot": self.has_plot,
            "error": None if self.error is None else self.error.to_dict(),
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "JobMetadata":
        error = data.get("error")
        return cls(
            job_id=data["job_id"],
            status=data["status"],
            operation=data["operation"],
            validated_parameters=deepcopy(data["validated_parameters"]),
            created_at=data["created_at"],
            started_at=data.get("started_at"),
            finished_at=data.get("finished_at"),
            has_result=data["has_result"],
            has_plot=data["has_plot"],
            error=JobError.from_dict(error) if error is not None else None,
        )


@dataclass(frozen=True)
class JobResult:
    job_id: str
    status: str
    operation: str
    result: Dict[str, Any]

    def to_dict(self) -> Dict[str, Any]:
        return {
            "job_id": self.job_id,
            "status": self.status,
            "operation": self.operation,
            "result": deepcopy(self.result),
        }


@dataclass(frozen=True)
class OperationOutput:
    result: Optional[Dict[str, Any]]
    plot_bytes: Optional[bytes]

    def to_dict(self) -> Dict[str, Any]:
        return {
            "result": None if self.result is None else deepcopy(self.result),
            "plot_bytes": self.plot_bytes,
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "OperationOutput":
        return cls(
            result=deepcopy(data.get("result")),
            plot_bytes=data.get("plot_bytes"),
        )

    def is_valid(self) -> bool:
        if self.result is None and self.plot_bytes is None:
            return False
        if self.result is not None and not isinstance(self.result, dict):
            return False
        if self.plot_bytes is not None and not isinstance(self.plot_bytes, bytes):
            return False
        return True
