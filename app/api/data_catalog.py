from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from app import config as app_config


DATA_FILE_PATTERN = re.compile(r"^(?P<timestamp>\d{10})\.dat$")


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


def list_data_files(
    *,
    year: int | None = None,
    month: int | None = None,
    day: int | None = None,
    start: str | None = None,
    end: str | None = None,
    limit: int | None = None,
) -> dict[str, Any]:
    data_dir = app_config.DATA_DIR
    mdata_dir = data_dir / "mdata"

    if not mdata_dir.is_dir():
        return {
            "data_dir": str(data_dir),
            "mdata_dir": str(mdata_dir),
            "count": 0,
            "files": [],
            "warning": "mdata directory does not exist or is not readable",
        }

    files = _scan_mdata_files(mdata_dir)
    files = _apply_latest_month_default(files, year=year, month=month, day=day, start=start, end=end)
    files = _filter_files(files, year=year, month=month, day=day, start=start, end=end)

    if limit is not None:
        files = files[:limit]

    return {
        "data_dir": str(data_dir),
        "mdata_dir": str(mdata_dir),
        "count": len(files),
        "files": [item.to_dict() for item in files],
    }


def parse_data_query(args: Any) -> dict[str, Any]:
    return {
        "year": _parse_int_arg(args, "year", minimum=0),
        "month": _parse_int_arg(args, "month", minimum=1, maximum=12),
        "day": _parse_int_arg(args, "day", minimum=1, maximum=31),
        "start": _parse_timestamp_arg(args, "from"),
        "end": _parse_timestamp_arg(args, "to"),
        "limit": _parse_int_arg(args, "limit", minimum=1),
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


def _parse_int_arg(args: Any, name: str, *, minimum: int | None = None, maximum: int | None = None) -> int | None:
    value = args.get(name)
    if value is None or value == "":
        return None

    try:
        parsed = int(value)
    except ValueError as exc:
        raise ValueError(f"Query parameter '{name}' must be an integer.") from exc

    if minimum is not None and parsed < minimum:
        raise ValueError(f"Query parameter '{name}' must be >= {minimum}.")
    if maximum is not None and parsed > maximum:
        raise ValueError(f"Query parameter '{name}' must be <= {maximum}.")

    return parsed


def _parse_timestamp_arg(args: Any, name: str) -> str | None:
    value = args.get(name)
    if value is None or value == "":
        return None

    if not re.fullmatch(r"\d{10}", value):
        raise ValueError(f"Query parameter '{name}' must use YYYYMMDDHH format.")

    return value
