#!/usr/bin/env bash
# install-rules falls back to AGENTS.md for unknown agents and creates
# the constitution file if it doesn't already exist.
#
# Expected: exit 0, AGENTS.md created, constitution created with
# the rules section.

set -euo pipefail

source "$(dirname "$0")/../lib/assert.sh"
source "$(dirname "$0")/../lib/fixture.sh"

fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT

# No .specify at all — installer should default to generic + AGENTS.md
# and still produce the constitution file under .specify/memory/.

exit_code=0
(cd "$fixture" && bash "$REPO_ROOT/scripts/bash/install-rules.sh" \
  --project-name "unknown-agent-app") \
  > "$fixture/out" 2>&1 || exit_code=$?

assert_equals 0 "$exit_code" "exit code"

assert_file_exists "$fixture/docs/DEVELOPMENT-RULES.md" "docs target"
assert_file_exists "$fixture/.specify/memory/constitution.md" "constitution created from scratch"
assert_file_exists "$fixture/AGENTS.md" "agent fallback target"

assert_contains "$fixture/AGENTS.md" "## Development Rules" "agent section"
assert_contains "$fixture/out" "Agent:     generic" "detected generic agent"
assert_contains "$fixture/out" "AGENTS.md" "summary agent file"

echo "✓ $(basename "$0")"
