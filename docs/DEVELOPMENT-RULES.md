# Development Rules

These rules apply to anyone contributing code, docs, templates, or
scripts to `speckit-security`. They exist so the project stays
maintainable, readable, and trustworthy as it grows. Non-negotiable
rules are marked **MUST**; strong recommendations are marked **SHOULD**.

Read this alongside [CONTRIBUTING.md](../CONTRIBUTING.md) (workflow)
and [CUSTOMIZATION.md](CUSTOMIZATION.md) (user-facing customization).

---

## Contents

1. [Commit message rules](#1-commit-message-rules)
2. [File structure rules](#2-file-structure-rules)
3. [Code organization and reuse](#3-code-organization-and-reuse)
4. [File length and complexity](#4-file-length-and-complexity)
5. [Naming conventions](#5-naming-conventions)
6. [Inline documentation](#6-inline-documentation)
7. [Unit test rules](#7-unit-test-rules)
8. [Readability and maintainability](#8-readability-and-maintainability)
9. [Review checklist](#9-review-checklist)

---

## 1. Commit message rules

**MUST** describe the change, not the process of making it.

A commit message is a permanent public artifact that future contributors, security researchers, auditors, and search engines will read. Its only job is to explain **what changed and why**, in the vocabulary of the project itself.

### What a good commit message looks like

```
Short, imperative summary under 72 characters

Optional longer body wrapped at ~72 characters. Explains the *why*
behind the change — what problem it solves, what it replaces, what
it enables. Uses the project's own terminology (gates, hooks,
templates, scripts).

- Bullet the concrete changes when there's more than one
- Reference file paths so a reviewer knows where to look
- Link to related issues by number when relevant
```

### What to NEVER include

- ❌ AI tool attribution (`Co-Authored-By: <AI model>`) unless the project has explicitly adopted that convention
- ❌ Any reference to the prompt, conversation, or thought process that led to the change
- ❌ Any phrase that reveals internal review/scrubbing history (e.g. "strip X references", "hide Y", "remove leaked Z")
- ❌ Informal or conversational language ("fixed it", "done", "oops")
- ❌ WIP / placeholder messages in shipped commits (squash them first)
- ❌ Proprietary information, vendor partnerships, pricing details, or unreleased feature names

### What to include

- ✅ Precise imperative verbs in the subject line: `add`, `fix`, `document`, `rename`, `extract`, `refactor`, `harden`
- ✅ The affected area: `gate-check:`, `docs:`, `scripts:`, `templates:`
- ✅ The rationale when non-obvious — especially for refactors or test changes
- ✅ A note when the change is breaking (`BREAKING:` prefix or trailer)

### Good examples

```
gate-check: detect inline prompts with POSIX-compatible patterns

The previous pattern used Perl-style `\s` which doesn't match in
POSIX `grep -E` on macOS, causing Gate F to silently pass when
inline system prompts were present in `src/`. Replace with
`[[:space:]]+` and add `-i` for case insensitivity.
```

```
templates: separate threat model from data contract

The threat model template was inlined inside data-contract.md which
made it hard to override just one. Extract to threat-model-stride.md
so it can be replaced independently via `.specify/templates/overrides/`.
```

### Bad examples (do NOT write these)

```
# Reveals scrub history
Strip Evervault references from public surfaces

# Reveals AI involvement unnecessarily
Fix bug (per Claude suggestion)

# Reveals internal conversation
Address feedback from review call
```

---

## 2. File structure rules

**MUST** keep related things together and unrelated things apart.

### Top-level directories

```
speckit-security/
├── commands/                # Slash command markdown files (AI prompts)
├── templates/               # Reusable artifact templates
├── scripts/
│   └── bash/                # All POSIX bash scripts live here
├── config/                  # Config file templates
├── catalog/                 # Spec-kit community catalog submission
├── docs/                    # Human-facing documentation
├── tests/                   # Unit and smoke tests
├── README.md                # Entry point
├── CHANGELOG.md             # Release notes
├── CONTRIBUTING.md          # Contribution workflow
├── SECURITY.md              # Vulnerability disclosure
├── CODE_OF_CONDUCT.md       # Community standards
├── LICENSE                  # Apache-2.0
├── extension.yml            # Spec-kit extension manifest
├── .extensionignore         # Files excluded from `specify extension add`
└── .gitignore
```

### Directory-level rules

- **MUST** keep hooks in `extension.yml → hooks:` — never as inline logic inside command files
- **MUST** keep scripts in `scripts/bash/` — no loose `.sh` files at the repo root
- **MUST** keep templates in `templates/` — not duplicated inside command files
- **MUST** keep docs in `docs/` — not scattered across the root (except README, CHANGELOG, CONTRIBUTING, SECURITY, CODE_OF_CONDUCT, LICENSE)
- **SHOULD** keep tests in `tests/` mirroring the structure they test (e.g. `tests/gate-check/` tests `scripts/bash/gate-check.sh`)

### Adding a new command

A new slash command requires **all of**:
1. A file under `commands/<command-name>.md`
2. An entry under `provides.commands` in `extension.yml`
3. A corresponding bash script under `scripts/bash/` if the command does real work (not just prompt the agent)
4. A template under `templates/` if the command writes structured artifacts
5. A test under `tests/<command-name>/` or `tests/<command-name>.sh`
6. A CHANGELOG entry under `## [Unreleased]`

Incomplete additions **will be rejected in review**.

---

## 3. Code organization and reuse

**MUST NOT** write the same code twice.

### DRY — don't repeat yourself

- If the same logic appears in two bash scripts, extract it to `scripts/bash/lib/` and `source` it
- If the same regex appears in two files, define it once in config and load it in both
- If the same markdown section appears in two templates, extract it to a shared template fragment

### Extract helpers when a function gets complex

> **Rule of thumb:** if a bash function or a script section does more
> than one thing, or needs more than one sentence to explain, extract
> a helper with a descriptive name.

Signs a function needs extraction:
- Nesting depth > 3
- Function body > 30 lines
- Multiple distinct responsibilities
- A comment starts with "First we... then we... then we..."

### Example: extracting a helper

**Before** — one function doing too much:

```bash
# gate-check.sh
check_gate_a() {
  if [ -f "$SPEC_PATH" ] && grep -q "## 2. Data Contract" "$SPEC_PATH"; then
    if [ -f "src/schemas/${SPEC_SLUG}.ts" ]; then
      if ! grep -q "z\\.any()" "src/schemas/${SPEC_SLUG}.ts"; then
        echo "pass"
      else
        echo "fail: z.any() in schema"
      fi
    else
      echo "fail: missing schema file"
    fi
  else
    echo "fail: missing Data Contract section"
  fi
}
```

**After** — decomposed:

```bash
# gate-check.sh
check_gate_a() {
  has_section "$SPEC_PATH" "## 2. Data Contract" || { echo "fail: missing Data Contract section"; return; }
  has_schema_file "$SPEC_SLUG" || { echo "fail: missing schema file"; return; }
  schema_uses_strict_types "$SPEC_SLUG" || { echo "fail: z.any() in schema"; return; }
  echo "pass"
}
```

The helpers `has_section`, `has_schema_file`, and `schema_uses_strict_types` live in `scripts/bash/lib/checks.sh` and are reusable across gates.

---

## 4. File length and complexity

**SHOULD** keep files short and focused.

### Target sizes

| File type | Target | Hard ceiling |
|---|---|---|
| Bash script | < 200 lines | 400 lines |
| Markdown command | < 200 lines | 400 lines |
| Markdown template | < 100 lines | 200 lines |
| Markdown doc | < 500 lines | 1000 lines |
| YAML config | < 150 lines | 300 lines |

A file that hits the hard ceiling **SHOULD** be split before the next feature lands in it.

### Complexity signals

- A bash function > 50 lines → extract helpers
- A command markdown with > 10 steps → split into sub-commands or extract shared steps to templates
- A doc > 1000 lines → split into a table of contents with linked sub-docs

---

## 5. Naming conventions

**MUST** follow these consistently across the repo.

### Files

| Kind | Pattern | Example |
|---|---|---|
| Bash script | `kebab-case.sh` | `gate-check.sh`, `red-team-run.sh` |
| Command markdown | `kebab-case.md` | `threat-model.md`, `data-contract.md` |
| Template | `kebab-case.md` / `kebab-case.yml` | `threat-model-stride.md`, `guardrail.yml` |
| Helper library | `snake_case.sh` | `scripts/bash/lib/checks.sh` |
| Test | `kebab-case.sh` or `kebab-case.test.sh` | `tests/gate-check.sh` |
| Doc | `SCREAMING-KEBAB.md` | `CUSTOMIZATION.md`, `DEVELOPMENT-RULES.md` |

### Bash variables and functions

- **Functions**: `snake_case` — `check_section`, `add_finding`, `has_schema_file`
- **Local variables**: `snake_case` with `local` declaration — `local spec_path`
- **Script-level constants**: `SCREAMING_SNAKE_CASE` — `GATE_LOG`, `SPEC_ID`
- **Environment variables**: `SPECKIT_TEKIMAX_SECURITY_<NAME>` prefix to avoid collisions

### Slash commands

**MUST** match the spec-kit pattern: `speckit.tekimax-security.<kebab-case-name>`.

### Gate identifiers

Gates use single uppercase letters A–Z in order of introduction. Once a letter is assigned to a gate it is never reused.

---

## 6. Inline documentation

**MUST** document intent, not mechanics.

### What to comment

- ✅ **Why** a non-obvious approach was chosen
- ✅ **Surprising behavior** (e.g. "macOS bash 3.2 fails on empty arrays under set -u")
- ✅ **Invariants** that must hold ("this log is append-only; never rewrite prior entries")
- ✅ **Workarounds** with the underlying bug linked
- ✅ **Security-relevant constraints** ("never print the secret value when flagging it")

### What NOT to comment

- ❌ **What the code does** when it's obvious from reading
- ❌ **Restating the function name** ("this function checks the gate")
- ❌ **Redundant type or signature info** already visible in the code
- ❌ **Temporary commentary** about refactors ("moved from X", "renamed from Y")

### Bash script headers

Every bash script in `scripts/bash/` **MUST** start with a header:

```bash
#!/usr/bin/env bash
# <one-line purpose>
#
# Invoked by: <which command file or hook>
#
# Usage: <script-name>.sh <args>
#
# Exits: 0 on success, 1 on intended failure, 2 on error.
# Reads: <config file paths>
# Writes: <output file paths>

set -euo pipefail
```

### Markdown command headers

Every file in `commands/` **MUST** start with the spec-kit frontmatter block, followed by an H1, followed by a one-paragraph purpose statement.

---

## 7. Unit test rules

**SHOULD** add tests incrementally; **MUST** add tests when fixing bugs.

### Philosophy

We don't aim for 100% coverage. We aim for:

- Every **bug fix** lands with a regression test that would have caught it
- Every **new gate** lands with at least one pass case and one block case
- Every **new bash helper** lands with a test for each distinct input shape

Coverage grows organically from real use, not from chasing a number.

### Test layout

```
tests/
├── README.md              # How to run tests, how to add one
├── run.sh                 # Test runner — runs every tests/*.sh
├── lib/
│   └── assert.sh          # Shared assertion helpers
└── gate-check/
    ├── pass-clean.sh      # Clean spec → PASS, exit 0
    ├── block-no-contract.sh
    ├── block-inline-prompt.sh
    └── block-committed-secret.sh
```

### Writing a test

Every test file **MUST**:
1. Be runnable standalone: `bash tests/gate-check/pass-clean.sh`
2. Set up its own fixture in a temp directory with `mktemp -d`
3. Clean up on exit with a `trap`
4. Exit 0 on pass, non-zero on fail
5. Print a human-readable one-line summary

### Test file template

```bash
#!/usr/bin/env bash
# <what this test verifies>
#
# Expected: <expected behavior>
set -euo pipefail

source "$(dirname "$0")/../lib/assert.sh"

fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT

# --- setup ---
# ... create files in $fixture ...

# --- run ---
actual_exit=0
bash /path/to/script.sh "$fixture/spec.md" > "$fixture/output" 2>&1 || actual_exit=$?

# --- assert ---
assert_equals 0 "$actual_exit" "exit code"
assert_contains "$fixture/output" "VERDICT: PASS" "verdict line"

echo "✓ $(basename "$0")"
```

### Running tests

Tests are runnable by humans with:

```bash
bash tests/run.sh              # all tests
bash tests/run.sh gate-check   # one suite
bash tests/gate-check/pass-clean.sh  # one test
```

The runner prints a human summary. It does not require any package manager or language runtime beyond POSIX bash, so anyone with a Mac or Linux terminal can run the full suite in under a second.

See [tests/README.md](../tests/README.md) for the full testing guide.

---

## 8. Readability and maintainability

**MUST** be readable by a human who has never seen the project before.

### Principles

- **One idea per line.** Long boolean chains belong in named variables.
- **Meaningful names.** `is_clean`, `has_inline_prompts`, `gate_a_result` — not `x`, `tmp`, `ret`.
- **Early returns.** Validate inputs at the top and exit early on failure instead of deeply nested `if` blocks.
- **No dead code.** Delete unused functions, commented-out blocks, TODOs older than 30 days.
- **No magic numbers.** `MAX_RPS=10` not `sleep 0.1`.
- **Consistent indentation.** 2 spaces in bash, YAML, and markdown code blocks. Never tabs.

### When in doubt

> Write it the way you'd want someone to read it at 3 AM while fixing a prod incident they didn't cause.

If the answer is "I'd rewrite it cleaner before I could debug it," rewrite it now.

---

## 9. Review checklist

Before opening a PR, confirm:

- [ ] Commit messages follow the rules in §1
- [ ] New files live in the right directory per §2
- [ ] No duplicated code across scripts, templates, or docs per §3
- [ ] Files are under the hard ceiling per §4
- [ ] Names follow the conventions in §5
- [ ] Inline comments explain *why*, not *what* per §6
- [ ] New behavior has at least one test per §7
- [ ] Bug fixes land with a regression test
- [ ] CHANGELOG `## [Unreleased]` updated
- [ ] `tests/run.sh` passes locally
- [ ] Documentation updated if user-visible behavior changed

---

## Enforcement

These rules are enforced by:

1. **Human review** — reviewers reference this doc in comments
2. **Test suite** — `tests/run.sh` in CI (when CI is added)
3. **Post-implementation audit** — `scripts/bash/audit.sh` catches some violations (inline prompts, secrets)

Violations **block** PR merge. Ask for guidance early if you're unsure whether a change complies — it's cheaper than rewriting after review.
