#!/usr/bin/env bash
# Assertion helpers for speckit-security tests.
#
# Usage (inside a test file):
#   source "$(dirname "$0")/../lib/assert.sh"
#
# Every helper prints a one-line failure message and exits non-zero on
# failure. On success, helpers print nothing — the test file itself
# prints its summary line at the end.

set -euo pipefail

# assert_equals <expected> <actual> <label>
assert_equals() {
  local expected="$1"
  local actual="$2"
  local label="${3:-values}"
  if [ "$expected" != "$actual" ]; then
    echo "✗ ${label}: expected '${expected}', got '${actual}'" >&2
    exit 1
  fi
}

# assert_contains <file> <needle> <label>
assert_contains() {
  local file="$1"
  local needle="$2"
  local label="${3:-output}"
  if ! grep -qF "$needle" "$file"; then
    echo "✗ ${label}: '${needle}' not found in ${file}" >&2
    echo "--- ${file} ---" >&2
    cat "$file" >&2
    echo "--- end ---" >&2
    exit 1
  fi
}

# assert_not_contains <file> <needle> <label>
assert_not_contains() {
  local file="$1"
  local needle="$2"
  local label="${3:-output}"
  if grep -qF "$needle" "$file"; then
    echo "✗ ${label}: '${needle}' unexpectedly found in ${file}" >&2
    exit 1
  fi
}

# assert_file_exists <path> <label>
assert_file_exists() {
  local path="$1"
  local label="${2:-file}"
  if [ ! -f "$path" ]; then
    echo "✗ ${label}: ${path} does not exist" >&2
    exit 1
  fi
}

# assert_exit_nonzero <exit_code> <label>
assert_exit_nonzero() {
  local code="$1"
  local label="${2:-exit}"
  if [ "$code" = "0" ]; then
    echo "✗ ${label}: expected non-zero exit, got 0" >&2
    exit 1
  fi
}
