#!/usr/bin/env bash
# speckit-security test runner.
#
# Runs every tests/<suite>/*.sh file and prints a pass/fail summary.
# Zero runtime dependencies beyond POSIX bash.
#
# Usage:
#   bash tests/run.sh              # all suites
#   bash tests/run.sh gate-check   # one suite
#   bash tests/run.sh gate-check/pass-clean.sh  # one test

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$TESTS_DIR"

filter="${1:-}"
passed=0
failed=0
failed_tests=()

run_test() {
  local test_file="$1"
  if bash "$test_file"; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    failed_tests+=("$test_file")
  fi
}

echo "=============================================="
echo " speckit-security test runner"
echo "=============================================="
echo

if [ -n "$filter" ]; then
  if [ -f "$filter" ]; then
    run_test "$filter"
  elif [ -d "$filter" ]; then
    while IFS= read -r test_file; do
      run_test "$test_file"
    done < <(find "$filter" -name "*.sh" -type f | sort)
  else
    echo "error: filter '$filter' is neither a file nor a directory" >&2
    exit 2
  fi
else
  while IFS= read -r test_file; do
    run_test "$test_file"
  done < <(find . -mindepth 2 -name "*.sh" -type f \
             -not -path "./lib/*" \
             | sort)
fi

echo
echo "=============================================="
total=$((passed + failed))
if [ $failed -eq 0 ]; then
  echo " ✓ ${passed}/${total} tests passed"
  exit 0
else
  echo " ✗ ${failed}/${total} tests failed"
  for t in "${failed_tests[@]}"; do
    echo "   - $t"
  done
  exit 1
fi
