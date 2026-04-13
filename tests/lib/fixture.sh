#!/usr/bin/env bash
# Shared fixture helpers for tests.
#
# Creates a temp project directory with the minimum files needed to
# exercise gate-check.sh and audit.sh, plus a few convenience helpers.
#
# Usage:
#   source "$(dirname "$0")/../lib/fixture.sh"
#   fixture=$(make_fixture)
#   trap 'rm -rf "$fixture"' EXIT

set -euo pipefail

# REPO_ROOT resolves to the speckit-security repo root — used by tests
# to run the scripts under scripts/bash.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# make_fixture
#
# Creates a temp dir and returns its path. The dir contains the minimum
# structure needed for gate-check and audit to run: a .specify/ stub,
# a spec file, a schema file, and empty src/.
make_fixture() {
  local dir
  dir=$(mktemp -d)

  mkdir -p "$dir/.specify/specs" \
           "$dir/.specify/extensions/tekimax-security" \
           "$dir/src/schemas" \
           "$dir/prompts/system" \
           "$dir/prompts/guardrails"

  cat > "$dir/.specify/specs/F-001-smoke.md" <<'SPEC'
# F-001 — smoke

## 2. Data Contract

- Sources: test input
- Schemas: src/schemas/smoke.ts
- PII: none
- Retention: 0 days

## 3. AI Integration

- Provider: example
- Model: example-model
- Version: example-model-2026-04-01
- Gateway: AI gateway
- Rollback: prior version, less than 60s

## Security / Threat Model

STRIDE:
| T1 | Spoofing | N/A | Low | Low | None | N/A |
SPEC

  cat > "$dir/src/schemas/smoke.ts" <<'TS'
import { z } from "zod";
export const SmokeSchema = z.object({
  id: z.string().uuid(),
});
TS

  cat > "$dir/prompts/system/smoke.md" <<'PROMPT'
# System Prompt — smoke

**Version:** 1.0.0

## System Prompt (v1.0.0)

```
Echo the input.
```
PROMPT

  cat > "$dir/prompts/guardrails/smoke.yml" <<'YML'
slug: smoke
version: 1.0.0
input:
  max_length: 1000
  blocked_patterns:
    - "ignore"
output:
  max_length: 1000
  redact_patterns:
    - pattern: "secret"
      replace: "[REDACTED]"
limits:
  rate_per_user_per_minute: 10
  cost_ceiling_usd_per_day: 5
YML

  echo "$dir"
}

# run_gate_check <fixture_dir> <spec_path> -> captured output in $fixture/gc.out
#
# Runs gate-check.sh from the fixture directory. Returns the script's
# exit code. Writes full stdout+stderr to $fixture_dir/gc.out.
run_gate_check() {
  local fixture_dir="$1"
  local spec_path="$2"
  local rc=0
  (cd "$fixture_dir" && bash "$REPO_ROOT/scripts/bash/gate-check.sh" "$spec_path") \
    > "$fixture_dir/gc.out" 2>&1 || rc=$?
  return $rc
}

# run_audit <fixture_dir> -> captured output in $fixture/audit.out
#
# Runs audit.sh from the fixture directory. Returns exit code. Writes
# full output to $fixture_dir/audit.out.
run_audit() {
  local fixture_dir="$1"
  local rc=0
  (cd "$fixture_dir" && bash "$REPO_ROOT/scripts/bash/audit.sh") \
    > "$fixture_dir/audit.out" 2>&1 || rc=$?
  return $rc
}
