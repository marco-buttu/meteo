"""Comparison helpers for legacy/native operation equivalence tests."""

from __future__ import annotations

from math import isclose
from typing import Any


IGNORED_RESULT_KEYS = frozenset({"job_id", "created_at", "started_at", "finished_at"})


def assert_json_equivalent(left: Any, right: Any, *, abs_tol: float, rel_tol: float, path: str = "$") -> None:
    if isinstance(left, dict) and isinstance(right, dict):
        left_keys = set(left) - IGNORED_RESULT_KEYS
        right_keys = set(right) - IGNORED_RESULT_KEYS
        assert left_keys == right_keys, f"Key mismatch at {path}: {left_keys!r} != {right_keys!r}"
        for key in sorted(left_keys):
            assert_json_equivalent(left[key], right[key], abs_tol=abs_tol, rel_tol=rel_tol, path=f"{path}.{key}")
        return

    if isinstance(left, list) and isinstance(right, list):
        assert len(left) == len(right), f"Length mismatch at {path}: {len(left)} != {len(right)}"
        for index, (left_item, right_item) in enumerate(zip(left, right)):
            assert_json_equivalent(left_item, right_item, abs_tol=abs_tol, rel_tol=rel_tol, path=f"{path}[{index}]")
        return

    if _is_number(left) and _is_number(right):
        assert isclose(float(left), float(right), abs_tol=abs_tol, rel_tol=rel_tol), (
            f"Numeric mismatch at {path}: {left!r} != {right!r} "
            f"with abs_tol={abs_tol} rel_tol={rel_tol}"
        )
        return

    assert left == right, f"Value mismatch at {path}: {left!r} != {right!r}"


def _is_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)
