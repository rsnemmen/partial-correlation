# Copilot instructions for `partial_correlation`

## Build, test, and lint commands

- **Run the full regression suite:** `make test`
- **Run the Python sample CLI:** `make python-sample`
- **Inspect the stable summary lines:** `make python-summary`
- **Run pytest directly:** `python -m pytest tests/test_python_api.py tests/test_python_cli.py`
- **Generate a fresh synthetic dataset:** `make gendata`
- **Run the Python CLI directly:** `python -m partial_correlation data/test01.dat`
- **Linting:** no linter is configured in this repository.

The original Fortran source (`cens_tau.f`) is preserved on the `legacy` branch and at the `fortran-final` tag for reference.

`make test` runs pytest-based CLI and API regressions against the same scientific outputs as the original Fortran. Exact prompt text, spacing, and floating-point formatting can vary slightly by runtime, so prefer checking reported tau values, sigma, and significance message over byte-for-byte output identity.

The bundled sample fixture `data/test01.dat` is an all-detections case (`censX = censY = censZ = 1` throughout). It is useful for basic regressions, but does **not** exercise the upper-limit branches of the censored-data algorithm; the Merloni-derived regression fixture covers censored radio/X-ray values.

## High-level architecture

- All logic lives in `partial_correlation/core.py`. The package exports everything through `partial_correlation/__init__.py`.
- `partial_correlation/core.py` exposes the Python-facing API:
  - `read_table(path)` loads the six-column ASCII file into `(values, censoring)` arrays
  - `partial_kendall_tau(...)` accepts in-memory arrays for `x`, `y`, `z` and their censor flags
  - `partial_kendall_tau_table(values, censoring)` works on `(n, 3)` tables
  - `partial_kendall_tau_from_file(path)` is the file-based convenience wrapper
  - `format_report(...)` and `python -m partial_correlation` provide a CLI report
- The implementation follows the method described in `9508018v1.pdf` (Akritas & Siebert): it tests whether the population partial Kendall tau between X and Y is zero after controlling for Z, removing distance/redshift-driven correlations in flux-limited astronomy samples.
- Computational flow: read six-column dataset → convert left-censored inputs to right-censoring via an internal sign flip → compute three pairwise Kendall tau values → derive the partial Kendall tau → compute the asymptotic variance term and null-hypothesis probability.
- Pairwise comparison matrices are built with NumPy array operations; the normal-tail probability is computed with `scipy.special.erfc`.
- `_compute_an()` is the expensive step — combinatorial O(n⁴) pure Python; a C extension is a planned optimization.
- The reported sigma and null-hypothesis probability come from the paper's **asymptotic normal** test. Treat them as large-sample approximations rather than exact small-sample p-values.
- `gendata.py` is a standalone helper that writes `test01.dat`, a synthetic dataset where the observed X-Y correlation is driven by their shared dependence on Z.

## Key conventions

- Input files must be whitespace-delimited ASCII with **exactly six columns in this order**: `X censX Y censY Z censZ`. No header row.
- Censoring flags: `1` = detection, `0` = upper limit.
- Variable roles are positional: column 1 is `X`, column 3 is `Y`, column 5 is `Z`.
- All three numeric columns are negated internally to convert astronomy's left-censored upper limits into right-censoring convention. That sign flip is part of the algorithm. If working with logged data, take logs first and let the implementation apply the sign flip internally.
- The file-based Python API defaults to a **500-row** maximum (`DEFAULT_MAX_FILE_ROWS = 500`) matching the original Fortran COMMON-block limit; in-memory functions have no cap.
