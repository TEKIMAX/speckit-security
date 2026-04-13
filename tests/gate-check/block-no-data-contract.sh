#!/usr/bin/env bash
# Gate A fails when the spec has no Data Contract section.
#
# Expected: exit 1, verdict BLOCK, Gate A reports missing section.

set -euo pipefail

source "$(dirname "$0")/../lib/assert.sh"
source "$(dirname "$0")/../lib/fixture.sh"

fixture=$(make_fixture)
trap 'rm -rf "$fixture"' EXIT

# Overwrite the spec with one that's missing the Data Contract section.
cat > "$fixture/.specify/specs/F-001-smoke.md" <<'SPEC'
# F-001 — smoke

## 3. AI Integration

- Provider: example
- Model: example-model
- Version: example-model-2026-04-01
- Gateway: AI gateway
- Rollback: prior version, less than 60s

## Security / Threat Model

STRIDE: |
SPEC

exit_code=0
run_gate_check "$fixture" ".specify/specs/F-001-smoke.md" || exit_code=$?

assert_exit_nonzero "$exit_code" "exit code"
assert_contains "$fixture/gc.out" "VERDICT: BLOCK" "verdict"
assert_contains "$fixture/gc.out" "Gate A" "gate A label"
assert_contains "$fixture/gc.out" "missing Data Contract" "failure reason"

echo "✓ $(basename "$0")"
