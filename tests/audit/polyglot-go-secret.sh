#!/usr/bin/env bash
# Regression: polyglot defaults include Go files — a committed AWS key
# in a .go file is detected without requiring config overrides.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../lib/assert.sh"
source "$HERE/../lib/fixture.sh"

fixture=$(make_fixture)
trap 'rm -rf "$fixture"' EXIT

mkdir -p "$fixture/internal/secrets"
# Assemble the literal at runtime to keep it out of committed history.
printf 'package secrets\n\nvar Key = "%s%s"\n' "AKIA" "ABCDEFGHIJKLMNOP" \
  > "$fixture/internal/secrets/keys.go"

run_audit "$fixture" || true
assert_contains "$fixture/audit.out" "committed-secret:" \
  "Go file containing an AWS key should be flagged by the polyglot default scan"

echo "✓ $(basename "$0")"
