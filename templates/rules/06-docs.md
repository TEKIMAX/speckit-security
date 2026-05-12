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
