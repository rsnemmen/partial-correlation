#!/usr/bin/env bash

extract_colon_value() {
  local file=$1
  local pattern=$2
  local value

  value=$(awk -v pattern="$pattern" '
    index($0, pattern) {
      sub(/^[^:]*:[[:space:]]*/, "", $0)
      gsub(/[[:space:]]/, "", $0)
      print $0
      exit
    }
  ' "$file")
  if [[ -z "${value:-}" ]]; then
    printf 'ERROR: missing "%s" in %s\n' "$pattern" "$file" >&2
    exit 1
  fi

  printf '%s\n' "$value"
}

extract_equals_value() {
  local file=$1
  local pattern=$2
  local value

  value=$(awk -v pattern="$pattern" '
    index($0, pattern) {
      sub(/^[^=]*=[[:space:]]*/, "", $0)
      gsub(/[[:space:]]/, "", $0)
      print $0
      exit
    }
  ' "$file")
  if [[ -z "${value:-}" ]]; then
    printf 'ERROR: missing "%s" in %s\n' "$pattern" "$file" >&2
    exit 1
  fi

  printf '%s\n' "$value"
}

extract_first_number() {
  local file=$1
  local pattern=$2
  local value

  value=$(awk -v pattern="$pattern" '
    index($0, pattern) {
      if (match($0, /[-+]?[0-9]*\.?[0-9]+([Ee][-+]?[0-9]+)?/)) {
        print substr($0, RSTART, RLENGTH)
        exit
      }
    }
  ' "$file")
  if [[ -z "${value:-}" ]]; then
    printf 'ERROR: missing numeric value for "%s" in %s\n' "$pattern" "$file" >&2
    exit 1
  fi

  printf '%s\n' "$value"
}

extract_message() {
  local file=$1
  local value

  value=$(awk '
    /Zero partial correlation rejected at level 0\.05|Null hypothesis cannot be rejected!/ {
      sub(/^[[:space:]]+/, "")
      print
      exit
    }
  ' "$file")
  if [[ -z "${value:-}" ]]; then
    printf 'ERROR: missing significance message in %s\n' "$file" >&2
    exit 1
  fi

  printf '%s\n' "$value"
}

assert_close() {
  local label=$1
  local actual=$2
  local expected=$3
  local tol=$4

  awk -v label="$label" -v actual="$actual" -v expected="$expected" -v tol="$tol" '
    BEGIN {
      diff = actual - expected
      if (diff < 0) {
        diff = -diff
      }
      if (diff > tol) {
        printf "FAIL: %s expected %s got %s (|diff|=%g > %g)\n", label, expected, actual, diff, tol > "/dev/stderr"
        exit 1
      }
      printf "ok - %s = %s\n", label, actual
    }
  '
}

assert_equal() {
  local label=$1
  local actual=$2
  local expected=$3

  if [[ "$actual" != "$expected" ]]; then
    printf 'FAIL: %s expected "%s" got "%s"\n' "$label" "$expected" "$actual" >&2
    exit 1
  fi

  printf 'ok - %s = %s\n' "$label" "$actual"
}

assert_less_equal() {
  local label=$1
  local actual=$2
  local limit=$3

  awk -v label="$label" -v actual="$actual" -v limit="$limit" '
    BEGIN {
      if (actual > limit) {
        printf "FAIL: %s expected <= %s got %s\n", label, limit, actual > "/dev/stderr"
        exit 1
      }
      printf "ok - %s = %s (<= %s)\n", label, actual, limit
    }
  '
}
