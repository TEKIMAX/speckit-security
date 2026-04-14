#!/usr/bin/env bash
# audit.sh: a user-supplied allowlist path in tekimax-security-config.yml
# suppresses direct-SDK-import findings for files under that path.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../lib/assert.sh"
source "$HERE/../lib/fixture.sh"

fixture=$(make_fixture)
trap 'rm -rf "$fixture"' EXIT

# Layout: the gateway lives at src/platform/ai-proxy.ts (not the
# default src/ai/gateway). Without config read-back, this would be
# flagged as a direct SDK import. With config read-back, the custom
# allowlist entry suppresses the finding.
mkdir -p "$fixture/src/platform"
cat > "$fixture/src/platform/ai-proxy.ts" <<'TS'
import Anthropic from "@anthropic-ai/sdk";
export const client = new Anthropic({ apiKey: process.env.KEY });
TS

mkdir -p "$fixture/.specify/extensions/tekimax-security"
cat > "$fixture/.specify/extensions/tekimax-security/tekimax-security-config.yml" <<'YML'
audit:
  allowlist:
    stack_direct_sdk:
      - src/platform/ai-proxy
YML

run_audit "$fixture" || true
assert_not_contains "$fixture/audit.out" "direct-sdk-import: src/platform/ai-proxy.ts" \
  "custom allowlist should suppress direct-sdk-import finding"

# Sanity: without the config, the same file IS flagged.
rm "$fixture/.specify/extensions/tekimax-security/tekimax-security-config.yml"
run_audit "$fixture" || true
assert_contains "$fixture/audit.out" "direct-sdk-import: src/platform/ai-proxy.ts" \
  "without allowlist the file should be flagged"

echo "✓ allowlist-custom-gateway.sh"
