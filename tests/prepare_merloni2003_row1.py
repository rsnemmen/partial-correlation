#!/usr/bin/env python3
"""Normalize the Merloni Table 1 dump for the first Table 2 regression row."""

from __future__ import annotations

import argparse
import math
import re
from pathlib import Path


SKIP_PREFIXES = ('#', '(1) ', 'Notes.', 'Column (1):', 'REFERENCES:')
FOOTNOTE_SUFFIX = re.compile(r'[A-Za-z]+$')
THIN_SPACES = {'\u2007': '', '\u2008': ''}


def parse_numeric_token(token: str) -> tuple[float, int]:
    cleaned = token.strip()
    for src, dst in THIN_SPACES.items():
        cleaned = cleaned.replace(src, dst)
    cleaned = cleaned.replace(' ', '')

    censor_flag = 0 if cleaned.startswith('<') else 1
    if cleaned[:1] in '<>':
        cleaned = cleaned[1:]
    cleaned = FOOTNOTE_SUFFIX.sub('', cleaned)
    if not cleaned:
        raise ValueError(f'invalid numeric token: {token!r}')

    return float(cleaned), censor_flag


def summarize_value(name: str, value: int) -> str:
    return f'{name}={value}'


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('source', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument(
        '--reverse-z-groups',
        action='store_true',
        help='reverse rows within identical distance groups to validate order invariance',
    )
    args = parser.parse_args()

    records: list[tuple[str, str]] = []
    radio_upper_limits = 0
    xray_upper_limits = 0
    z_upper_limits = 0

    for lineno, raw_line in enumerate(args.source.read_text(encoding='utf-8').splitlines(), 1):
        if not raw_line.strip():
            continue
        if raw_line.startswith(SKIP_PREFIXES):
            continue

        columns = raw_line.split('\t')
        if len(columns) != 11:
            raise ValueError(f'line {lineno}: expected 11 tab-separated columns, found {len(columns)}')

        distance_key = columns[1].strip()
        distance_mpc = float(distance_key)
        log_lr, censor_lr = parse_numeric_token(columns[3])
        log_lx, censor_lx = parse_numeric_token(columns[6])
        log_d = math.log10(distance_mpc)

        radio_upper_limits += int(censor_lr == 0)
        xray_upper_limits += int(censor_lx == 0)

        records.append(
            (
                distance_key,
                f'{log_lr:.6f} {censor_lr:d} {log_lx:.6f} {censor_lx:d} {log_d:.6f} 1\n',
            )
        )

    output_rows: list[str] = []
    if args.reverse_z_groups:
        grouped: dict[str, list[str]] = {}
        for distance_key, row in records:
            grouped.setdefault(distance_key, []).append(row)
        for group_rows in grouped.values():
            output_rows.extend(reversed(group_rows))
    else:
        output_rows = [row for _, row in records]

    args.output.write_text(''.join(output_rows), encoding='utf-8')

    print(
        ' '.join(
            [
                summarize_value('rows', len(records)),
                summarize_value('radio_upper_limits', radio_upper_limits),
                summarize_value('xray_upper_limits', xray_upper_limits),
                summarize_value('z_upper_limits', z_upper_limits),
            ]
        )
    )
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
