#!/usr/bin/env bash
# config.sh: list reads resolve at depths 1, 2, and 3, and missing
# keys or files return empty (not error).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../lib/assert.sh"
source "$HERE/../../scripts/bash/lib/config.sh"

fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT

cat > "$fixture/cfg.yml" <<'YML'
required_sections:
  - "Data Contract"
  - Security

audit:
  secret_patterns:
    - sk_live_
    - ACME_TOKEN_[A-Z]+
  allowlist:
    stack_direct_sdk:
      - src/ai/gateway.ts
      - src/ai/gateway-test.ts
YML

# Top-level list
top_items=$(config_list "$fixture/cfg.yml" "required_sections" | tr '\n' '|')
assert_equals "Data Contract|Security|" "$top_items" "top-level list"

# Depth-2 list
sec_items=$(config_list "$fixture/cfg.yml" "audit.secret_patterns" | tr '\n' '|')
assert_equals "sk_live_|ACME_TOKEN_[A-Z]+|" "$sec_items" "depth-2 list"

# Depth-3 list
allow_items=$(config_list "$fixture/cfg.yml" "audit.allowlist.stack_direct_sdk" | tr '\n' '|')
assert_equals "src/ai/gateway.ts|src/ai/gateway-test.ts|" "$allow_items" "depth-3 list"

# Missing key / file
assert_equals "" "$(config_list "$fixture/cfg.yml" "missing.list")"    "missing key returns empty"
assert_equals "" "$(config_list "/no/such/file.yml" "anything")"       "missing file returns empty"

echo "✓ parser-reads-lists.sh"
