from __future__ import annotations

import json
import shutil
import tempfile
from copy import deepcopy
from pathlib import Path
from typing import Any, Dict, Optional

from app.domain.exceptions import (
    JobNotFoundError,
    PlotNotAvailableError,
    ResultNotAvailableError,
    StorageError,
)
from app.domain.job_models import JobMetadata


class StorageService:
    """Filesystem-backed shared storage for metadata, results, and plot artifacts."""

    def __init__(
        self,
        root_dir: Optional[str] = None,
        plot_dir: Optional[str] = None,
    ) -> None:
        self._root_dir = Path(root_dir or '/data/jobs').resolve()
        self._metadata_dir = self._root_dir / 'metadata'
        self._result_dir = self._root_dir / 'results'
        self._plot_dir = Path(plot_dir).resolve() if plot_dir else self._root_dir / 'plots'
        self._ensure_directories()

    def save_job_metadata(self, metadata: JobMetadata) -> None:
        self._write_json(self._metadata_path(metadata.job_id), metadata.to_dict())

    def load_job_metadata(self, job_id: str) -> JobMetadata:
        path = self._metadata_path(job_id)
        if not path.exists():
            raise JobNotFoundError(f"Job '{job_id}' not found")
        data = self._read_json(path)
        return JobMetadata.from_dict(data)

    def update_job_metadata(self, metadata: JobMetadata) -> None:
        path = self._metadata_path(metadata.job_id)
        if not path.exists():
            raise JobNotFoundError(f"Job '{metadata.job_id}' not found")
        self._write_json(path, metadata.to_dict())

    def save_job_result(self, job_id: str, result: Dict[str, Any]) -> None:
        self._write_json(self._result_path(job_id), deepcopy(result))

    def load_job_result(self, job_id: str) -> Dict[str, Any]:
        path = self._result_path(job_id)
        if not path.exists():
            raise ResultNotAvailableError(f"Result not available for job '{job_id}'")
        return deepcopy(self._read_json(path))

    def has_job_result(self, job_id: str) -> bool:
        return self._result_path(job_id).exists()

    def save_job_plot(self, job_id: str, plot_bytes: bytes) -> None:
        self._write_bytes(self._plot_path(job_id), bytes(plot_bytes))

    def load_job_plot(self, job_id: str) -> bytes:
        path = self._plot_path(job_id)
        if not path.exists():
            raise PlotNotAvailableError(
                f"Plot not available for job '{job_id}'",
                reason='not_supported',
            )
        try:
            return path.read_bytes()
        except OSError as exc:
            raise StorageError(f"Failed to read plot for job '{job_id}'") from exc

    def has_job_plot(self, job_id: str) -> bool:
        return self._plot_path(job_id).exists()

    def clear_all(self) -> None:
        for directory in {self._root_dir, self._plot_dir}:
            if directory.exists():
                shutil.rmtree(directory)
        self._ensure_directories()

    def _ensure_directories(self) -> None:
        for directory in (
            self._metadata_dir,
            self._result_dir,
            self._plot_dir,
        ):
            directory.mkdir(parents=True, exist_ok=True)

    def _metadata_path(self, job_id: str) -> Path:
        return self._metadata_dir / f'{job_id}.json'

    def _result_path(self, job_id: str) -> Path:
        return self._result_dir / f'{job_id}.json'

    def _plot_path(self, job_id: str) -> Path:
        return self._plot_dir / f'{job_id}.png'

    def _read_json(self, path: Path) -> Dict[str, Any]:
        try:
            with path.open('r', encoding='utf-8') as handle:
                return json.load(handle)
        except (OSError, json.JSONDecodeError) as exc:
            raise StorageError(f"Failed to read JSON data from '{path}'") from exc

    def _write_json(self, path: Path, payload: Dict[str, Any]) -> None:
        serialized = json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True)
        self._atomic_write_text(path, serialized)

    def _write_bytes(self, path: Path, payload: bytes) -> None:
        self._atomic_write_bytes(path, payload)

    def _atomic_write_text(self, path: Path, payload: str) -> None:
        fd, tmp_path = tempfile.mkstemp(
            dir=str(path.parent),
            prefix='.tmp-',
            suffix=path.suffix,
        )
        try:
            with open(fd, 'w', encoding='utf-8') as handle:
                handle.write(payload)
                handle.flush()
                os_fsync(handle)
            Path(tmp_path).replace(path)
        except OSError as exc:
            Path(tmp_path).unlink(missing_ok=True)
            raise StorageError(f"Failed to write text data to '{path}'") from exc

    def _atomic_write_bytes(self, path: Path, payload: bytes) -> None:
        fd, tmp_path = tempfile.mkstemp(
            dir=str(path.parent),
            prefix='.tmp-',
            suffix=path.suffix,
        )
        try:
            with open(fd, 'wb') as handle:
                handle.write(payload)
                handle.flush()
                os_fsync(handle)
            Path(tmp_path).replace(path)
        except OSError as exc:
            Path(tmp_path).unlink(missing_ok=True)
            raise StorageError(f"Failed to write binary data to '{path}'") from exc


def os_fsync(handle: Any) -> None:
    import os

    os.fsync(handle.fileno())
