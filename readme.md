# Partial correlation coefficient and significance for censored data

This branch is centered on the **Python implementation** of the partial Kendall tau test from [Akritas & Siebert (1996), *A test for partial correlation with censored astronomical data*](https://ui.adsabs.harvard.edu/abs/1996MNRAS.278..919A/abstract).

Use it when two variables appear correlated, but both may be driven by a third variable. A common astronomy example is checking whether two luminosities are still correlated after controlling for distance or redshift.

The repository still includes the original Fortran executable as a scientific reference and regression target, but the recommended user-facing path on this branch is the Python CLI and library. If you want the original **Fortran-only** workflow and documentation, use the `legacy` branch.

## What the Python implementation reports

The Python CLI and library compute:

- the three pairwise Kendall tau values `Tau(1,2)`, `Tau(1,3)`, and `Tau(2,3)`
- the partial Kendall tau between `X` and `Y` after controlling for `Z`
- a variance term, a significance statement, and the probability of the null hypothesis that the partial correlation is zero

The reported significance is the paper's asymptotic normal approximation, so it is most trustworthy for larger samples.

## Quickstart

From the repository root, install the required Python dependencies:

```sh
python -m pip install numpy scipy
```

If you want an optional progress bar for long runs, install `tqdm` as well:

```sh
python -m pip install tqdm
```

Run the bundled sample fixture with the Python CLI:

```sh
python -m partial_correlation data/test01.dat
```

If you only want the stable summary lines:

```sh
make python-summary
```

For the file-based Python API:

```python
from partial_correlation import partial_kendall_tau_from_file

result = partial_kendall_tau_from_file("data/test01.dat")
print(result.partial_tau, result.sigma, result.null_hypothesis_probability)
```

## Walkthrough: run the test on your own data

If you already have a dataset and want to apply the test, this is the shortest reliable Python-first path.

### 1. Prepare a six-column ASCII file

Your input file must be plain text, whitespace-delimited, and have exactly six columns in this order:

```text
X censX Y censY Z censZ
```

This line shows the required column order only. Do **not** include it as a header row in the file.

Column meanings:

- `X`: first variable
- `Y`: second variable
- `Z`: control variable
- `censX`, `censY`, `censZ`: censor flags, where `1` means a detection and `0` means an upper limit

The reader enforces:

- no header row
- no comment lines
- no extra columns
- at least 4 data rows
- at most 500 rows by default for file-based reads
- malformed rows or invalid censor flags raise an error

Example:

```text
26.9800 1 44.4340 0 -1.0714 1
27.1200 1 44.9010 1 -0.9500 1
26.4000 0 44.1000 1 -1.2200 1
```

If all of your points are detections, the censor arrays are just all ones. For example, with NumPy:

```python
import numpy as np

cens_x = np.ones_like(x, dtype=int)
cens_y = np.ones_like(y, dtype=int)
cens_z = np.ones_like(z, dtype=int)

np.savetxt(
    fileout,
    np.column_stack((x, cens_x, y, cens_y, z, cens_z)),
    fmt="%10.4f %i %10.4f %i %10.4f %i",
)
```

### 2. Run the Python CLI on the file

```sh
python -m partial_correlation path/to/your-data.dat
```

If you prefer a stdin-driven flow closer to the legacy executable, you can pipe the path instead:

```sh
printf '%s\n' 'path/to/your-data.dat' | python -m partial_correlation
```

For long datasets, you can show a tqdm progress bar while computing the variance term:

```sh
python -m partial_correlation --progress path/to/your-data.dat
```

The progress bar is opt-in and is written to standard error, so the normal report on standard output stays unchanged.

If you need to raise the default 500-row guardrail for file-based reads:

```sh
python -m partial_correlation --max-rows 2000 path/to/your-data.dat
```

If you are calling the Python API directly, you can disable the file-reader cap entirely with `max_rows=None`:

```python
from partial_correlation import partial_kendall_tau_from_file

result = partial_kendall_tau_from_file("path/to/your-data.dat", max_rows=None)
```

### 3. Read the key output lines

The most important lines are:

- `--> Partial Kendalls tau:`: the partial correlation between `X` and `Y` after controlling for `Z`
- `Probability of null hypothesis`: the reported p-value-like probability for zero partial correlation
- `Zero partial correlation rejected at level ...`: a significance summary derived from the asymptotic test

For scripted runs, this command keeps just the stable summary lines:

```sh
python -m partial_correlation path/to/your-data.dat | grep -E 'Tau\(|Partial Kendalls tau|Square root of variance|Zero partial correlation|Probability of null hypothesis'
```

### 4. Use the library API when your data are already in memory

For array inputs:

```python
from partial_correlation import partial_kendall_tau

result = partial_kendall_tau(x, cens_x, y, cens_y, z, cens_z)
print(result.partial_tau)
```

For an already loaded `(n, 3)` value table plus `(n, 3)` censor table:

```python
from partial_correlation import partial_kendall_tau_table

result = partial_kendall_tau_table(values, censoring)
```

The in-memory API is not tied to the file reader's default 500-row limit.

## Python interfaces

The package exposes these main entry points:

- `read_table(path)` to load the six-column ASCII file into `(values, censoring)` arrays
- `partial_kendall_tau(...)` for separate in-memory `x`, `y`, `z` arrays plus censor flags
- `partial_kendall_tau_table(values, censoring)` for `(n, 3)` arrays
- `partial_kendall_tau_from_file(path)` as the file-based convenience wrapper
- `format_report(path, result)` if you want the CLI-style text report from Python code

The command-line interface is:

```sh
python -m partial_correlation [--progress] [--max-rows N] [path]
```

If `path` is omitted, the CLI reads a single path from standard input.

## Input and interpretation notes

- Variable roles are positional. The code does not infer them from names or headers.
- Both implementations negate all three numeric columns internally to convert astronomy's usual left-censored upper limits into the right-censoring convention used by the statistical derivation. Do **not** negate your data before writing the file.
- If you work in log space, take logarithms first and then write those logged values to the input file. The implementation handles the internal sign flip itself.
- The bundled sample fixture `data/test01.dat` is useful for baseline checks, but it contains detections only and does not exercise the upper-limit branches of the censored-data algorithm by itself.

## Useful commands on this branch

| Command | What it does |
| --- | --- |
| `python -m partial_correlation data/test01.dat` | Run the Python CLI on the bundled sample |
| `make python-sample` | Run the Python CLI on `data/test01.dat` |
| `make python-summary` | Print only the stable Python summary lines |
| `make python-test` | Run the pytest-based Python regressions |
| `make test` | Run the full regression suite |
| `make gendata` | Regenerate `data/test01.dat` with synthetic data |
| `make` | Build the bundled Fortran reference executable |
| `make sample` | Run the bundled sample through `./cens_tau` |
| `make summary` | Print only the stable Fortran summary lines |

## Fortran reference and the `legacy` branch

This branch still ships the original `cens_tau.f` program and keeps it in the regression suite for parity with the Python port.

If you specifically want the original **Fortran-first** experience, including the older build/run workflow and README structure, use the `legacy` branch instead:

```sh
git switch legacy
```

or browse that branch on GitHub.

## Regression checks and fixtures

`make test` runs four checks:

1. the bundled fixture `data/test01.dat`, compared against `data/test01.txt` by the legacy Fortran shell regression
2. a normalized fixture derived from `data/merloni2003.dat`, checked against the repository's current fiducial output for the first Table 2 setup by the legacy Fortran shell regression
3. the Python CLI regressions under `pytest`, covering the bundled and normalized fixtures plus stdin-path handling
4. the Python library/API regressions under `pytest`

If you only want the Python-side automated checks, run:

```sh
make python-test
```

If you want to inspect the stable summary values from the bundled sample fixture:

```sh
make python-summary
```

If you want to regenerate the synthetic sample fixture, run:

```sh
make gendata
```

This overwrites `data/test01.dat`.

## Citation

If you use this code in published work, please cite the following papers:

- [Akritas & Siebert (1996), *A test for partial correlation with censored astronomical data*](https://ui.adsabs.harvard.edu/abs/1996MNRAS.278..919A/abstract)
- [Nemmen et al. (2012), *Science*, 338, 1445](http://labs.adsabs.harvard.edu/adsabs/abs/2012Sci...338.1445N/)
