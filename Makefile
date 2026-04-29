FC = gfortran
FFLAGS = -O
PYTHON ?= python
PYTEST ?= $(PYTHON) -m pytest
PYTHON_PROGRAM := $(PYTHON) -m partial_correlation

PROGRAM := cens_tau
SOURCE := cens_tau.f
DATA_DIR := data
SAMPLE_DATA := $(DATA_DIR)/test01.dat
FORTRAN_TEST_SCRIPTS := tests/test_test01.sh tests/test_merloni2003_table2_row1.sh
PYTHON_TESTS := tests/test_python_api.py tests/test_python_cli.py
SUMMARY_PATTERN := Tau\(|Partial Kendalls tau|Square root of variance|Zero partial correlation|Probability of null hypothesis

.PHONY: all build sample run summary python-sample python-summary python-test test gendata clean

all: build

build: $(PROGRAM)

$(PROGRAM): $(SOURCE)
	$(FC) $(FFLAGS) $< -o $@

sample: $(PROGRAM)
	printf '%s\n' '$(SAMPLE_DATA)' | ./$(PROGRAM)

run: sample

summary: $(PROGRAM)
	printf '%s\n' '$(SAMPLE_DATA)' | ./$(PROGRAM) | grep -E '$(SUMMARY_PATTERN)'

python-sample:
	$(PYTHON_PROGRAM) $(SAMPLE_DATA)

python-summary:
	$(PYTHON_PROGRAM) $(SAMPLE_DATA) | grep -E '$(SUMMARY_PATTERN)'

python-test:
	$(PYTEST) $(PYTHON_TESTS)

test: $(PROGRAM)
	set -e; \
	first=1; \
	for script in $(FORTRAN_TEST_SCRIPTS); do \
		if [ $$first -eq 0 ]; then printf '\n'; fi; \
		bash $$script; \
		first=0; \
	done; \
	printf '\n'; \
	$(PYTEST) $(PYTHON_TESTS)

gendata:
	$(PYTHON) gendata.py

clean:
	rm -f $(PROGRAM)
