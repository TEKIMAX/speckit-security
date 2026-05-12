#!/usr/bin/env bash
# lib/path.sh exposes require_inside_project and refuses paths that
# escape the project root via traversal, absolute paths, or symlinks.
#
# Expected: project-relative paths pass; "../etc/passwd" exits 2.

set -euo pipefail
source "$(dirname "$0")/../lib/assert.sh"
source "$(dirname "$0")/../lib/fixture.sh"

fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT

# --- accepts a path inside the project ---
cat > "$fixture/inside.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
source "$REPO_ROOT/scripts/bash/lib/path.sh"
require_inside_project "ok.txt" "inside"
echo "PASS"
EOF
touch "$fixture/ok.txt"
rc=0
(cd "$fixture" && bash "$fixture/inside.sh") > "$fixture/inside.out" 2>&1 || rc=$?
assert_equals 0 "$rc" "inside-project exit"
assert_contains "$fixture/inside.out" "PASS" "inside-project pass marker"

# --- rejects a traversal path ---
cat > "$fixture/escape.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
source "$REPO_ROOT/scripts/bash/lib/path.sh"
require_inside_project "../../../etc/passwd" "escape"
echo "SHOULD-NOT-PRINT"
EOF
rc=0
(cd "$fixture" && bash "$fixture/escape.sh") > "$fixture/escape.out" 2>&1 || rc=$?
assert_equals 2 "$rc" "traversal exit code"
assert_contains "$fixture/escape.out" "escapes the project root" "traversal error message"
assert_not_contains "$fixture/escape.out" "SHOULD-NOT-PRINT" "function returned instead of exiting"

echo "✓ $(basename "$0")"
