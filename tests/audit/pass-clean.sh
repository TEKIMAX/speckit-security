#!/usr/bin/env bash
# Audit passes cleanly when src/ has no inline prompts or secrets.
#
# Expected: exit 0, verdict PASS, audit log entry written.

set -euo pipefail

source "$(dirname "$0")/../lib/assert.sh"
source "$(dirname "$0")/../lib/fixture.sh"

fixture=$(make_fixture)
trap 'rm -rf "$fixture"' EXIT

exit_code=0
run_audit "$fixture" || exit_code=$?

assert_equals 0 "$exit_code" "exit code"
assert_contains "$fixture/audit.out" "VERDICT: PASS" "verdict"
assert_contains "$fixture/audit.out" "No findings. Clean." "clean message"
assert_file_exists "$fixture/.tekimax-security/audit-log.jsonl" "audit log"

echo "✓ $(basename "$0")"
