#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
python_bin="${PYTHON:-python}"
fixture="$repo_root/data/test01.dat"
tmp_invalid=$(mktemp "${TMPDIR:-/tmp}/python-invalid-fixture.XXXXXX")
trap 'rm -f "$tmp_invalid"' EXIT

INVALID_FIXTURE="$tmp_invalid" FIXTURE="$fixture" "$python_bin" - <<'PY'
from __future__ import annotations

import math
import os
from pathlib import Path

import numpy as np

from partial_correlation import (
    partial_kendall_tau,
    partial_kendall_tau_from_file,
    partial_kendall_tau_table,
    read_table,
)


def assert_close(label: str, actual: float, expected: float, tolerance: float = 1e-12) -> None:
    if not math.isclose(actual, expected, rel_tol=0.0, abs_tol=tolerance):
        raise AssertionError(f'{label}: expected {expected} got {actual}')


fixture = Path(os.environ['FIXTURE'])
invalid_fixture = Path(os.environ['INVALID_FIXTURE'])
values, censoring = read_table(fixture)

result_from_file = partial_kendall_tau_from_file(fixture)
result_from_table = partial_kendall_tau_table(values, censoring)
result_from_columns = partial_kendall_tau(
    values[:, 0],
    censoring[:, 0],
    values[:, 1],
    censoring[:, 1],
    values[:, 2],
    censoring[:, 2],
)

for field in (
    'tau_12',
    'tau_13',
    'tau_23',
    'partial_tau',
    'sigma',
    'z_score',
    'null_hypothesis_probability',
):
    assert_close(field, getattr(result_from_file, field), getattr(result_from_table, field))
    assert_close(field, getattr(result_from_file, field), getattr(result_from_columns, field))

if values.shape != (50, 3):
    raise AssertionError(f'unexpected value table shape: {values.shape}')
if not np.all(censoring == 1):
    raise AssertionError('expected the bundled sample fixture to be all detections')

invalid_fixture.write_text('1 1 2 1 3\n', encoding='utf-8')
try:
    read_table(invalid_fixture)
except ValueError as exc:
    if 'expected six whitespace-delimited columns' not in str(exc):
        raise AssertionError(f'unexpected validation message: {exc}')
else:
    raise AssertionError('expected invalid fixture to fail validation')

print('PASS: Python API file/table/column entry points agree')
PY
