#!/usr/bin/env bash
# Regression: the inline-prompt pattern must not match legal or
# privacy copy that uses second-person addressing ("If you are a
# California resident", "If you are a HIPAA covered entity", etc.).
#
# The earlier pattern `[Yy]ou[[:space:]]+are[[:space:]]+a` matched
# any pronoun+copula+article construction and tripped on every
# Terms of Service and Privacy Policy page in the wild. Tightened
# to require an AI-specific role keyword (helpful, AI, assistant,
# chatbot, expert, virtual, language model, etc.) immediately
# after the article.
#
# Expected: clean audit, exit 0, no findings.

set -euo pipefail

source "$(dirname "$0")/../lib/assert.sh"
source "$(dirname "$0")/../lib/fixture.sh"

fixture=$(make_fixture)
trap 'rm -rf "$fixture"' EXIT

# Plant a realistic Terms of Service JSX file with several
# second-person legal clauses. None of these are AI system prompts
# but every one of them contains "you are a <noun>".
mkdir -p "$fixture/src/pages"
cat > "$fixture/src/pages/Terms.tsx" <<'TSX'
export function Terms() {
  return (
    <article>
      <p>
        If you are a California resident, you have the right to
        request disclosure of the personal information we collect.
      </p>
      <p>
        If you are a Texas resident, you have specific rights
        under the Texas Data Privacy and Security Act.
      </p>
      <p>
        If you are a HIPAA covered entity or business associate,
        you must not upload protected health information to the
        service.
      </p>
      <p>
        If you are a visitor under thirteen years of age, please
        do not submit any personal information.
      </p>
      <p>
        You are a valued customer and these terms explain the
        rules that apply when you use our service.
      </p>
    </article>
  );
}
TSX

exit_code=0
run_audit "$fixture" || exit_code=$?

assert_equals 0 "$exit_code" "exit code"
assert_contains "$fixture/audit.out" "No findings. Clean." "clean message"
assert_not_contains "$fixture/audit.out" "Terms.tsx" "legal copy not flagged"

echo "✓ $(basename "$0")"
