#!/usr/bin/env bash
# install-rules writes docs/DEVELOPMENT-RULES.md, appends to the
# spec-kit constitution, and writes the agent-specific context file.
#
# Expected: exit 0, all three files present, correct agent file
# (CLAUDE.md for --ai claude), and docs content contains the project
# name substitution.

set -euo pipefail

source "$(dirname "$0")/../lib/assert.sh"
source "$(dirname "$0")/../lib/fixture.sh"

fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT

# Create a minimal spec-kit-shaped project with a claude init.
mkdir -p "$fixture/.specify/memory"
printf '{"ai": "claude", "project_name": "demo-app"}\n' \
  > "$fixture/.specify/init-options.json"

# Run the installer (uses the dev-mode template fallback because the
# extension install dir isn't present in the fixture).
exit_code=0
(cd "$fixture" && bash "$REPO_ROOT/scripts/bash/install-rules.sh") \
  > "$fixture/out" 2>&1 || exit_code=$?

assert_equals 0 "$exit_code" "exit code"

# Target 1 — docs/DEVELOPMENT-RULES.md
assert_file_exists "$fixture/docs/DEVELOPMENT-RULES.md" "docs target"
assert_contains "$fixture/docs/DEVELOPMENT-RULES.md" "demo-app" "project name substitution"
assert_contains "$fixture/docs/DEVELOPMENT-RULES.md" "Commit message rules" "full rules content"

# Target 2 — .specify/memory/constitution.md
assert_file_exists "$fixture/.specify/memory/constitution.md" "constitution target"
assert_contains "$fixture/.specify/memory/constitution.md" "## Development Rules" "constitution section"
assert_contains "$fixture/.specify/memory/constitution.md" "docs/DEVELOPMENT-RULES.md" "constitution link"

# Target 3 — CLAUDE.md (because agent is claude)
assert_file_exists "$fixture/CLAUDE.md" "agent context target"
assert_contains "$fixture/CLAUDE.md" "## Development Rules" "agent section"

# Summary output
assert_contains "$fixture/out" "Agent:     claude" "summary agent"
assert_contains "$fixture/out" "CLAUDE.md" "summary context file"

echo "✓ $(basename "$0")"
