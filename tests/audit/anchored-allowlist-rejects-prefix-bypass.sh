#!/usr/bin/env bash
# Regression: an attacker-ish filename that shares a prefix with an
# allowlist entry must NOT be silently allowlisted.
#
# Before v0.3.1 the allowlist did a substring match, so a file named
# src/ai/gateway-bypass.ts was treated as allowed when the allowlist
# entry was "src/ai/gateway". v0.3.1 uses an anchored match.

set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../lib/assert.sh"
source "$HERE/../lib/fixture.sh"

fixture=$(make_fixture)
trap 'rm -rf "$fixture"' EXIT

mkdir -p "$fixture/src/ai"
cat > "$fixture/src/ai/gateway-bypass.ts" <<'TS'
import OpenAI from "openai";
export const client = new OpenAI();
TS

cat > "$fixture/.specify/extensions/tekimax-security/tekimax-security-config.yml" <<'YML'
audit:
  allowlist:
    stack_direct_sdk:
      - src/ai/gateway
YML

run_audit "$fixture" || true
assert_contains "$fixture/audit.out" "direct-sdk-import: src/ai/gateway-bypass.ts" \
  "gateway-bypass.ts must NOT inherit allowlist entry src/ai/gateway"

echo "✓ $(basename "$0")"
