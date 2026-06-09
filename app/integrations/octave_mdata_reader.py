"""Reader for the Octave binary mdata files used by the legacy backend.

This module intentionally supports only the subset of the Octave binary format
used by the atmospheric ``mdata`` files generated for this application. It is
not a general-purpose Octave binary reader.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import struct
from typing import Any, BinaryIO

from app.domain.exceptions import OperationExecutionError


_HEADER = b"Octave-1-L\0"
_DOUBLE_TYPE_CODE = 7
_MATRIX_DIMS_MARKER = -2


class OctaveMdataReadError(ValueError):
    """Raised when an Octave mdata file cannot be decoded."""


@dataclass(frozen=True)
class MData:
    """Decoded subset of the Octave ``mdata`` struct."""

    isok: float
    nl: int
    nh: int
    step: float
    model: str
    version: float
    site: str
    prs: list[list[float]]
    tmp: list[list[float]]
    hgt: list[list[float]]
    rh: list[list[float]]
    dpt: list[list[float]]
    uwind: list[list[float]]
    vwind: list[list[float]]
    clwmr: list[list[float]]
    crain: list[list[float]]
    date: str


def read_mdata_file(path: Path | str) -> MData:
    """Read an Octave binary mdata file.

    Args:
        path: File path to a ``YYYYMMDDHH.dat`` Octave binary file.

    Returns:
        The decoded mdata struct.

    Raises:
        OperationExecutionError: If the file cannot be read or decoded.
    """

    data_path = Path(path)
    try:
        raw = data_path.read_bytes()
        decoded = _OctaveBinaryReader(raw).read_file()
        return _build_mdata(decoded)
    except (OSError, OctaveMdataReadError, struct.error, UnicodeDecodeError) as exc:
        raise OperationExecutionError(
            "Unable to read data file as the expected Octave binary mdata file.",
            code="DATA_FILE_READ_FAILED",
        ) from exc


class _OctaveBinaryReader:
    def __init__(self, raw: bytes) -> None:
        self._raw = raw
        self._offset = 0

    def read_file(self) -> dict[str, Any]:
        header = self._read(len(_HEADER))
        if header != _HEADER:
            raise OctaveMdataReadError("Invalid Octave binary header.")

        name = self._read_name()
        type_name = self._read_type_name()
        if name != "mdata" or type_name != "scalar struct":
            raise OctaveMdataReadError("Expected a scalar struct named mdata.")

        value = self._read_value(type_name)
        if self._offset != len(self._raw):
            raise OctaveMdataReadError("Trailing unread bytes in mdata file.")
        if not isinstance(value, dict):
            raise OctaveMdataReadError("Decoded mdata value is not a struct.")
        return value

    def _read(self, size: int) -> bytes:
        if self._offset + size > len(self._raw):
            raise OctaveMdataReadError("Unexpected end of file.")
        chunk = self._raw[self._offset : self._offset + size]
        self._offset += size
        return chunk

    def _read_u32(self) -> int:
        return struct.unpack("<I", self._read(4))[0]

    def _read_i32(self) -> int:
        return struct.unpack("<i", self._read(4))[0]

    def _read_f64(self) -> float:
        return struct.unpack("<d", self._read(8))[0]

    def _read_name(self) -> str:
        length = self._read_u32()
        return self._read(length).decode("latin1")

    def _read_type_name(self) -> str:
        # Octave binary variables contain a zero documentation string length,
        # a global flag byte, then a 0xff marker followed by the type name.
        doc_length = self._read_u32()
        if doc_length != 0:
            self._read(doc_length)
        self._read(1)  # global flag
        marker = self._read(1)[0]
        if marker != 0xFF:
            raise OctaveMdataReadError("Invalid Octave type marker.")
        length = self._read_u32()
        return self._read(length).decode("latin1")

    def _read_value(self, type_name: str) -> Any:
        if type_name == "scalar struct":
            return self._read_scalar_struct()
        if type_name == "scalar":
            return self._read_scalar()
        if type_name == "matrix":
            return self._read_matrix()
        if type_name == "sq_string":
            return self._read_sq_string()
        raise OctaveMdataReadError(f"Unsupported Octave type: {type_name!r}.")

    def _read_scalar_struct(self) -> dict[str, Any]:
        field_count = self._read_u32()
        result: dict[str, Any] = {}
        for _ in range(field_count):
            name = self._read_name()
            type_name = self._read_type_name()
            result[name] = self._read_value(type_name)
        return result

    def _read_scalar(self) -> float:
        type_code = self._read(1)[0]
        if type_code != _DOUBLE_TYPE_CODE:
            raise OctaveMdataReadError("Unsupported scalar numeric type.")
        return self._read_f64()

    def _read_matrix(self) -> list[list[float]]:
        dims_marker = self._read_i32()
        if dims_marker != _MATRIX_DIMS_MARKER:
            raise OctaveMdataReadError("Unsupported matrix dimension marker.")
        rows = self._read_u32()
        cols = self._read_u32()
        type_code = self._read(1)[0]
        if type_code != _DOUBLE_TYPE_CODE:
            raise OctaveMdataReadError("Unsupported matrix numeric type.")

        values = [self._read_f64() for _ in range(rows * cols)]
        matrix = [[0.0 for _ in range(cols)] for _ in range(rows)]
        index = 0
        for col in range(cols):
            for row in range(rows):
                matrix[row][col] = values[index]
                index += 1
        return matrix

    def _read_sq_string(self) -> str:
        dims_marker = self._read_i32()
        if dims_marker != _MATRIX_DIMS_MARKER:
            raise OctaveMdataReadError("Unsupported string dimension marker.")
        rows = self._read_u32()
        cols = self._read_u32()
        return self._read(rows * cols).decode("latin1")


def _build_mdata(decoded: dict[str, Any]) -> MData:
    required = {
        "isok",
        "nl",
        "nh",
        "step",
        "model",
        "version",
        "site",
        "prs",
        "tmp",
        "hgt",
        "rh",
        "dpt",
        "uwind",
        "vwind",
        "clwmr",
        "crain",
        "date",
    }
    missing = sorted(required - set(decoded))
    if missing:
        raise OctaveMdataReadError("Missing mdata field(s): " + ", ".join(missing))

    nl = int(decoded["nl"])
    nh = int(decoded["nh"])

    for field in ("prs", "tmp", "hgt", "rh", "dpt", "uwind", "vwind", "clwmr"):
        _ensure_matrix_shape(field, decoded[field], nl, nh)
    _ensure_matrix_shape("crain", decoded["crain"], 1, nh)

    return MData(
        isok=float(decoded["isok"]),
        nl=nl,
        nh=nh,
        step=float(decoded["step"]),
        model=str(decoded["model"]),
        version=float(decoded["version"]),
        site=str(decoded["site"]),
        prs=decoded["prs"],
        tmp=decoded["tmp"],
        hgt=decoded["hgt"],
        rh=decoded["rh"],
        dpt=decoded["dpt"],
        uwind=decoded["uwind"],
        vwind=decoded["vwind"],
        clwmr=decoded["clwmr"],
        crain=decoded["crain"],
        date=str(decoded["date"]),
    )


def _ensure_matrix_shape(
    field_name: str,
    value: Any,
    expected_rows: int,
    expected_cols: int,
) -> None:
    if not isinstance(value, list) or len(value) != expected_rows:
        raise OctaveMdataReadError(f"Field {field_name!r} has invalid row count.")
    for row in value:
        if not isinstance(row, list) or len(row) != expected_cols:
            raise OctaveMdataReadError(f"Field {field_name!r} has invalid column count.")
