#!/usr/bin/env bash
# Gate F blocks when an inline system prompt appears in src/.
#
# This is the regression test for the POSIX grep bug — the original
# gate-check used Perl-style \s which silently passed on macOS.
#
# Expected: exit 1, verdict BLOCK, Gate F reports inline-prompts.

set -euo pipefail

source "$(dirname "$0")/../lib/assert.sh"
source "$(dirname "$0")/../lib/fixture.sh"

fixture=$(make_fixture)
trap 'rm -rf "$fixture"' EXIT

# Plant an inline system prompt in src/ai/chat.ts.
mkdir -p "$fixture/src/ai"
cat > "$fixture/src/ai/chat.ts" <<'TS'
const systemPrompt = "You are a helpful assistant. Summarize feedback.";
export { systemPrompt };
TS

exit_code=0
run_gate_check "$fixture" ".specify/specs/F-001-smoke.md" || exit_code=$?

assert_exit_nonzero "$exit_code" "exit code"
assert_contains "$fixture/gc.out" "VERDICT: BLOCK" "verdict"
assert_contains "$fixture/gc.out" "Gate F" "gate F label"
assert_contains "$fixture/gc.out" "inline-prompts" "failure reason"

echo "✓ $(basename "$0")"
