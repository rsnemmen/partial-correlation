FC = gfortran
FFLAGS = -O
PYTHON ?= python

PROGRAM := cens_tau
SOURCE := cens_tau.f
DATA_DIR := data
SAMPLE_DATA := $(DATA_DIR)/test01.dat
TEST_SCRIPTS := tests/test_test01.sh tests/test_merloni2003_table2_row1.sh
SUMMARY_PATTERN := Tau\(|Partial Kendalls tau|Square root of variance|Zero partial correlation|Probability of null hypothesis

.PHONY: all build sample run summary test gendata clean

all: build

build: $(PROGRAM)

$(PROGRAM): $(SOURCE)
	$(FC) $(FFLAGS) $< -o $@

sample: $(PROGRAM)
	printf '%s\n' '$(SAMPLE_DATA)' | ./$(PROGRAM)

run: sample

summary: $(PROGRAM)
	printf '%s\n' '$(SAMPLE_DATA)' | ./$(PROGRAM) | grep -E '$(SUMMARY_PATTERN)'

test: $(PROGRAM)
	first=1; \
	for script in $(TEST_SCRIPTS); do \
		if [ $$first -eq 0 ]; then printf '\n'; fi; \
		bash $$script; \
		first=0; \
	done

gendata:
	$(PYTHON) gendata.py

clean:
	rm -f $(PROGRAM)
