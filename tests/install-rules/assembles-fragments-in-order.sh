#!/usr/bin/env bash
# install-rules.sh assembles templates/rules/*.md fragments in
# sorted (numeric-prefix) order into docs/DEVELOPMENT-RULES.md.
#
# Expected: section headings appear in 1..9 order and project name is
# substituted in the assembled output.

set -euo pipefail
source "$(dirname "$0")/../lib/assert.sh"
source "$(dirname "$0")/../lib/fixture.sh"

fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT

mkdir -p "$fixture/.specify/memory"
printf '{"ai": "claude", "project_name": "assemble-test"}\n' \
  > "$fixture/.specify/init-options.json"

rc=0
(cd "$fixture" && bash "$REPO_ROOT/scripts/bash/install-rules.sh") \
  > "$fixture/out" 2>&1 || rc=$?
assert_equals 0 "$rc" "install-rules exit"

doc="$fixture/docs/DEVELOPMENT-RULES.md"
assert_file_exists "$doc" "assembled doc"
assert_contains "$doc" "assemble-test" "project name substitution"

# Verify section ordering — extract H2 headings starting with a digit
# and check they appear in 1..9 order.
ordering=$(grep -E '^## [0-9]\.' "$doc" | head -9 | sed -E 's/^## ([0-9])\..*/\1/' | tr '\n' ' ')
assert_equals "1 2 3 4 5 6 7 8 9 " "$ordering" "section order"

# Verify the cover/index lives at the top (TOC entries before §1).
toc_line=$(grep -n '^1\. \[Commit message rules\]' "$doc" | head -1 | cut -d: -f1)
section_line=$(grep -n '^## 1\. Commit message rules' "$doc" | head -1 | cut -d: -f1)
if [ "$toc_line" -ge "$section_line" ]; then
  echo "✗ TOC (line $toc_line) should appear before section 1 (line $section_line)" >&2
  exit 1
fi

echo "✓ $(basename "$0")"
