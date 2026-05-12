#!/usr/bin/env bash
# lib/gates.sh exposes check_gate_a..g as standalone functions.
# Each returns its verdict on stdout as "pass", "fail: <reason>", or
# "skip: <reason>". Functions are testable in isolation.
#
# Expected: pass/fail verdicts match a hand-built fixture.

set -euo pipefail
source "$(dirname "$0")/../lib/assert.sh"
source "$(dirname "$0")/../lib/fixture.sh"

fixture=$(make_fixture)
trap 'rm -rf "$fixture"' EXIT

# Source the libs from within the fixture cwd so relative file checks
# (src/schemas/<slug>.ts, prompts/guardrails/<slug>.yml) resolve.
cd "$fixture"
# shellcheck source=/dev/null
source "$REPO_ROOT/scripts/bash/lib/defaults.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/scripts/bash/lib/config.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/scripts/bash/lib/gates.sh"

spec=".specify/specs/F-001-smoke.md"

# Gate A — clean fixture has a valid Data Contract + schema -> pass
result=$(check_gate_a "$spec" "smoke")
assert_equals "pass" "$result" "Gate A on clean fixture"

# Gate A — corrupt the schema with z.any() -> fail
echo "const Bad = z.any();" >> "src/schemas/smoke.ts"
result=$(check_gate_a "$spec" "smoke")
assert_equals "fail: z.any() in schema" "$result" "Gate A z.any()"

# Gate B — STRIDE row present -> pass
result=$(check_gate_b "$spec")
assert_equals "pass" "$result" "Gate B on clean fixture"

# Gate C — AI integration with pinned model + rollback -> pass
result=$(check_gate_c "$spec")
assert_equals "pass" "$result" "Gate C on clean fixture"

# Gate D — guardrail YAML has all required keys -> pass
result=$(check_gate_d "smoke" "pass")
assert_equals "pass" "$result" "Gate D on clean fixture"

# Gate D — skips when Gate C reports no AI integration
result=$(check_gate_d "smoke" "skip: no AI integration")
assert_equals "skip: no AI integration" "$result" "Gate D inherits C skip"

# Gate E — no red-team report -> skip with required-before-ship note
result=$(check_gate_e "smoke")
case "$result" in
  skip:*) ;;
  *) echo "✗ Gate E should skip without report, got: $result" >&2; exit 1 ;;
esac

echo "✓ $(basename "$0")"
