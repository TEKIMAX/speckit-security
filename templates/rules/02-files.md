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
