# Copilot instructions for `partial_correlation`

## Build, test, and lint commands

- **Build the Fortran executable:** `./make.sh`
- **Direct build equivalent:** `gfortran -O cens_tau.f -o cens_tau`
- **Run the main sample regression:** `printf 'test01.dat\n' | ./cens_tau`
- **Run a lightweight single-check regression:** `printf 'test01.dat\n' | ./cens_tau | grep -E 'Partial Kendalls tau|Zero partial correlation'`
- **Inspect the stable summary lines from the sample regression:** `printf 'test01.dat\n' | ./cens_tau | grep -E 'Tau\\(|Partial Kendalls tau|Square root of variance|Zero partial correlation|Probability of null hypothesis'`
- **Generate a fresh synthetic dataset:** `python gendata.py`
- **Linting:** no linter is configured in this repository.

There is no automated multi-test suite in this repository. `test01.dat` and `test01.txt` are the closest thing to a regression fixture, but exact prompt text, spacing, and floating-point formatting can vary by compiler/runtime. Prefer checking the reported tau values and significance message over requiring a byte-for-byte match.

The shipped regression fixture is an all-detections case (`censX = censY = censZ = 1` throughout `test01.dat`). It is useful for basic regressions, but it does **not** exercise the upper-limit branches of the censored-data algorithm.

## High-level architecture

- `cens_tau.f` contains the entire analysis program. The `partial_tau` program reads a data filename from standard input, loads the dataset into fixed-size COMMON blocks, computes the three pairwise Kendall tau values, then derives the partial Kendall tau and its significance.
- The implementation follows the method described in `9508018v1.pdf` (Akritas & Siebert): it tests whether the population partial Kendall tau between X and Y is zero after controlling for Z, which is the use case for removing distance/redshift-driven correlations in flux-limited astronomy samples.
- The computational flow inside `cens_tau.f` is:
  1. main program reads the six-column ASCII dataset into `dat(500,3)` and `idat(500,3)`
  2. `tau(k,l)` and `h(k,l,i,j)` compute pairwise Kendall tau values for each variable pair
  3. `tau123(res)` combines those pairwise taus into the partial Kendall tau
  4. `sigma(sigres)` calls `an()` to compute the variance term used for the reported significance
- `an()` is the expensive part of the run. Its nested loops make variance estimation much slower than the initial tau calculation, and the printed counter (`1` through `ntot`) is expected progress output rather than debugging noise.
- The reported sigma and null-hypothesis probability come from the paper's **asymptotic normal** test. Treat them as large-sample approximations rather than exact small-sample p-values; the paper's simulations show the approximation improves noticeably with larger sample sizes.
- `gendata.py` is a standalone helper that writes `test01.dat`, a synthetic dataset where the observed X-Y correlation is driven by their shared dependence on Z.
- The `.dat` files in the repository are analysis inputs; the program itself does not encode dataset names or dataset-specific logic.

## Key conventions

- Input files must be whitespace-delimited ASCII with **exactly six columns in this order**: `X censX Y censY Z censZ`. The README explicitly says there should be **no header row**.
- Censoring flags use `1` for a detection and `0` for an upper limit.
- Variable roles are positional, not inferred: column 1 is the independent variable, column 3 is the dependent variable, and column 5 is the control/test variable. If a change requires different semantics, update the `k1`, `k2`, and `k3` assignments in `cens_tau.f` consistently with the rest of the formulas.
- The code negates all three numeric columns immediately after reading them to convert astronomy's usual **left-censored upper limits** into the **right-censoring** convention used by the statistical derivation. That sign flip is part of the algorithm, not dead code. If you are working with logged data, the paper's convention is to take logs first and only then apply the sign flip.
- Storage is hard-limited to **500 rows** by the COMMON-block arrays. Any work on larger datasets requires changing the array dimensions and reviewing every loop that depends on `ntot`.
- The program is interactive by default and asks for the input filename on stdin. For automation and tests, pipe the filename instead of trying to pass it as a CLI argument.
