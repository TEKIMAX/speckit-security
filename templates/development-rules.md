# Development Rules

These rules apply to everyone contributing code, docs, or scripts to
**{{PROJECT_NAME}}**. They exist so the project stays maintainable,
readable, and trustworthy as it grows. Non-negotiable rules are marked
**MUST**; strong recommendations are marked **SHOULD**.

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

A commit message is a permanent public artifact. Its only job is to
explain **what changed and why**, in the vocabulary of the project.

### What a good commit message looks like

```
Short, imperative summary under 72 characters

Optional longer body wrapped at ~72 characters. Explains the *why*
behind the change — what problem it solves, what it replaces, what
it enables.

- Bullet the concrete changes when there's more than one
- Reference file paths so a reviewer knows where to look
- Link to related issues by number when relevant
```

### What to NEVER include

- ❌ AI tool attribution unless the project explicitly adopts it
- ❌ References to the prompt, conversation, or thought process
- ❌ Internal review history ("strip X references", "hide Y")
- ❌ Informal language ("fixed it", "done", "oops")
- ❌ WIP / placeholder messages in shipped commits — squash first
- ❌ Proprietary information, pricing, unreleased feature names

### What to include

- ✅ Imperative verbs: `add`, `fix`, `document`, `rename`, `extract`, `refactor`
- ✅ The affected area: `auth:`, `docs:`, `scripts:`, `tests:`
- ✅ The rationale when non-obvious
- ✅ A `BREAKING:` prefix or trailer when the change breaks consumers

### Example — good

```
auth: reject expired JWT without hitting the database

Previously every request re-queried the session table even after
the token's `exp` claim had passed. Exit early in the middleware
when `exp < now` to save ~4ms per unauthenticated request.
```

### Example — bad (do not write these)

```
# Reveals internal scrub history
Strip vendor X references

# Reveals AI involvement
Fix bug (per AI suggestion)

# Reveals internal conversation
Address feedback from review call
```

---

## 2. File structure rules

**MUST** keep related things together and unrelated things apart.

### Directory discipline

- **Hooks stay in the hooks directory.** Never inline hook logic inside
  unrelated files. If the framework you're using defines where hooks
  live, put them there and nowhere else.
- **Scripts stay in `scripts/`.** No loose `.sh` / `.ps1` / `.py` files
  scattered across the repo root.
- **Templates stay in `templates/`.** Not duplicated inside command
  files, docs, or scripts.
- **Tests stay in `tests/`** and mirror the structure of the code they
  test.
- **Docs stay in `docs/`** (except README, CHANGELOG, CONTRIBUTING,
  SECURITY, CODE_OF_CONDUCT, LICENSE which live at the root).

### Adding a new feature

A new feature landing in the repo requires **all of**:

1. Code in the appropriate module/script directory
2. At least one test in `tests/` that covers the main pass and fail paths
3. Documentation update if user-visible behavior changed
4. CHANGELOG entry under `## [Unreleased]`
5. Inline comments for any non-obvious decision

Incomplete additions **should be rejected in review**.

---

## 3. Code organization and reuse

**MUST NOT** write the same code twice.

### DRY — don't repeat yourself

- If the same logic appears in two scripts, extract it to a shared
  library and source/import it.
- If the same regex or constant appears in two files, define it once in
  config and load it in both.
- If the same markdown section appears in two templates, extract it to
  a shared fragment.

### Extract helpers when a function gets complex

> **Rule of thumb:** if a function does more than one thing, or needs
> more than one sentence to explain, extract a helper with a descriptive
> name.

Signs a function needs extraction:
- Nesting depth > 3
- Function body > 30 lines
- Multiple distinct responsibilities
- A comment starts with "First we... then we... then we..."

### Example — before and after

**Before** — one function doing too much:

```
check_user(u):
  if u exists:
    if u has role:
      if role is active:
        if role includes permission:
          return ok
        else error "no permission"
      else error "role inactive"
    else error "no role"
  else error "no user"
```

**After** — decomposed with early returns:

```
check_user(u):
  user_exists(u) || return "no user"
  role = role_for(u); role || return "no role"
  role_active(role) || return "role inactive"
  has_permission(role, action) || return "no permission"
  return ok
```

Helpers are reusable across call sites.

---

## 4. File length and complexity

**SHOULD** keep files short and focused.

### Target sizes

| File type | Target | Hard ceiling |
|---|---|---|
| Script (bash, python, etc.) | < 200 lines | 400 lines |
| Source module | < 300 lines | 500 lines |
| Template / markdown | < 200 lines | 400 lines |
| Doc | < 500 lines | 1000 lines |
| Config file | < 150 lines | 300 lines |

A file that hits the hard ceiling **SHOULD** be split before the next
feature lands in it.

### Complexity signals

- A function > 50 lines → extract helpers
- A step-by-step doc > 20 steps → split into sub-docs with a table of contents
- A config file > 300 lines → split into topic-specific files

---

## 5. Naming conventions

**MUST** follow these consistently.

### Files

