from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import pytest

import partial_correlation.core as core
from partial_correlation import (
    partial_kendall_tau,
    partial_kendall_tau_from_file,
    partial_kendall_tau_table,
    read_table,
)

from .pytest_helpers import FIXTURE


RESULT_FIELDS = (
    'tau_12',
    'tau_13',
    'tau_23',
    'partial_tau',
    'sigma',
    'z_score',
    'null_hypothesis_probability',
)


def test_python_api_entry_points_agree_on_sample_fixture() -> None:
    values, censoring = read_table(FIXTURE)

    result_from_file = partial_kendall_tau_from_file(FIXTURE)
    result_from_table = partial_kendall_tau_table(values, censoring)
    result_from_columns = partial_kendall_tau(
        values[:, 0],
        censoring[:, 0],
        values[:, 1],
        censoring[:, 1],
        values[:, 2],
        censoring[:, 2],
    )

    for field in RESULT_FIELDS:
        assert getattr(result_from_table, field) == pytest.approx(
            getattr(result_from_file, field),
            rel=0.0,
            abs=1e-12,
        )
        assert getattr(result_from_columns, field) == pytest.approx(
            getattr(result_from_file, field),
            rel=0.0,
            abs=1e-12,
        )

    assert values.shape == (50, 3)
    assert np.all(censoring == 1)


def test_read_table_rejects_malformed_fixture(tmp_path: Path) -> None:
    invalid_fixture = tmp_path / 'invalid-fixture.dat'
    invalid_fixture.write_text('1 1 2 1 3\n', encoding='utf-8')

    with pytest.raises(ValueError, match='expected six whitespace-delimited columns'):
        read_table(invalid_fixture)


def test_python_api_progress_option_reports_progress(monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    events: list[int] = []

    class FakeProgressBar:
        def __init__(self, *, total: int) -> None:
            self.total = total
            print(f'progress-start total={total}', file=sys.stderr)

        def update(self, amount: int = 1) -> None:
            events.append(amount)

        def close(self) -> None:
            print(f'progress-close updates={sum(events)} total={self.total}', file=sys.stderr)

    monkeypatch.setattr(core, '_create_progress_bar', lambda *, total: FakeProgressBar(total=total))

    expected = partial_kendall_tau_from_file(FIXTURE)
    result = partial_kendall_tau_from_file(FIXTURE, progress=True)
    captured = capsys.readouterr()

    for field in RESULT_FIELDS:
        assert getattr(result, field) == pytest.approx(
            getattr(expected, field),
            rel=0.0,
            abs=1e-12,
        )

    assert sum(events) == 50
    assert 'progress-start total=50' in captured.err
    assert 'progress-close updates=50 total=50' in captured.err
