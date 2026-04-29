# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo does

Python implementation of the partial Kendall tau test for censored data (Akritas & Siebert 1996), used in astronomy to check if two variables remain correlated after controlling for a third (e.g., controlling for distance/redshift). The original Fortran source is preserved on the `legacy` branch and at the `fortran-final` tag.

## Commands

```sh
# Run tests (pytest)
make test

# Run a single pytest file
python -m pytest tests/test_python_api.py
python -m pytest tests/test_python_cli.py

# Run the CLI on the bundled sample
python -m partial_correlation data/test01.dat

# Print only stable summary lines
make python-summary
```

Dependencies: `pip install numpy scipy tqdm`

No linter is configured in this repository.

## Architecture

All logic lives in `partial_correlation/core.py`. The package exports everything through `partial_correlation/__init__.py`.

**Data flow:**
1. `read_table(path)` parses the six-column ASCII format (`X censX Y censY Z censZ`) into `(values, censoring)` NumPy arrays.
2. Input values are negated internally to convert left-censored upper limits to right-censoring convention. Do **not** pre-negate data.
3. `_build_c_matrices()` constructs three `(n, n)` comparison matrices from the negated data.
4. `_kendall_tau()` computes the three pairwise tau values from those matrices.
5. `_compute_an()` computes the variance via an O(n⁴) triple loop — the bottleneck; `--progress` adds a tqdm bar to stderr.
6. `PartialKendallResult` (frozen dataclass) holds all outputs.

**Public API surface** (three entry points for different input shapes):
- `partial_kendall_tau(x, cens_x, y, cens_y, z, cens_z)` — separate 1-D arrays
- `partial_kendall_tau_table(values, censoring)` — `(n, 3)` arrays
- `partial_kendall_tau_from_file(path)` — file path; subject to `max_rows=500` cap (matches the original Fortran COMMON-block limit; in-memory functions have no cap)

**CLI** is `partial_correlation/__main__.py`, which calls `main()` from `core.py`. If no path argument is given, one line is read from stdin (legacy behavior).

## Input file format

Six whitespace-delimited columns, no header: `X censX Y censY Z censZ`. Censor flags: `1` = detection, `0` = upper limit. Minimum 4 rows, default cap 500 rows.

## Tests

- `tests/test_python_api.py` — unit/regression tests for all three API entry points
- `tests/test_python_cli.py` — CLI subprocess tests covering the bundled fixture, the Merloni 2003 dataset (upper-limit branches), and stdin-path handling
- `tests/pytest_helpers.py` — shared helpers and fixture path constants
- `data/test01.dat` — bundled 50-row all-detections sample (`censX = censY = censZ = 1` throughout); does **not** exercise upper-limit branches. Regenerate with `make gendata`. `gendata.py` produces a synthetic dataset where the X-Y correlation is entirely driven by Z.
- `data/merloni2003.dat` — Merloni 2003 dataset; `test_python_cli.py::test_python_cli_matches_merloni_regression` covers the censored-data (upper-limit) branches that `test01.dat` misses.

## Statistical caveat

The reported sigma and null-hypothesis probability use the paper's **asymptotic normal** approximation. Treat results as large-sample approximations, not exact small-sample p-values; accuracy improves noticeably with larger samples.

## Known limitation / open TODO

`_compute_an` is O(n⁴) pure Python; a C extension is a planned optimization.
