#!/usr/bin/env bash
# config.sh: scalar reads resolve at depths 1, 2, and 3, and missing
# keys or files return empty (not error).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../lib/assert.sh"
source "$HERE/../../scripts/bash/lib/config.sh"

fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT

cat > "$fixture/cfg.yml" <<'YML'
enforcement: strict

stack:
  schema: zod
  runtime: node

red_team:
  staging_url: "https://staging.example.com"
  max_rps: 25

audit:
  allowlist:
    max_depth: 7
YML

assert_equals "strict"     "$(config_get "$fixture/cfg.yml" "enforcement")"         "top-level scalar"
assert_equals "zod"        "$(config_get "$fixture/cfg.yml" "stack.schema")"         "depth-2 scalar"
assert_equals "node"       "$(config_get "$fixture/cfg.yml" "stack.runtime")"        "depth-2 scalar, second key"
assert_equals "https://staging.example.com" "$(config_get "$fixture/cfg.yml" "red_team.staging_url")" "quoted URL"
assert_equals "25"         "$(config_get "$fixture/cfg.yml" "red_team.max_rps")"     "integer scalar"
assert_equals "7"          "$(config_get "$fixture/cfg.yml" "audit.allowlist.max_depth")" "depth-3 scalar"
assert_equals ""           "$(config_get "$fixture/cfg.yml" "missing.key")"          "missing key returns empty"
assert_equals ""           "$(config_get "/no/such/file.yml" "anything")"            "missing file returns empty"

echo "✓ parser-reads-scalars.sh"
