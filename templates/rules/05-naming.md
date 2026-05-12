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
