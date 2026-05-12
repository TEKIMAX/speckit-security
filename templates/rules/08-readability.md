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
