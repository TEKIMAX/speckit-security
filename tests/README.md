# Tests

Zero-dependency POSIX bash tests for `speckit-security`. No package
manager, no language runtime, no test framework — just `bash` and the
scripts under `scripts/bash/`. Every test runs in under a second.

## How to run the tests

```bash
# All tests
bash tests/run.sh

# One suite
bash tests/run.sh gate-check
bash tests/run.sh audit

# One test
bash tests/gate-check/pass-clean.sh
```

The runner prints a human-readable summary at the end:

```
==============================================
 speckit-security test runner
==============================================

✓ block-inline-prompt.sh
✓ block-no-data-contract.sh
✓ pass-clean.sh
✓ block-committed-secret.sh
✓ pass-clean.sh

==============================================
 ✓ 5/5 tests passed
```

A failing run tells you exactly which tests broke:

```
 ✗ 1/5 tests failed
   - ./gate-check/block-inline-prompt.sh
```

Failed tests print the assertion that failed and the surrounding
context to stderr, so you can debug without re-running.

## Layout

```
tests/
├── README.md                 # this file
├── run.sh                    # the runner
├── lib/
│   ├── assert.sh             # assertion helpers
│   └── fixture.sh            # temp project fixture builder
├── gate-check/
│   ├── pass-clean.sh         # clean spec → PASS, exit 0
│   ├── block-no-data-contract.sh   # missing section → BLOCK, exit 1
│   └── block-inline-prompt.sh      # inline prompt in src/ → BLOCK, exit 1
└── audit/
    ├── pass-clean.sh         # empty src/ → PASS, exit 0
    └── block-committed-secret.sh   # sk_live_* in src/ → BLOCK, exit 1
```

## What each test covers

### gate-check

| Test | Scenario | Expected |
|---|---|---|
| `pass-clean.sh` | Spec with all required sections, valid Zod schema, threat model | PASS, exit 0, gate-log entry written with all 6 gates noted |
| `block-no-data-contract.sh` | Spec missing `## 2. Data Contract` section | BLOCK, exit 1, Gate A reports missing section |
| `block-inline-prompt.sh` | `src/ai/chat.ts` contains `You are a helpful assistant` | BLOCK, exit 1, Gate F reports `inline-prompts` |

### audit

| Test | Scenario | Expected |
|---|---|---|
| `pass-clean.sh` | Clean project with no secrets or inline prompts | PASS, exit 0, "No findings. Clean." |
| `block-committed-secret.sh` | `sk_live_*` pattern in `src/routes/webhook.ts` | BLOCK, exit 1, finding mentions file path but NOT the secret value |

## Writing a new test

Every test file must:

1. **Be runnable standalone** — `bash tests/<suite>/<test>.sh` should
   just work without any setup steps.
2. **Use `make_fixture`** from `lib/fixture.sh` to create an isolated
   temp project. Never write to anywhere outside the fixture directory.
3. **Clean up on exit** with `trap 'rm -rf "$fixture"' EXIT`.
4. **Exit 0 on pass, non-zero on fail.** Use `assert_equals`,
   `assert_contains`, `assert_not_contains`, `assert_file_exists`, and
   `assert_exit_nonzero` from `lib/assert.sh`.
5. **Print a one-line success summary** at the end: `echo "✓ $(basename "$0")"`
6. **Start with a header comment** explaining what the test covers.

### Test template

Copy this and fill in the blanks:

```bash
#!/usr/bin/env bash
# <one-line description of what this test verifies>
#
# Expected: <expected behavior and exit code>

set -euo pipefail

source "$(dirname "$0")/../lib/assert.sh"
source "$(dirname "$0")/../lib/fixture.sh"

fixture=$(make_fixture)
trap 'rm -rf "$fixture"' EXIT

# --- setup ---
# ... modify the fixture to match the scenario being tested ...

# --- run ---
exit_code=0
run_gate_check "$fixture" ".specify/specs/F-001-smoke.md" || exit_code=$?

# --- assert ---
assert_equals 0 "$exit_code" "exit code"
assert_contains "$fixture/gc.out" "VERDICT: PASS" "verdict"

echo "✓ $(basename "$0")"
```

## When to add a test

Per [DEVELOPMENT-RULES.md §7](../docs/DEVELOPMENT-RULES.md#7-unit-test-rules):

- **MUST** add a regression test when fixing a bug
- **MUST** add a pass case and a fail case when adding a new gate
- **MUST** add a test for each distinct input shape when adding a new bash helper
- **SHOULD** add edge cases as you encounter them in the wild

We don't chase coverage numbers. Tests grow from real use.

## Current coverage

5 tests covering the critical gate-check and audit paths. More will be
added incrementally — the next priorities are:

- `gate-check/block-unpinned-model.sh` — model version is `"latest"`
- `gate-check/block-missing-schema.sh` — Zod schema file missing
- `gate-check/block-committed-env.sh` — `.env` committed to git
- `audit/block-direct-sdk-import.sh` — `@google/genai` import outside
  `src/ai/gateway.ts`
- `audit/warn-guardrail-drift.sh` — guardrail YAML edited without
  version bump

Contributions welcome — see
[CONTRIBUTING.md](../CONTRIBUTING.md) for the workflow.
