#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
program="$repo_root/cens_tau"
fixture="$repo_root/data/test01.dat"
reference="$repo_root/data/test01.txt"
tolerance="1e-6"
source "$repo_root/tests/regression_helpers.sh"

tmp_output=$(mktemp "${TMPDIR:-/tmp}/cens-tau-test01.XXXXXX")
trap 'rm -f "$tmp_output"' EXIT

printf '%s\n' "$fixture" | "$program" > "$tmp_output"

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
actual_sigres=$(extract_first_number "$tmp_output" 'Null hypothesis rejected at')
expected_sigres=$(extract_first_number "$reference" 'Null hypothesis rejected at')
actual_probability=$(extract_equals_value "$tmp_output" 'Probability of null hypothesis')
expected_probability=$(extract_equals_value "$reference" 'Probability of null hypothesis')

assert_close "Tau(1,2)" "$actual_tau12" "$expected_tau12" "$tolerance"
assert_close "Tau(1,3)" "$actual_tau13" "$expected_tau13" "$tolerance"
assert_close "Tau(2,3)" "$actual_tau23" "$expected_tau23" "$tolerance"
assert_close "Partial Kendalls tau" "$actual_partial_tau" "$expected_partial_tau" "$tolerance"
assert_close "Square root of variance (sigma)" "$actual_sigma" "$expected_sigma" "$tolerance"
assert_equal "significance message" "$actual_message" "$expected_message"
assert_close "Null hypothesis significance" "$actual_sigres" "$expected_sigres" "$tolerance"
assert_close "Probability of null hypothesis" "$actual_probability" "$expected_probability" "$tolerance"

printf 'PASS: %s matches %s within %s\n' "${fixture#$repo_root/}" "${reference#$repo_root/}" "$tolerance"