| Kind | Pattern | Example |
|---|---|---|
| Script | `kebab-case.sh` | `run-migrations.sh` |
| Module | language idiom | `kebab-case.ts`, `snake_case.py` |
| Template | `kebab-case.md` / `kebab-case.yml` | `feature-spec.md` |
| Test | `kebab-case.test.<ext>` | `run-migrations.test.sh` |
| Doc | `SCREAMING-KEBAB.md` | `CUSTOMIZATION.md`, `DEVELOPMENT-RULES.md` |

### Identifiers

- **Functions**: `snake_case` in bash/python, `camelCase` in JS/TS
- **Local variables**: same as functions in that language
- **Constants**: `SCREAMING_SNAKE_CASE`
- **Environment variables**: `PROJECT_NAME_<NAME>` prefix to avoid collisions

### General

- **Meaningful names.** `is_active_session`, `cart_total`, `retry_after_ms` — not `x`, `tmp`, `ret`.
- **No abbreviations** except industry standard (`id`, `url`, `api`).
- **Boolean names** start with `is_`, `has_`, `should_`, `can_`.

---

## 6. Inline documentation

**MUST** document intent, not mechanics.

### What to comment

- ✅ **Why** a non-obvious approach was chosen
- ✅ **Surprising behavior** ("macOS bash 3.2 fails on empty arrays under set -u")
- ✅ **Invariants** that must hold ("this log is append-only")
- ✅ **Workarounds** with the underlying bug linked
- ✅ **Security-relevant constraints** ("never print the secret value")

### What NOT to comment

- ❌ **What the code does** when it's obvious from reading
- ❌ **Restating the function name** ("this function validates input")
- ❌ **Redundant type or signature info** already visible
- ❌ **Temporary refactor notes** ("moved from X", "renamed from Y")

### Script headers

Every script should start with:

```
# <one-line purpose>
#
# Usage: <script-name> <args>
#
# Exits: 0 on success, non-zero on failure.
# Reads: <input files or env vars>
# Writes: <output files>
```

---

## 7. Unit test rules

**SHOULD** add tests incrementally; **MUST** add tests when fixing bugs.

### Philosophy

We don't aim for 100% coverage. We aim for:

- Every **bug fix** lands with a regression test that would have caught it
- Every **new feature** lands with at least one pass case and one failure case
- Every **new helper** lands with a test for each distinct input shape

Coverage grows organically from real use, not from chasing a number.

### Writing a test

Every test file **MUST**:

1. Be runnable standalone (no complex setup required)
2. Create its own isolated fixture (temp directory, in-memory DB, etc.)
3. Clean up on exit
4. Exit 0 on pass, non-zero on fail
5. Print a human-readable summary

### Running tests

Tests **MUST** be runnable by a human in one command with no extra tooling:

```bash
bash tests/run.sh        # or: pnpm test / pytest / go test
```

The test output should be readable at 3 AM during an incident — tell
the human what's broken, not what the framework thinks happened.

### Documenting tests

Every test directory **MUST** have a `README.md` that explains:

- How to run the tests (copy-paste ready commands)
- What each test covers (one line per test)
- How to add a new test (pointer to the template)
- What the expected output looks like when everything passes

---

## 8. Readability and maintainability

**MUST** be readable by a human who has never seen the project before.

### Principles

- **One idea per line.** Long boolean chains belong in named variables.
- **Meaningful names.** `is_clean`, `has_inline_prompts` — not `x`, `tmp`.
- **Early returns.** Validate inputs at the top and exit early on failure.
- **No dead code.** Delete unused functions, commented-out blocks, stale TODOs.
- **No magic numbers.** `MAX_RETRIES = 3` not a bare `3` in a loop.
- **Consistent indentation.** Follow the language's standard (2 or 4 spaces).

### When in doubt

> Write it the way you'd want someone to read it at 3 AM while fixing a
> production incident they didn't cause.

If the answer is "I'd rewrite it cleaner before I could debug it,"
rewrite it now.

---

## 9. Review checklist

Before opening a PR, confirm:

- [ ] Commit messages follow §1 — no internal context leaks, imperative mood, under 72 chars
- [ ] New files live in the right directory per §2
- [ ] No duplicated code across scripts, templates, or docs per §3
- [ ] Files are under the hard ceiling per §4
- [ ] Names follow the conventions in §5
- [ ] Inline comments explain *why*, not *what* per §6
- [ ] New behavior has at least one test per §7
- [ ] Bug fixes land with a regression test
- [ ] CHANGELOG `## [Unreleased]` updated
- [ ] `tests/run.sh` (or project equivalent) passes locally
- [ ] User-visible documentation updated if behavior changed

---

## Enforcement

These rules are enforced by:

1. **Human review** — reviewers reference this doc in comments
2. **CI test suite** — all tests pass on every PR
3. **Spec-kit post-implementation audit** (if using `speckit-security`)
   catches inline prompts, committed secrets, and direct SDK imports

Violations **block** PR merge.

Ask for guidance early if you're unsure whether a change complies —
it's cheaper than rewriting after review.

---

*Installed by `/speckit.tekimax-security.install-rules` · Customize freely for your project.*
