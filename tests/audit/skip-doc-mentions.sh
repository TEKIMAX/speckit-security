#!/usr/bin/env bash
# Regression: literal doc mentions of secret prefixes (without real
# key material) must not trigger the audit. Before the pattern was
# tightened, the bare string "sk_live_" or the bare word
# "PRIVATE_KEY" would flag any file that discussed them — including
# documentation, config comments, and test fixtures.
#
# Expected: clean audit, exit 0, no findings.

set -euo pipefail

source "$(dirname "$0")/../lib/assert.sh"
source "$(dirname "$0")/../lib/fixture.sh"

fixture=$(make_fixture)
trap 'rm -rf "$fixture"' EXIT

# Plant doc-style mentions: bare prefixes with no trailing key chars,
# a bare 'PRIVATE_KEY' identifier (as a variable name), and a bare
# 'BEGIN RSA' phrase without the full PEM header.
mkdir -p "$fixture/src/config"
cat > "$fixture/src/config/example.ts" <<'TS'
// Example patterns detected by the audit:
//   sk_live_ prefix on Stripe live keys
//   sk_test_ prefix on Stripe test keys
//   PRIVATE_KEY environment variable for signing
//   BEGIN RSA header from PEM-encoded key files
const SECRET_ENV_NAME = "PRIVATE_KEY";
const DOC_PREFIX = "sk_live_";
TS

exit_code=0
run_audit "$fixture" || exit_code=$?

assert_equals 0 "$exit_code" "exit code"
assert_contains "$fixture/audit.out" "No findings. Clean." "clean message"

echo "✓ $(basename "$0")"
