#!/usr/bin/env bash
# Gate-check PASS on a clean spec with all required artifacts.
#
# Expected: exit 0, verdict PASS, gate-log entry written.

set -euo pipefail

source "$(dirname "$0")/../lib/assert.sh"
source "$(dirname "$0")/../lib/fixture.sh"

fixture=$(make_fixture)
trap 'rm -rf "$fixture"' EXIT

exit_code=0
run_gate_check "$fixture" ".specify/specs/F-001-smoke.md" || exit_code=$?

assert_equals 0 "$exit_code" "exit code"
assert_contains "$fixture/gc.out" "VERDICT: PASS" "verdict"
assert_contains "$fixture/gc.out" "Gate A — Data Contract" "gate A label"
assert_contains "$fixture/gc.out" "Gate F — Inline Content Scan" "gate F label"
assert_file_exists "$fixture/.tekimax-security/gate-log.jsonl" "gate log"
assert_contains "$fixture/.tekimax-security/gate-log.jsonl" '"verdict": "PASS"' "gate log verdict"
assert_contains "$fixture/.tekimax-security/gate-log.jsonl" '"prev_hash": "genesis"' "gate log hash chain"

echo "✓ $(basename "$0")"
