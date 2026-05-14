from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from app import config as app_config
from app.domain.exceptions import OperationError


DATA_FILE_PATTERN = re.compile(r"^(?P<timestamp>\d{10})\.dat$")
DEFAULT_LIMIT = 1000


@dataclass(frozen=True)
class DataFile:
    filename: str
    timestamp: str
    year: int
    month: int
    day: int
    hour: int

    def to_dict(self) -> dict[str, Any]:
        return {
            "filename": self.filename,
            "timestamp": self.timestamp,
            "year": self.year,
            "month": self.month,
            "day": self.day,
            "hour": self.hour,
        }


def handle(params: dict[str, Any]) -> dict[str, Any]:
    return {
        "result": list_data_files(
            year=params.get("year"),
            month=params.get("month"),
            day=params.get("day"),
            start=params.get("from"),
            end=params.get("to"),
            limit=params.get("limit"),
        ),
        "plot_bytes": None,
    }


def list_data_files(
    *,
    year: int | None = None,
    month: int | None = None,
    day: int | None = None,
    start: str | None = None,
    end: str | None = None,
    limit: int | None = None,
) -> dict[str, Any]:
    _validate_filters(year=year, month=month, day=day, start=start, end=end, limit=limit)

    effective_limit = DEFAULT_LIMIT if limit is None else limit
    data_dir = app_config.DATA_DIR
    mdata_dir = data_dir / "mdata"

    if not mdata_dir.is_dir():
        return {
            "data_dir": str(data_dir),
            "mdata_dir": str(mdata_dir),
            "count": 0,
            "files": [],
            "limit": effective_limit,
            "default_selection": _default_selection_name(
                year=year,
                month=month,
                day=day,
                start=start,
                end=end,
            ),
            "warning": "mdata directory does not exist or is not readable",
        }

    files = _scan_mdata_files(mdata_dir)
    default_selection = _default_selection_name(
        year=year,
        month=month,
        day=day,
        start=start,
        end=end,
    )
    files = _apply_latest_month_default(files, year=year, month=month, day=day, start=start, end=end)
    files = _filter_files(files, year=year, month=month, day=day, start=start, end=end)
    files = files[:effective_limit]

    return {
        "data_dir": str(data_dir),
        "mdata_dir": str(mdata_dir),
        "count": len(files),
        "limit": effective_limit,
        "default_selection": default_selection,
        "files": [item.to_dict() for item in files],
    }


def _scan_mdata_files(mdata_dir: Path) -> list[DataFile]:
    files: list[DataFile] = []
    for path in mdata_dir.iterdir():
        if not path.is_file():
            continue

        match = DATA_FILE_PATTERN.match(path.name)
        if not match:
            continue

        timestamp = match.group("timestamp")
        files.append(
            DataFile(
                filename=path.name,
                timestamp=timestamp,
                year=int(timestamp[0:4]),
                month=int(timestamp[4:6]),
                day=int(timestamp[6:8]),
                hour=int(timestamp[8:10]),
            )
        )

    return sorted(files, key=lambda item: item.timestamp, reverse=True)


def _apply_latest_month_default(
    files: list[DataFile],
    *,
    year: int | None,
    month: int | None,
    day: int | None,
    start: str | None,
    end: str | None,
) -> list[DataFile]:
    if year is not None or month is not None or day is not None or start is not None or end is not None:
        return files

    if not files:
        return files

    latest = files[0]
    return [item for item in files if item.year == latest.year and item.month == latest.month]


def _filter_files(
    files: list[DataFile],
    *,
    year: int | None,
    month: int | None,
    day: int | None,
    start: str | None,
    end: str | None,
) -> list[DataFile]:
    filtered = files

    if year is not None:
        filtered = [item for item in filtered if item.year == year]
    if month is not None:
        filtered = [item for item in filtered if item.month == month]
    if day is not None:
        filtered = [item for item in filtered if item.day == day]
    if start is not None:
        filtered = [item for item in filtered if item.timestamp >= start]
    if end is not None:
        filtered = [item for item in filtered if item.timestamp <= end]

    return filtered


def _validate_filters(
    *,
    year: int | None,
    month: int | None,
    day: int | None,
    start: str | None,
    end: str | None,
    limit: int | None,
) -> None:
    if year is not None and year < 0:
        raise OperationError("Parameter 'year' must be >= 0.", code="INVALID_PARAMETERS")
    if month is not None and not 1 <= month <= 12:
        raise OperationError("Parameter 'month' must be between 1 and 12.", code="INVALID_PARAMETERS")
    if day is not None and not 1 <= day <= 31:
        raise OperationError("Parameter 'day' must be between 1 and 31.", code="INVALID_PARAMETERS")
    if start is not None and not re.fullmatch(r"\d{10}", start):
        raise OperationError("Parameter 'from' must use YYYYMMDDHH format.", code="INVALID_PARAMETERS")
    if end is not None and not re.fullmatch(r"\d{10}", end):
        raise OperationError("Parameter 'to' must use YYYYMMDDHH format.", code="INVALID_PARAMETERS")
    if start is not None and end is not None and start > end:
        raise OperationError("Parameter 'from' must be <= parameter 'to'.", code="INVALID_PARAMETERS")
    if limit is not None and limit < 1:
        raise OperationError("Parameter 'limit' must be >= 1.", code="INVALID_PARAMETERS")


def _default_selection_name(
    *,
    year: int | None,
    month: int | None,
    day: int | None,
    start: str | None,
    end: str | None,
) -> str:
    if year is None and month is None and day is None and start is None and end is None:
        return "latest_available_month"
    return "explicit_filters"
