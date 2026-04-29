# Copilot instructions for `partial_correlation`

## Build, test, and lint commands

- **Build the Fortran executable:** `make`
- **Direct build equivalent:** `gfortran -O cens_tau.f -o cens_tau`
- **Run the legacy Fortran sample:** `make sample`
- **Inspect the stable Fortran summary lines:** `make summary`
- **Run the Python sample CLI:** `make python-sample`
- **Inspect the stable Python summary lines:** `make python-summary`
- **Run the full regression suite:** `make test`
- **Run the Python CLI regression only:** `bash tests/test_python_cli.sh`
- **Run the Python API regression only:** `bash tests/test_python_api.sh`
- **Generate a fresh synthetic dataset:** `make gendata`
- **Run the Python CLI directly:** `python -m partial_correlation data/test01.dat`
- **Linting:** no linter is configured in this repository.

The repository now has an automated multi-check regression suite. `make test` runs the legacy Fortran fixture checks plus Python CLI/API parity checks against the same scientific outputs. Exact prompt text, spacing, and floating-point formatting can still vary slightly by runtime, so prefer checking the reported tau values, sigma, and significance message over requiring byte-for-byte output identity.

The bundled sample fixture `data/test01.dat` is an all-detections case (`censX = censY = censZ = 1` throughout). It is useful for basic regressions, but it does **not** exercise the upper-limit branches of the censored-data algorithm by itself; the Merloni-derived regression fixture covers censored radio/X-ray values.

## High-level architecture

- The repository now contains **two implementations** of the same method:
  1. `cens_tau.f`: the legacy Fortran reference implementation
  2. `partial_correlation/core.py`: the NumPy/SciPy-backed Python port
- `cens_tau.f` still serves as the scientific reference implementation. The `partial_tau` program reads a data filename from standard input, loads the dataset into fixed-size COMMON blocks, computes the three pairwise Kendall tau values, then derives the partial Kendall tau and its significance.
- `partial_correlation/core.py` exposes the Python-facing API:
  - `read_table(path)` loads the six-column ASCII file into `(values, censoring)` arrays
  - `partial_kendall_tau(...)` accepts in-memory arrays for `x`, `y`, `z` and their censor flags
  - `partial_kendall_tau_table(values, censoring)` works on `(n, 3)` tables
  - `partial_kendall_tau_from_file(path)` is the file-based convenience wrapper
  - `format_report(...)` and `python -m partial_correlation` provide a CLI report similar to the Fortran output
- The implementation follows the method described in `9508018v1.pdf` (Akritas & Siebert): it tests whether the population partial Kendall tau between X and Y is zero after controlling for Z, which is the use case for removing distance/redshift-driven correlations in flux-limited astronomy samples.
- Both implementations share the same computational flow:
  1. read the six-column dataset into three values plus three censor flags
  2. convert astronomy's left-censored inputs into right-censoring via an internal sign flip
  3. compute the three pairwise Kendall tau values
  4. derive the partial Kendall tau
  5. compute the asymptotic variance term and null-hypothesis probability
- In the Python port, the pairwise comparison matrices are built with NumPy array operations, and the normal-tail probability is computed with `scipy.special.erfc`.
- `an()` remains the expensive part of the algorithm in both implementations. The Python port reduces some overhead with NumPy-backed matrices, but the variance calculation is still fundamentally expensive because the statistical method itself is combinatorial.
- The reported sigma and null-hypothesis probability come from the paper's **asymptotic normal** test. Treat them as large-sample approximations rather than exact small-sample p-values; the paper's simulations show the approximation improves noticeably with larger sample sizes.
- `gendata.py` is a standalone helper that writes `test01.dat`, a synthetic dataset where the observed X-Y correlation is driven by their shared dependence on Z.
- The `.dat` files in the repository are analysis inputs; neither implementation encodes dataset names or dataset-specific logic.

## Key conventions

- Input files must be whitespace-delimited ASCII with **exactly six columns in this order**: `X censX Y censY Z censZ`. The README explicitly says there should be **no header row**.
- Censoring flags use `1` for a detection and `0` for an upper limit.
- Variable roles are positional, not inferred: column 1 is `X`, column 3 is `Y`, and column 5 is `Z`. If you change those semantics, update both the Fortran logic and the Python port consistently.
- Both implementations negate all three numeric columns internally to convert astronomy's usual **left-censored upper limits** into the **right-censoring** convention used by the statistical derivation. That sign flip is part of the algorithm, not dead code. If you are working with logged data, take logs first and let the implementation apply the sign flip internally.
- The Fortran program is interactive by default and asks for the input filename on stdin. The Python CLI accepts either a positional path argument or a single path on stdin.
- The file-based Python API defaults to the same **500-row** maximum as the Fortran implementation (`DEFAULT_MAX_FILE_ROWS = 500`) for parity and guardrails, although the in-memory Python functions are not tied to COMMON-block storage.
