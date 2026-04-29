#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
python_bin="${PYTHON:-python}"
fixture="$repo_root/data/test01.dat"
reference="$repo_root/data/test01.txt"
raw_source="$repo_root/data/merloni2003.dat"
prepare_script="$repo_root/tests/prepare_merloni2003_row1.py"
tolerance="1e-6"
probability_tolerance="1e-10"
order_tolerance="1e-9"
source "$repo_root/tests/regression_helpers.sh"

summary_value() {
  local summary=$1
  local key=$2

  printf '%s\n' "$summary" | tr ' ' '\n' | awk -F= -v key="$key" '$1 == key { print $2; exit }'
}

tmp_output=$(mktemp "${TMPDIR:-/tmp}/python-cens-tau-test01.XXXXXX")
tmp_stdin_output=$(mktemp "${TMPDIR:-/tmp}/python-cens-tau-stdin.XXXXXX")
tmp_fixture=$(mktemp "${TMPDIR:-/tmp}/python-merloni-row1.XXXXXX")
tmp_reordered_fixture=$(mktemp "${TMPDIR:-/tmp}/python-merloni-row1-reordered.XXXXXX")
tmp_merloni_output=$(mktemp "${TMPDIR:-/tmp}/python-merloni-row1-output.XXXXXX")
tmp_reordered_output=$(mktemp "${TMPDIR:-/tmp}/python-merloni-row1-reordered-output.XXXXXX")
trap 'rm -f "$tmp_output" "$tmp_stdin_output" "$tmp_fixture" "$tmp_reordered_fixture" "$tmp_merloni_output" "$tmp_reordered_output"' EXIT

"$python_bin" -m partial_correlation "$fixture" > "$tmp_output"
printf '%s\n' "$fixture" | "$python_bin" -m partial_correlation > "$tmp_stdin_output"

actual_tau12=$(extract_colon_value "$tmp_output" 'Tau(1,2):')
expected_tau12=$(extract_colon_value "$reference" 'Tau(1,2):')
actual_tau13=$(extract_colon_value "$tmp_output" 'Tau(1,3):')
expected_tau13=$(extract_colon_value "$reference" 'Tau(1,3):')
actual_tau23=$(extract_colon_value "$tmp_output" 'Tau(2,3):')
expected_tau23=$(extract_colon_value "$reference" 'Tau(2,3):')
actual_partial_tau=$(extract_colon_value "$tmp_output" 'Partial Kendalls tau:')
expected_partial_tau=$(extract_colon_value "$reference" 'Partial Kendalls tau:')
actual_sigma=$(extract_colon_value "$tmp_output" 'Square root of variance (sigma):')
expected_sigma=$(extract_colon_value "$reference" 'Square root of variance (sigma):')
actual_message=$(extract_message "$tmp_output")
expected_message=$(extract_message "$reference")
actual_probability=$(extract_equals_value "$tmp_output" 'Probability of null hypothesis')
expected_probability=$(extract_equals_value "$reference" 'Probability of null hypothesis')
stdin_partial_tau=$(extract_colon_value "$tmp_stdin_output" 'Partial Kendalls tau:')

assert_close "Python Tau(1,2)" "$actual_tau12" "$expected_tau12" "$tolerance"
assert_close "Python Tau(1,3)" "$actual_tau13" "$expected_tau13" "$tolerance"
assert_close "Python Tau(2,3)" "$actual_tau23" "$expected_tau23" "$tolerance"
assert_close "Python Partial Kendalls tau" "$actual_partial_tau" "$expected_partial_tau" "$tolerance"
assert_close "Python Square root of variance (sigma)" "$actual_sigma" "$expected_sigma" "$tolerance"
assert_equal "Python significance message" "$actual_message" "$expected_message"
assert_close "Python Probability of null hypothesis" "$actual_probability" "$expected_probability" "$tolerance"
assert_close "Python stdin path partial tau" "$stdin_partial_tau" "$actual_partial_tau" "$order_tolerance"

summary=$("$python_bin" "$prepare_script" "$raw_source" "$tmp_fixture")
reordered_summary=$("$python_bin" "$prepare_script" --reverse-z-groups "$raw_source" "$tmp_reordered_fixture")

assert_equal "Python Merloni+2003 rows" "$(summary_value "$summary" rows)" "149"
assert_equal "Python Merloni+2003 reordered rows" "$(summary_value "$reordered_summary" rows)" "149"

"$python_bin" -m partial_correlation "$tmp_fixture" > "$tmp_merloni_output"
"$python_bin" -m partial_correlation "$tmp_reordered_fixture" > "$tmp_reordered_output"

actual_merloni_partial_tau=$(extract_colon_value "$tmp_merloni_output" 'Partial Kendalls tau:')
actual_merloni_sigma=$(extract_colon_value "$tmp_merloni_output" 'Square root of variance (sigma):')
actual_merloni_message=$(extract_message "$tmp_merloni_output")
actual_merloni_probability=$(extract_equals_value "$tmp_merloni_output" 'Probability of null hypothesis')
reordered_merloni_partial_tau=$(extract_colon_value "$tmp_reordered_output" 'Partial Kendalls tau:')
reordered_merloni_sigma=$(extract_colon_value "$tmp_reordered_output" 'Square root of variance (sigma):')

assert_close "Python Merloni+2003 row-order partial tau" "$actual_merloni_partial_tau" "$reordered_merloni_partial_tau" "$order_tolerance"
assert_close "Python Merloni+2003 row-order sigma" "$actual_merloni_sigma" "$reordered_merloni_sigma" "$order_tolerance"
assert_close "Python Merloni+2003 partial tau" "$actual_merloni_partial_tau" "0.267236739" "$tolerance"
assert_close "Python Merloni+2003 sigma" "$actual_merloni_sigma" "4.58830856E-02" "$tolerance"
assert_equal "Python Merloni+2003 significance message" "$actual_merloni_message" "Zero partial correlation rejected at level 0.05"
assert_close "Python Merloni+2003 probability of null hypothesis" "$actual_merloni_probability" "5.7353336267124159E-009" "$probability_tolerance"

printf 'PASS: Python CLI matches the Fortran regression fixtures\n'
