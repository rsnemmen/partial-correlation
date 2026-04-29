PYTHON ?= python
PYTEST ?= $(PYTHON) -m pytest
PYTHON_PROGRAM := $(PYTHON) -m partial_correlation

DATA_DIR := data
SAMPLE_DATA := $(DATA_DIR)/test01.dat
PYTHON_TESTS := tests/test_python_api.py tests/test_python_cli.py
SUMMARY_PATTERN := Tau\(|Partial Kendalls tau|Square root of variance|Zero partial correlation|Probability of null hypothesis

.PHONY: all python-sample python-summary python-test test gendata clean

all: python-test

python-sample:
	$(PYTHON_PROGRAM) $(SAMPLE_DATA)

python-summary:
	$(PYTHON_PROGRAM) $(SAMPLE_DATA) | grep -E '$(SUMMARY_PATTERN)'

python-test:
	$(PYTEST) $(PYTHON_TESTS)

test: python-test

gendata:
	$(PYTHON) gendata.py

clean:
	rm -rf partial_correlation/__pycache__ tests/__pycache__
