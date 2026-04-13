#!/usr/bin/env bash
# Audit blocks when a committed secret matching known patterns exists.
#
# Regression test for the set -e + final `[` test bug — the original
# audit.sh silently terminated on CRITICAL findings instead of reporting.
#
# Expected: exit 1, verdict BLOCK, finding mentions the file path.

set -euo pipefail

source "$(dirname "$0")/../lib/assert.sh"
source "$(dirname "$0")/../lib/fixture.sh"

fixture=$(make_fixture)
trap 'rm -rf "$fixture"' EXIT

# Plant a Stripe-style live-key pattern in a source file.
mkdir -p "$fixture/src/routes"
printf 'const key = "sk_live_%s";\n' "abc123xyz456789012345678" \
  > "$fixture/src/routes/webhook.ts"

exit_code=0
run_audit "$fixture" || exit_code=$?

assert_exit_nonzero "$exit_code" "exit code"
assert_contains "$fixture/audit.out" "VERDICT: BLOCK" "verdict"
assert_contains "$fixture/audit.out" "committed-secret" "finding type"
assert_contains "$fixture/audit.out" "src/routes/webhook.ts" "offending file"
# Never leak the actual secret value in the audit output.
assert_not_contains "$fixture/audit.out" "sk_live_abc123" "secret value redaction"

echo "✓ $(basename "$0")"
