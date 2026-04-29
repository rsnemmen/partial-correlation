FC = gfortran
FFLAGS = -O
PYTHON ?= python

PROGRAM := cens_tau
SOURCE := cens_tau.f
SAMPLE_DATA := test01.dat
SUMMARY_PATTERN := Tau\(|Partial Kendalls tau|Square root of variance|Zero partial correlation|Probability of null hypothesis

.PHONY: all build sample run test gendata clean

all: build

build: $(PROGRAM)

$(PROGRAM): $(SOURCE)
	$(FC) $(FFLAGS) $< -o $@

sample: $(PROGRAM)
	printf '%s\n' '$(SAMPLE_DATA)' | ./$(PROGRAM)

run: sample

test: $(PROGRAM)
	printf '%s\n' '$(SAMPLE_DATA)' | ./$(PROGRAM) | grep -E '$(SUMMARY_PATTERN)'

gendata:
	$(PYTHON) gendata.py

clean:
	rm -f $(PROGRAM)
