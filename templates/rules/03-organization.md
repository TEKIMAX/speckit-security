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
