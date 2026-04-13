---
description: "Install development rules into the project — writes docs/DEVELOPMENT-RULES.md, appends to .specify/memory/constitution.md, and writes the agent-specific context file"
scripts:
  sh: .specify/extensions/tekimax-security/scripts/bash/install-rules.sh
---

# Install Development Rules

Install the speckit-security development discipline into the user's
project so both humans and the active AI agent inherit it. The rules
cover commit messages, file structure, DRY, helper extraction, file
length, naming, inline documentation, unit test requirements, and the
review checklist.

## User Input

$ARGUMENTS

## Context

Writing the rules to a single `docs/` file is not enough — the AI
agent only reads files it's explicitly directed to. To make the rules
*binding* at runtime, they also need to land in the spec-kit
constitution (which every spec-kit-aware agent reads at session start)
and in the agent's native system-context file.

This command delegates to a bash helper that handles all three writes
atomically, detects the active agent from `.specify/init-options.json`,
and safely appends to existing files without clobbering them.

## Steps

1. Run the installer script:

   ```bash
   bash {SCRIPT}
   ```

   Optional arguments:
   - `--docs <path>` — override the default `docs/DEVELOPMENT-RULES.md` target
   - `--project-name <name>` — override project name detection
   - `--force` — replace an existing `## Development Rules` section
     in the constitution or agent context file instead of skipping it

2. The script performs three writes:

   **Target 1 — `docs/DEVELOPMENT-RULES.md`**

   Full human-readable rules. Template is copied from
   `.specify/extensions/tekimax-security/templates/development-rules.md`
   with `{{PROJECT_NAME}}` substituted. Existing files are backed up
   with a timestamped suffix before being overwritten.

   **Target 2 — `.specify/memory/constitution.md`**

   Spec-kit's project constitution. Every spec-kit-aware agent reads
   this at session start, so rules written here bind every agent the
   user interacts with. The script appends a `## Development Rules`
   section with the key principles (short form) and a pointer to the
   full doc. If the section already exists, the script skips it
   unless `--force` was passed.

   **Target 3 — Agent-specific context file**

   The agent is detected from `.specify/init-options.json` (`ai`
   field). The script maps the agent to its native context file:

   | Agent | File |
   |---|---|
   | `claude` | `CLAUDE.md` |
   | `copilot` | `.github/copilot-instructions.md` |
   | `gemini` | `GEMINI.md` |
   | `cursor` / `cursor-agent` | `.cursorrules` |
   | `windsurf` | `.windsurfrules` |
   | `opencode`, `codex`, `kiro-cli`, and everything else | `AGENTS.md` |

   The same short-form rules section is appended to the detected
   context file. Same safety rules as the constitution: skip if
   section exists, unless `--force`.

3. The script prints a summary box with the three target paths and
   whether each was created, appended, or skipped.

4. If the user wants to review before committing, they can diff the
   three files against the backups or against their git index.

## Rules

- **Never silently overwrite.** The full `docs/DEVELOPMENT-RULES.md`
  is backed up before replacement; the constitution and agent context
  files are append-only unless `--force` is passed.
- **Never modify files outside the project root.** The script uses
  relative paths and refuses to write to absolute paths.
- **Detect the agent correctly.** If `.specify/init-options.json` is
  missing or malformed, default to `generic` + `AGENTS.md`.
- **Print what changed.** The summary box is the contract — every run
  tells the user exactly which files were touched.
