from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from numpy.typing import ArrayLike, NDArray
from scipy.special import erfc

DEFAULT_MAX_FILE_ROWS = 500
_SQRT_TWO = np.sqrt(2.0)


FloatArray = NDArray[np.float64]
IntArray = NDArray[np.int8]


@dataclass(frozen=True)
class PartialKendallResult:
    tau_12: float
    tau_13: float
    tau_23: float
    partial_tau: float
    sigma: float
    z_score: float
    null_hypothesis_probability: float
    rejects_null_0_05: bool


def read_table(path: str | Path, *, max_rows: int | None = DEFAULT_MAX_FILE_ROWS) -> tuple[FloatArray, IntArray]:
    dataset_path = Path(path)
    values: list[tuple[float, float, float]] = []
    censoring: list[tuple[int, int, int]] = []

    with dataset_path.open('r', encoding='utf-8') as handle:
        for lineno, line in enumerate(handle, 1):
            fields = line.split()
            if len(fields) != 6:
                raise ValueError(
                    f'{dataset_path}: invalid data row {lineno}; '
                    'expected six whitespace-delimited columns: X censX Y censY Z censZ'
                )

            try:
                x, cx, y, cy, z, cz = fields
                row = (float(x), float(y), float(z))
                flag_row = (int(cx), int(cy), int(cz))
            except ValueError as exc:
                raise ValueError(
                    f'{dataset_path}: invalid data row {lineno}; '
                    'expected numeric X/Y/Z values and integer censor flags'
                ) from exc

            if any(flag not in (0, 1) for flag in flag_row):
                raise ValueError(f'{dataset_path}: invalid censor flag on row {lineno}; flags must be 0 or 1')

            values.append(row)
            censoring.append(flag_row)

            if max_rows is not None and len(values) > max_rows:
                raise ValueError(f'{dataset_path}: input has more than {max_rows} rows')

    if not values:
        raise ValueError(f'{dataset_path}: input file is empty')
    if len(values) <= 3:
        raise ValueError(f'{dataset_path}: at least 4 rows are required')

    return np.asarray(values, dtype=np.float64), np.asarray(censoring, dtype=np.int8)


def partial_kendall_tau(
    x: ArrayLike,
    cens_x: ArrayLike,
    y: ArrayLike,
    cens_y: ArrayLike,
    z: ArrayLike,
    cens_z: ArrayLike,
    *,
    progress: bool = False,
) -> PartialKendallResult:
    values = np.column_stack(
        (
            _as_vector(x, name='x'),
            _as_vector(y, name='y'),
            _as_vector(z, name='z'),
        )
    )
    censoring = np.column_stack(
        (
            _as_censor_vector(cens_x, name='cens_x'),
            _as_censor_vector(cens_y, name='cens_y'),
            _as_censor_vector(cens_z, name='cens_z'),
        )
    )
    return partial_kendall_tau_table(values, censoring, progress=progress)


def partial_kendall_tau_from_file(
    path: str | Path,
    *,
    max_rows: int | None = DEFAULT_MAX_FILE_ROWS,
    progress: bool = False,
) -> PartialKendallResult:
    values, censoring = read_table(path, max_rows=max_rows)
    return partial_kendall_tau_table(values, censoring, progress=progress)


def partial_kendall_tau_table(
    values: ArrayLike,
    censoring: ArrayLike,
    *,
    progress: bool = False,
) -> PartialKendallResult:
    value_table = _as_value_table(values)
    censor_table = _as_censor_table(censoring, n_rows=value_table.shape[0])

    if value_table.shape[0] <= 3:
        raise ValueError('at least 4 rows are required')

    right_censored_values = -value_table
    c_matrices = _build_c_matrices(right_censored_values, censor_table)

    tau_12 = _kendall_tau(c_matrices[0], c_matrices[1])
    tau_13 = _kendall_tau(c_matrices[0], c_matrices[2])
    tau_23 = _kendall_tau(c_matrices[1], c_matrices[2])

    denominator = (1.0 - tau_13**2) * (1.0 - tau_23**2)
    partial_tau = float((tau_12 - tau_13 * tau_23) / np.sqrt(denominator))
    sigma = float(np.sqrt(_compute_an(c_matrices, progress=progress) / (value_table.shape[0] * denominator)))
    z_score = float(abs(partial_tau / sigma))
    null_probability = float(erfc(z_score / _SQRT_TWO))

    return PartialKendallResult(
        tau_12=tau_12,
        tau_13=tau_13,
        tau_23=tau_23,
        partial_tau=partial_tau,
        sigma=sigma,
        z_score=z_score,
        null_hypothesis_probability=null_probability,
        rejects_null_0_05=bool(z_score > 1.96),
    )


