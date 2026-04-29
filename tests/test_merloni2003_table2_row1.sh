#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
program="$repo_root/cens_tau"
raw_source="$repo_root/data/merloni2003.dat"
prepare_script="$repo_root/tests/prepare_merloni2003_row1.py"
python_bin="${PYTHON:-python}"

paper_partial_tau="0.255"
paper_sigma="0.0414"
paper_tau_tolerance="0.015"
paper_sigma_tolerance="0.005"
paper_pnull_upper_bound="1e-8"
order_tolerance="1e-9"

source "$repo_root/tests/regression_helpers.sh"

summary_value() {
  local summary=$1
  local key=$2

  printf '%s\n' "$summary" | tr ' ' '\n' | awk -F= -v key="$key" '$1 == key { print $2; exit }'
}

if [[ ! -f "$raw_source" ]]; then
  printf 'ERROR: missing raw Merloni source file: %s\n' "$raw_source" >&2
  exit 1
fi

tmp_fixture=$(mktemp "${TMPDIR:-/tmp}/merloni-row1.XXXXXX")
tmp_reordered_fixture=$(mktemp "${TMPDIR:-/tmp}/merloni-row1-reordered.XXXXXX")
tmp_output=$(mktemp "${TMPDIR:-/tmp}/merloni-row1-output.XXXXXX")
tmp_reordered_output=$(mktemp "${TMPDIR:-/tmp}/merloni-row1-reordered-output.XXXXXX")
trap 'rm -f "$tmp_fixture" "$tmp_reordered_fixture" "$tmp_output" "$tmp_reordered_output"' EXIT

summary=$("$python_bin" "$prepare_script" "$raw_source" "$tmp_fixture")
reordered_summary=$("$python_bin" "$prepare_script" --reverse-z-groups "$raw_source" "$tmp_reordered_fixture")

assert_equal "Merloni rows" "$(summary_value "$summary" rows)" "149"
assert_equal "Merloni radio upper limits" "$(summary_value "$summary" radio_upper_limits)" "20"
assert_equal "Merloni X-ray upper limits" "$(summary_value "$summary" xray_upper_limits)" "14"
assert_equal "Merloni Z upper limits" "$(summary_value "$summary" z_upper_limits)" "0"
assert_equal "Merloni reordered rows" "$(summary_value "$reordered_summary" rows)" "149"

printf '%s\n' "$tmp_fixture" | "$program" > "$tmp_output"
printf '%s\n' "$tmp_reordered_fixture" | "$program" > "$tmp_reordered_output"

actual_partial_tau=$(extract_colon_value "$tmp_output" 'Partial Kendalls tau:')
actual_sigma=$(extract_colon_value "$tmp_output" 'Square root of variance (sigma):')
actual_message=$(extract_message "$tmp_output")
actual_probability=$(extract_equals_value "$tmp_output" 'Probability of null hypothesis')

reordered_partial_tau=$(extract_colon_value "$tmp_reordered_output" 'Partial Kendalls tau:')
reordered_sigma=$(extract_colon_value "$tmp_reordered_output" 'Square root of variance (sigma):')

assert_close "Merloni row-order partial tau" "$actual_partial_tau" "$reordered_partial_tau" "$order_tolerance"
assert_close "Merloni row-order sigma" "$actual_sigma" "$reordered_sigma" "$order_tolerance"
assert_close "Merloni partial tau" "$actual_partial_tau" "$paper_partial_tau" "$paper_tau_tolerance"
assert_close "Merloni sigma" "$actual_sigma" "$paper_sigma" "$paper_sigma_tolerance"
assert_equal "Merloni significance message" "$actual_message" "Zero partial correlation rejected at level 0.05"
assert_less_equal "Merloni probability of null hypothesis" "$actual_probability" "$paper_pnull_upper_bound"

printf 'PASS: Merloni 2003 Table 2 row 1 reproduced from %s within tolerances\n' "${raw_source#$repo_root/}"
