---
description: "Install a DEVELOPMENT-RULES.md into the user's project with commit, file-structure, code-org, naming, docs, and test rules"
---

# Install Development Rules

Copy the `speckit-security` development rules template into the user's
project so their team inherits the same discipline: clean commit
messages, hooks-in-hooks-directory, DRY, helper extraction, file length
limits, naming conventions, inline documentation for intent, and
incremental unit test requirements.

## User Input

$ARGUMENTS

## Context

The rules are opinionated but stack-agnostic and have been battle-tested
on this extension's own codebase. The goal is to raise the baseline
engineering discipline of any project adopting `speckit-security`
without forcing them to invent conventions from scratch.

## Steps

1. **Locate the project root** — the directory containing `.specify/`.

2. **Determine the target path** — default is `docs/DEVELOPMENT-RULES.md`
   at the project root. If the user passed a path in `$ARGUMENTS`, use
   that instead.

3. **Check for an existing file at the target path.** If one exists:
   - **Do not overwrite silently.** Back it up to
     `<target>.backup-<date>.md` and note the backup path.
   - Or exit and ask the user to confirm overwrite.

4. **Read the template** from
   `.specify/extensions/tekimax-security/templates/development-rules.md`.

5. **Substitute variables** in the template:
   - `{{PROJECT_NAME}}` → the project name from `.specify/init-options.json`
     or the directory name if the JSON isn't present.

6. **Write the rendered file** to the target path. Create the `docs/`
   directory if it doesn't exist.

7. **Update the project's `CONTRIBUTING.md` if present** to add a
   reference:

   ```markdown
   ## Development Rules

   See [docs/DEVELOPMENT-RULES.md](docs/DEVELOPMENT-RULES.md) for the
   full development discipline — commit messages, file structure,
   code organization, naming, documentation, and unit test rules.
   ```

   If no `CONTRIBUTING.md` exists, skip this step and note it in the
   output.

8. **Print a summary** of what was installed:

   ```
   ✓ Installed DEVELOPMENT-RULES.md at docs/DEVELOPMENT-RULES.md
   ✓ Added reference in CONTRIBUTING.md

   Next steps:
     1. Review the rules and customize §5 (naming) for your language
     2. Remove any sections that don't apply (e.g. bash-specific rules
        for a TypeScript project)
     3. Commit the file
     4. Link it from your CONTRIBUTING.md if you don't already
   ```

## Rules

- **Never overwrite an existing file without backing it up.**
- **Never modify files outside the project root.**
- **Leave a visible note** in the installed file indicating which
  command installed it and that it can be freely customized.
- The installed rules are **a starting point**, not a straitjacket.
  Teams are expected to adapt them to their language, framework, and
  conventions.
