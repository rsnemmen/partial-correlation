from __future__ import annotations

from pathlib import Path

import pytest

from .pytest_helpers import (
    FIXTURE,
    REFERENCE,
    extract_colon_value,
    extract_equals_value,
    extract_message,
    prepare_merloni_fixture,
    run_python_cli,
    summary_value,
)


MERLONI_PARTIAL_TAU = 0.267236739
MERLONI_SIGMA = 4.58830856e-02
MERLONI_NULL_PROBABILITY = 5.7353336267124159e-09
RESULT_TOLERANCE = 1e-6
PROBABILITY_TOLERANCE = 1e-10
ORDER_TOLERANCE = 1e-9


def test_python_cli_matches_sample_reference_output() -> None:
    completed = run_python_cli(FIXTURE)

    assert completed.returncode == 0, completed.stderr
    assert completed.stderr == ''

    reference_text = REFERENCE.read_text(encoding='utf-8')

    for pattern in ('Tau(1,2):', 'Tau(1,3):', 'Tau(2,3):', 'Partial Kendalls tau:', 'Square root of variance (sigma):'):
        assert float(extract_colon_value(completed.stdout, pattern)) == pytest.approx(
            float(extract_colon_value(reference_text, pattern)),
            rel=0.0,
            abs=RESULT_TOLERANCE,
        )

    assert extract_message(completed.stdout) == extract_message(reference_text)
    assert float(extract_equals_value(completed.stdout, 'Probability of null hypothesis')) == pytest.approx(
        float(extract_equals_value(reference_text, 'Probability of null hypothesis')),
        rel=0.0,
        abs=RESULT_TOLERANCE,
    )


def test_python_cli_accepts_stdin_path() -> None:
    positional = run_python_cli(FIXTURE)
    stdin = run_python_cli(input_text=f'{FIXTURE}\n')

    assert positional.returncode == 0, positional.stderr
    assert stdin.returncode == 0, stdin.stderr
    assert stdin.stderr == ''
    assert float(extract_colon_value(stdin.stdout, 'Partial Kendalls tau:')) == pytest.approx(
        float(extract_colon_value(positional.stdout, 'Partial Kendalls tau:')),
        rel=0.0,
        abs=ORDER_TOLERANCE,
    )


def test_python_cli_matches_merloni_regression(tmp_path: Path) -> None:
    fixture = tmp_path / 'merloni-row1.dat'
    reordered_fixture = tmp_path / 'merloni-row1-reordered.dat'

    summary = prepare_merloni_fixture(fixture)
    reordered_summary = prepare_merloni_fixture(reordered_fixture, reverse_z_groups=True)

    assert summary_value(summary, 'rows') == '149'
    assert summary_value(summary, 'radio_upper_limits') == '20'
    assert summary_value(summary, 'xray_upper_limits') == '14'
    assert summary_value(summary, 'z_upper_limits') == '0'
    assert summary_value(reordered_summary, 'rows') == '149'

    completed = run_python_cli(fixture)
    reordered = run_python_cli(reordered_fixture)

    assert completed.returncode == 0, completed.stderr
    assert reordered.returncode == 0, reordered.stderr
    assert completed.stderr == ''
    assert reordered.stderr == ''

    assert float(extract_colon_value(completed.stdout, 'Partial Kendalls tau:')) == pytest.approx(
        float(extract_colon_value(reordered.stdout, 'Partial Kendalls tau:')),
        rel=0.0,
        abs=ORDER_TOLERANCE,
    )
    assert float(extract_colon_value(completed.stdout, 'Square root of variance (sigma):')) == pytest.approx(
        float(extract_colon_value(reordered.stdout, 'Square root of variance (sigma):')),
        rel=0.0,
        abs=ORDER_TOLERANCE,
    )
    assert float(extract_colon_value(completed.stdout, 'Partial Kendalls tau:')) == pytest.approx(
        MERLONI_PARTIAL_TAU,
        rel=0.0,
        abs=RESULT_TOLERANCE,
    )
    assert float(extract_colon_value(completed.stdout, 'Square root of variance (sigma):')) == pytest.approx(
        MERLONI_SIGMA,
        rel=0.0,
        abs=RESULT_TOLERANCE,
    )
    assert extract_message(completed.stdout) == 'Zero partial correlation rejected at level 0.05'
    assert float(extract_equals_value(completed.stdout, 'Probability of null hypothesis')) == pytest.approx(
        MERLONI_NULL_PROBABILITY,
        rel=0.0,
        abs=PROBABILITY_TOLERANCE,
    )
