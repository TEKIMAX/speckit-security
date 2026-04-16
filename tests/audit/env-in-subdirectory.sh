#!/usr/bin/env bash
# Regression: a .env file committed under apps/ or packages/ is
# detected. Previous behavior matched only the repo root.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../lib/assert.sh"
source "$HERE/../lib/fixture.sh"

fixture=$(make_fixture)
trap 'rm -rf "$fixture"' EXIT

mkdir -p "$fixture/apps/api"
# Assemble the literal at runtime so the committed test source never
# contains a value matching the Stripe live-key pattern.
printf 'API_KEY=sk_live_%s\n' "abcdef0123456789ABCDEFGHIJ" \
  > "$fixture/apps/api/.env"

(cd "$fixture" && git init -q && git add -A && \
  git -c user.email=t@t -c user.name=t commit -q -m init)

run_audit "$fixture" || true
assert_contains "$fixture/audit.out" ".env-committed: apps/api/.env" \
  "nested .env should be flagged"

mv "$fixture/apps/api/.env" "$fixture/apps/api/.env.example"
(cd "$fixture" && git add -A && git -c user.email=t@t -c user.name=t commit -q -m rename)
run_audit "$fixture" || true
assert_not_contains "$fixture/audit.out" ".env-committed: apps/api/.env.example" \
  ".env.example must not be flagged as committed-secret carrier"

echo "✓ $(basename "$0")"