def format_report(path: str | Path, result: PartialKendallResult) -> str:
    lines = [
        str(path),
        f' Tau(1,2): {result.tau_12: .9f}',
        f' Tau(1,3): {result.tau_13: .9f}',
        f' Tau(2,3): {result.tau_23: .9f}',
        f' --> Partial Kendalls tau: {result.partial_tau: .9f}',
        '',
        ' Calculating variance...this takes some time....',
        '',
        f' Square root of variance (sigma): {result.sigma: .8E}',
        '',
    ]

    if result.rejects_null_0_05:
        lines.append(' Zero partial correlation rejected at level 0.05')
    else:
        lines.extend(
            [
                ' Null hypothesis cannot be rejected!',
                ' (--> No correlation present, if influence of',
                ' third variable is excluded)',
            ]
        )

    lines.extend(
        [
            '',
            ' More specifically:',
            f' Null hypothesis rejected at {result.z_score: .7f} sigma',
            f' Probability of null hypothesis = {result.null_hypothesis_probability: .16E}',
        ]
    )
    return '\n'.join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description='Compute the censored partial Kendall tau statistic from a six-column input file.',
    )
    parser.add_argument(
        'path',
        nargs='?',
        help='input file with columns: X censX Y censY Z censZ; if omitted, read one path from stdin',
    )
    parser.add_argument(
        '--max-rows',
        type=int,
        default=DEFAULT_MAX_FILE_ROWS,
        help='maximum number of rows to accept from a file (default: %(default)s)',
    )
    parser.add_argument(
        '--progress',
        action='store_true',
        help='display a tqdm progress bar while computing the variance term',
    )
    args = parser.parse_args(argv)

    input_path = args.path
    if input_path is None:
        line = sys.stdin.readline()
        if not line:
            parser.error('an input file path is required')
        input_path = line.strip()
        if not input_path:
            parser.error('an input file path is required')

    try:
        result = partial_kendall_tau_from_file(input_path, max_rows=args.max_rows, progress=args.progress)
    except Exception as exc:
        print(f'ERROR: {exc}', file=sys.stderr)
        return 1

    print(format_report(input_path, result))
    return 0


def _as_vector(values: ArrayLike, *, name: str) -> FloatArray:
    vector = np.asarray(values, dtype=np.float64)
    if vector.ndim != 1:
        raise ValueError(f'{name} must be a one-dimensional array')
    return vector


def _as_censor_vector(values: ArrayLike, *, name: str) -> IntArray:
    vector = np.asarray(values)
    if vector.ndim != 1:
        raise ValueError(f'{name} must be a one-dimensional array')
    if not np.all((vector == 0) | (vector == 1)):
        raise ValueError(f'{name} must contain only 0/1 censor flags')
    return vector.astype(np.int8, copy=False)


def _as_value_table(values: ArrayLike) -> FloatArray:
    table = np.asarray(values, dtype=np.float64)
    if table.ndim != 2 or table.shape[1] != 3:
        raise ValueError('values must have shape (n, 3)')
    return table


def _as_censor_table(censoring: ArrayLike, *, n_rows: int) -> IntArray:
    table = np.asarray(censoring)
    if table.ndim != 2 or table.shape != (n_rows, 3):
        raise ValueError(f'censoring must have shape ({n_rows}, 3)')
    if not np.all((table == 0) | (table == 1)):
        raise ValueError('censoring must contain only 0/1 flags')
    return table.astype(np.int8, copy=False)


def _build_c_matrices(values: FloatArray, censoring: IntArray) -> FloatArray:
    n_rows = values.shape[0]
    c_matrices = np.zeros((3, n_rows, n_rows), dtype=np.float64)

    for index in range(3):
        column = values[:, index]
        flags = censoring[:, index].astype(np.float64, copy=False)
        less = column[:, None] < column[None, :]
        greater = column[:, None] > column[None, :]
        c_matrices[index] = np.where(less, flags[:, None], np.where(greater, -flags[None, :], 0.0))

    return c_matrices


