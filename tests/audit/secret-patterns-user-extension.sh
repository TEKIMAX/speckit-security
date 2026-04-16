#!/usr/bin/env bash
# audit.sh: user-supplied secret_patterns in tekimax-security-config.yml
# are additive — built-in patterns still fire, and custom patterns
# catch company-specific tokens.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../lib/assert.sh"
source "$HERE/../lib/fixture.sh"

fixture=$(make_fixture)
trap 'rm -rf "$fixture"' EXIT

# Plant a fake company token that the built-in patterns wouldn't catch.
mkdir -p "$fixture/src"
cat > "$fixture/src/config.ts" <<'TS'
// Fake token for testing; not a real secret.
export const TOKEN = "ACME_PROD_abcd1234efgh5678ijkl";
TS

mkdir -p "$fixture/.specify/extensions/tekimax-security"
cat > "$fixture/.specify/extensions/tekimax-security/tekimax-security-config.yml" <<'YML'
audit:
  secret_patterns:
    - "ACME_PROD_[a-z0-9]{20}"
YML

run_audit "$fixture" || true
assert_contains "$fixture/audit.out" "committed-secret: ./src/config.ts" \
  "custom secret pattern should flag the company token"

# Sanity: without the custom pattern, the file is NOT flagged (the
# built-ins don't know about ACME_PROD_).
rm "$fixture/.specify/extensions/tekimax-security/tekimax-security-config.yml"
run_audit "$fixture" || true
assert_not_contains "$fixture/audit.out" "committed-secret: ./src/config.ts" \
  "without custom pattern the company token should be invisible to audit"

echo "✓ secret-patterns-user-extension.sh"
