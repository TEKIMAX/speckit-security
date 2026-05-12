#!/usr/bin/env bash
# Path-confinement helper for speckit-security scripts.
#
# Sourced by any script that accepts a path from the caller. Prevents
# path traversal via "../..", symlinks, or absolute paths that escape
# the project root.
#
# Usage (sourced):
#     source "$(dirname "$0")/lib/path.sh"
#     require_inside_project "$SPEC_PATH" "spec path"

# Guard: path resolution uses Python for canonicalization (realpath -e
# is not portable across BSD/macOS and GNU/Linux). Fail fast with a
# clear message rather than silently degrading the check.
if ! command -v python3 >/dev/null 2>&1; then
  echo "error: speckit-security requires python3 but it is not installed." >&2
  echo "  Install Python 3 and ensure it is on your PATH." >&2
  exit 2
fi

# require_inside_project <path> <label>
#
# Resolves <path> to its canonical absolute form and verifies it lives
# inside the current working directory (the project root). Exits with
# error code 2 if the path escapes the project.
#
# Uses `pwd -P` (physical path, no symlinks) and Python's
# os.path.realpath so the check works on both macOS and Linux.
require_inside_project() {
  local target="$1"
  local label="${2:-path}"
  local project_root
  project_root="$(pwd -P)"

  local resolved
  resolved=$(python3 -c "
import os, sys
target = sys.argv[1]
root = sys.argv[2]
if not os.path.isabs(target):
    target = os.path.join(root, target)
print(os.path.realpath(target))
" "$target" "$project_root")

  if [[ "$resolved" != "$project_root"* ]]; then
    echo "error: $label escapes the project root." >&2
    echo "  resolved: $resolved" >&2
    echo "  project:  $project_root" >&2
    echo "  speckit-security scripts are confined to the project directory." >&2
    exit 2
  fi
}
