#!/usr/bin/env bash
# Regression: audit must skip build artifacts under .next/, out/,
# .source/, and .wrangler/ so documentation that mentions secret
# patterns (as examples) doesn't flood the output once the doc
# framework bundles those pages into JS.
#
# This bug was found by running the audit against our own docs-site
# — Next.js bundled the customization page and every mention of
# secret prefixes showed up as a 'committed-secret' finding. None
# of those paths are tracked in git, but the audit was walking the
# filesystem.
#
# The fixture assembles the test strings at runtime so the literal
# secret-looking tokens never appear in the committed source of
# this repo (avoids tripping GitHub's push protection scanner).
#
# Expected: clean audit, exit 0, no findings for .next/ or out/.

set -euo pipefail

source "$(dirname "$0")/../lib/assert.sh"
source "$(dirname "$0")/../lib/fixture.sh"

fixture=$(make_fixture)
trap 'rm -rf "$fixture"' EXIT

# Plant secret-pattern strings inside the build-artifact directories.
# A real-looking token of the shape our regex catches would
# previously have triggered a finding; now it's skipped because
# .next/ and out/ are excluded from the filesystem walk.
mkdir -p "$fixture/.next/dev/server/chunks" "$fixture/out/api"

printf 'const SECRET_DOCS = "sk_live_%s";\nconst PEM = "-----BEGIN RSA PRIVATE KEY-----";\n' \
  "abc123xyz456789012345678" \
  > "$fixture/.next/dev/server/chunks/page.js"

printf '{"doc": "Patterns to detect: sk_live_%s"}\n' \
  "abc123xyz456789012345678" \
  > "$fixture/out/api/search"

exit_code=0
run_audit "$fixture" || exit_code=$?

assert_equals 0 "$exit_code" "exit code"
assert_contains "$fixture/audit.out" "No findings. Clean." "clean message"
assert_not_contains "$fixture/audit.out" ".next/" "build artifact path not flagged"
assert_not_contains "$fixture/audit.out" "out/api/search" "static export path not flagged"

echo "✓ $(basename "$0")"
