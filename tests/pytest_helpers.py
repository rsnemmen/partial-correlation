from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
FIXTURE = REPO_ROOT / 'data/test01.dat'
REFERENCE = REPO_ROOT / 'data/test01.txt'
RAW_MERLONI_SOURCE = REPO_ROOT / 'data/merloni2003.dat'
PREPARE_MERLONI_SCRIPT = REPO_ROOT / 'tests/prepare_merloni2003_row1.py'

_NUMBER_PATTERN = re.compile(r'[-+]?(?:\d+\.?\d*|\.\d+)(?:[Ee][-+]?\d+)?')
_SIGNIFICANCE_MESSAGES = (
    'Zero partial correlation rejected at level 0.05',
    'Null hypothesis cannot be rejected!',
)


def run_python_cli(*args: str | Path, input_text: str | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, '-m', 'partial_correlation', *(str(arg) for arg in args)],
        input=input_text,
        text=True,
        capture_output=True,
        cwd=REPO_ROOT,
        check=False,
    )


def prepare_merloni_fixture(output_path: Path, *, reverse_z_groups: bool = False) -> str:
    command = [sys.executable, str(PREPARE_MERLONI_SCRIPT)]
    if reverse_z_groups:
        command.append('--reverse-z-groups')
    command.extend([str(RAW_MERLONI_SOURCE), str(output_path)])

    completed = subprocess.run(
        command,
        text=True,
        capture_output=True,
        cwd=REPO_ROOT,
        check=False,
    )
    if completed.returncode != 0:
        raise AssertionError(completed.stderr or completed.stdout or 'failed to prepare Merloni fixture')
    return completed.stdout.strip()


def summary_value(summary: str, key: str) -> str:
    for item in summary.split():
        item_key, item_value = item.split('=', 1)
        if item_key == key:
            return item_value
    raise AssertionError(f'missing summary value {key!r} in {summary!r}')


def extract_colon_value(text: str, pattern: str) -> str:
    return _extract_after_separator(text, pattern, ':')


def extract_equals_value(text: str, pattern: str) -> str:
    return _extract_after_separator(text, pattern, '=')


def extract_message(text: str) -> str:
    for line in text.splitlines():
        stripped = line.strip()
        if stripped in _SIGNIFICANCE_MESSAGES:
            return stripped
    raise AssertionError('missing significance message')


def _extract_after_separator(text: str, pattern: str, separator: str) -> str:
    for line in text.splitlines():
        if pattern in line:
            _, _, tail = line.partition(separator)
            if tail:
                return ''.join(tail.split())
            break
    raise AssertionError(f'missing {pattern!r}')
