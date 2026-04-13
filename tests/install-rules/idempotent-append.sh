#!/usr/bin/env bash
# Running install-rules twice without --force must not duplicate the
# Development Rules section in the constitution or agent context file.
#
# Expected: second run exits 0 and reports "skipped" for both append
# targets; the constitution contains exactly one "## Development Rules"
# heading.

set -euo pipefail

source "$(dirname "$0")/../lib/assert.sh"
source "$(dirname "$0")/../lib/fixture.sh"

fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT

mkdir -p "$fixture/.specify"
printf '{"ai": "opencode", "project_name": "idem"}\n' \
  > "$fixture/.specify/init-options.json"

# --- first run ---
(cd "$fixture" && bash "$REPO_ROOT/scripts/bash/install-rules.sh") \
  > "$fixture/first.out" 2>&1

# --- second run ---
(cd "$fixture" && bash "$REPO_ROOT/scripts/bash/install-rules.sh") \
  > "$fixture/second.out" 2>&1

# Count the Development Rules headings in each append target.
constitution_headings=$(grep -c "^## Development Rules" "$fixture/.specify/memory/constitution.md")
agents_headings=$(grep -c "^## Development Rules" "$fixture/AGENTS.md")

assert_equals "1" "$constitution_headings" "constitution heading count"
assert_equals "1" "$agents_headings" "agents heading count"

assert_contains "$fixture/second.out" "skipped" "second run skipped append"

echo "✓ $(basename "$0")"
