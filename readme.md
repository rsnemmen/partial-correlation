# Partial correlation coefficient and significance for censored data

This repository contains a Fortran implementation of the partial Kendall tau test from [Akritas & Siebert (1996), *A test for partial correlation with censored astronomical data*](https://ui.adsabs.harvard.edu/abs/1996MNRAS.278..919A/abstract).

Use it when two variables appear correlated, but both may be driven by a third variable. A common astronomy example is checking whether two luminosities are still correlated after controlling for distance or redshift.

## What the program reports

The program computes:

- the three pairwise Kendall tau values `Tau(1,2)`, `Tau(1,3)`, and `Tau(2,3)`
- the partial Kendall tau between `X` and `Y` after controlling for `Z`
- a variance term, a significance statement, and the probability of the null hypothesis that the partial correlation is zero

The significance output is the paper's asymptotic normal approximation, so it is most trustworthy for larger samples.

## Build and quickstart

You need a Fortran compiler such as `gfortran`.

```sh
make
```

Common commands:

| Command | What it does |
| --- | --- |
| `make` | Build `./cens_tau` |
| `make sample` | Run the bundled sample fixture in `data/test01.dat` |
| `make summary` | Print only the stable summary lines from the sample run |
| `make python-sample` | Run the Python CLI on `data/test01.dat` |
| `make python-summary` | Print only the stable Python summary lines |
| `make python-test` | Run the pytest-based Python regressions |
| `make test` | Run the regression checks |
| `make gendata` | Regenerate `data/test01.dat` with synthetic data |
| `./make.sh` | Legacy build wrapper; still supported |

For a first run:

```sh
make
make summary
```

If you want the full sample output instead:

```sh
make sample
```

## Python library and CLI

The repository now also includes a NumPy/SciPy-backed Python port under `partial_correlation/`.

You need Python plus the `numpy` and `scipy` packages to use it. If you want an optional progress bar for long runs, install `tqdm` as well.

### Run the Python CLI

```sh
python -m partial_correlation data/test01.dat
```

or, if you want behavior closer to the Fortran executable, pipe the path on standard input:

```sh
printf '%s\n' 'data/test01.dat' | python -m partial_correlation
```

For long datasets, you can display a tqdm progress bar for the variance calculation:

```sh
python -m partial_correlation --progress path/to/your-data.dat
```

The progress bar is opt-in and is written to standard error, so the normal report on standard output stays unchanged.

For the stable summary lines only:

```sh
make python-summary
```

### Use the library API

```python
from partial_correlation import partial_kendall_tau_from_file

result = partial_kendall_tau_from_file("data/test01.dat")
print(result.partial_tau, result.sigma, result.null_hypothesis_probability)
```

If you want progress reporting from the library as well:

```python
result = partial_kendall_tau_from_file("data/test01.dat", progress=True)
```

If your data are already in memory, use the array-based entry point:

```python
from partial_correlation import partial_kendall_tau

result = partial_kendall_tau(x, cens_x, y, cens_y, z, cens_z)
```

## Walkthrough: run the test on your own data

If you already have a dataset and want to apply the partial correlation test, this is the shortest reliable path.

### 1. Prepare a six-column ASCII file

Your input file must be plain text, whitespace-delimited, and have exactly six columns in this order:

```text
X censX Y censY Z censZ
```

This line shows the required column order only. Do **not** include it as a header row in the file.

Column meanings:

- `X`: independent variable
- `Y`: dependent variable
- `Z`: control/test variable
- `censX`, `censY`, `censZ`: censor flags, where `1` means a detection and `0` means an upper limit

Rules the program enforces:

- no header row
- no comment lines
- no extra columns
- at least 4 data rows
- at most 500 data rows
- malformed rows or invalid censor flags stop the program with an error

Example:

```text
26.9800 1 44.4340 0 -1.0714 1
27.1200 1 44.9010 1 -0.9500 1
26.4000 0 44.1000 1 -1.2200 1
```

If all of your points are detections, the censor arrays are just all ones. For example, with NumPy:

```python
import numpy

censX = numpy.ones_like(X, dtype=int)
censY = numpy.ones_like(Y, dtype=int)
censZ = numpy.ones_like(Z, dtype=int)

numpy.savetxt(
    fileout,
    numpy.column_stack((X, censX, Y, censY, Z, censZ)),
    fmt="%10.4f %i %10.4f %i %10.4f %i",
)
```

### 2. Build the executable

```sh
make
```

### 3. Run the program on your file

The program is interactive: it asks for the input filename on standard input. You can either type the filename after starting it:

```sh
./cens_tau
```

or automate the prompt by piping the filename:

```sh
printf '%s\n' 'path/to/your-data.dat' | ./cens_tau
```

### 4. Read the key output lines

The most important lines are:

- `--> Partial Kendalls tau:`: the partial correlation between `X` and `Y` after controlling for `Z`
- `Probability of null hypothesis`: the reported p-value-like probability for zero partial correlation
- `Zero partial correlation rejected at level ...`: a significance summary derived from the asymptotic test

For scripted runs, this command keeps just the stable summary lines:

```sh
printf '%s\n' 'path/to/your-data.dat' | ./cens_tau | grep -E 'Tau\(|Partial Kendalls tau|Square root of variance|Zero partial correlation|Probability of null hypothesis'
```

## Input and interpretation notes

- Variable roles are positional. The program does not infer them from names or headers.
- The code negates all three numeric columns internally to convert astronomy's usual left-censored upper limits into the right-censoring convention used by the statistical derivation. Do **not** negate your data before writing the file.
- If you work in log space, take logarithms first and then write those logged values to the input file. The program handles the internal sign flip itself.
- The bundled regression fixture `data/test01.dat` is useful for baseline checks, but it contains detections only and does not exercise the upper-limit branches of the censored-data algorithm.

## Regression checks and fixtures

`make test` currently runs four checks:

1. the bundled fixture `data/test01.dat`, compared against `data/test01.txt` by the legacy Fortran shell regression
2. a normalized fixture derived from `data/merloni2003.dat`, checked against the repository's current fiducial output for the first Table 2 setup by the legacy Fortran shell regression
3. the Python CLI regressions under `pytest`, covering the bundled and normalized fixtures plus stdin-path handling
4. the Python library/API regressions under `pytest`

If you only want the Python-side automated checks, run:

```sh
make python-test
```

If you only want to inspect the stable summary values from the bundled sample fixture:

```sh
make summary
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