def _kendall_tau(c_x: FloatArray, c_y: FloatArray) -> float:
    n_rows = c_x.shape[0]
    coefficient = 2.0 / (n_rows * (n_rows - 1.0))
    return float(np.triu(c_x * c_y, k=1).sum(dtype=np.float64) * coefficient)


def _compute_an(c_matrices: FloatArray, *, progress: bool = False) -> float:
    c_x, c_y, c_z = c_matrices
    yz_symmetric = c_y * c_z + (c_y * c_z).T
    n_rows = c_x.shape[0]
    aasum = np.zeros(n_rows, dtype=np.float64)
    progress_bar = _create_progress_bar(total=n_rows) if progress else None

    try:
        for i1 in range(n_rows):
            total = 0.0
            for j1 in range(n_rows - 2):
                if j1 == i1:
                    continue
                for j2 in range(j1 + 2, n_rows):
                    if j2 == i1:
                        continue
                    if j1 < i1 < j2:
                        total += _segment_contribution(c_x, c_y, c_z, yz_symmetric, i1, j1, j2, j1 + 1, i1)
                        total += _segment_contribution(c_x, c_y, c_z, yz_symmetric, i1, j1, j2, i1 + 1, j2)
                    else:
                        total += _segment_contribution(c_x, c_y, c_z, yz_symmetric, i1, j1, j2, j1 + 1, j2)
            aasum[i1] = total / 24.0
            if progress_bar is not None:
                progress_bar.update(1)
    finally:
        if progress_bar is not None:
            progress_bar.close()

    c1 = 16.0 / (n_rows - 1.0)
    c2 = 6.0 / ((n_rows - 1.0) * (n_rows - 2.0) * (n_rows - 3.0))
    centered = c2 * aasum
    ave = centered.mean(dtype=np.float64)
    return float(c1 * np.square(centered - ave).sum(dtype=np.float64))


def _create_progress_bar(*, total: int):
    try:
        from tqdm.auto import tqdm
    except ImportError as exc:
        raise RuntimeError(
            'progress reporting requires tqdm; install tqdm to use --progress or progress=True'
        ) from exc

    return tqdm(total=total, desc='Calculating variance', unit='row', file=sys.stderr)


def _segment_contribution(
    c_x: FloatArray,
    c_y: FloatArray,
    c_z: FloatArray,
    yz_symmetric: FloatArray,
    i1: int,
    j1: int,
    j2: int,
    start: int,
    stop: int,
) -> float:
    if start >= stop:
        return 0.0

    mid = slice(start, stop)
    yz_i1_j1 = yz_symmetric[i1, j1]
    yz_i1_j2 = yz_symmetric[i1, j2]
    yz_j1_j2 = yz_symmetric[j1, j2]

    gtsum = (
        c_x[i1, j1] * (2.0 * c_y[i1, j1] - c_z[i1, j1] * yz_symmetric[mid, j2])
        + c_x[i1, j2] * (2.0 * c_y[i1, j2] - c_z[i1, j2] * yz_symmetric[mid, j1])
        + c_x[i1, mid] * (2.0 * c_y[i1, mid] - c_z[i1, mid] * yz_j1_j2)
        + c_x[j1, i1] * (2.0 * c_y[j1, i1] - c_z[j1, i1] * yz_symmetric[mid, j2])
        + c_x[j1, mid] * (2.0 * c_y[j1, mid] - c_z[j1, mid] * yz_i1_j2)
        + c_x[j1, j2] * (2.0 * c_y[j1, j2] - c_z[j1, j2] * yz_symmetric[i1, mid])
        + c_x[mid, i1] * (2.0 * c_y[mid, i1] - c_z[mid, i1] * yz_j1_j2)
        + c_x[mid, j1] * (2.0 * c_y[mid, j1] - c_z[mid, j1] * yz_i1_j2)
        + c_x[mid, j2] * (2.0 * c_y[mid, j2] - c_z[mid, j2] * yz_i1_j1)
        + c_x[j2, i1] * (2.0 * c_y[j2, i1] - c_z[j2, i1] * yz_symmetric[j1, mid])
        + c_x[j2, j1] * (2.0 * c_y[j2, j1] - c_z[j2, j1] * yz_symmetric[i1, mid])
        + c_x[j2, mid] * (2.0 * c_y[j2, mid] - c_z[j2, mid] * yz_i1_j1)
    )
    return float(np.sum(gtsum, dtype=np.float64))
