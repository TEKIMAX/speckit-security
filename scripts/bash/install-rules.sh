#!/usr/bin/env bash
# Install development rules into the user's project.
#
# Writes to three targets so the rules are both readable by humans and
# binding on AI agents at runtime:
#   1. docs/DEVELOPMENT-RULES.md     — full human-readable reference
#   2. .specify/memory/constitution.md — spec-kit constitution (every agent reads this)
#   3. <agent-context-file>           — agent-specific system context
#
# Invoked by: speckit.tekimax-security.install-rules
#
# Usage: install-rules.sh [--docs <path>] [--project-name <name>] [--force]
#
# Exits: 0 on success, 1 on intended failure, 2 on error.
# Reads: .specify/init-options.json (for agent detection)
#        .specify/extensions/tekimax-security/templates/rules/*.md
# Writes: see targets above.

set -euo pipefail

# install-rules.sh needs only path confinement from the shared lib.
_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/path.sh
source "$_SCRIPT_DIR/lib/path.sh"

# --- arg parsing -----------------------------------------------------

docs_path="docs/DEVELOPMENT-RULES.md"
project_name=""
force=0

while [ $# -gt 0 ]; do
  case "$1" in
    --docs)          docs_path="$2";   shift 2 ;;
    --project-name)  project_name="$2"; shift 2 ;;
    --force)         force=1;          shift   ;;
    -h|--help)
      sed -n '2,15p' "$0"
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

# --- path confinement -----------------------------------------------
# Validate that --docs path stays inside the project root. Without
# this, `--docs /etc/crontab` would write outside the project.
require_inside_project "$docs_path" "--docs path"

# --- locate the rules fragment dir ----------------------------------
#
# When installed via `specify extension add`, fragments live under
# .specify/extensions/tekimax-security/templates/rules/. From a source
# checkout, fragments live at ../../templates/rules/ relative to this
# script. Each fragment is < 200 lines (rule §4); assembled output is
# the full DEVELOPMENT-RULES.md.

ext_dir=".specify/extensions/tekimax-security"
if [ -d "$ext_dir/templates/rules" ]; then
  rules_dir="$ext_dir/templates/rules"
else
  rules_dir="$_SCRIPT_DIR/../../templates/rules"
fi

if [ ! -d "$rules_dir" ]; then
  echo "error: rules fragment directory not found at $rules_dir" >&2
  exit 2
fi

assemble_rules() {
  # Concatenate fragments in sorted order (numeric prefix gives order).
  # Each fragment ends with its own '---' separator, so no glue needed.
  while IFS= read -r fragment; do
    cat "$fragment"
    printf '\n'
  done < <(find "$rules_dir" -maxdepth 1 -name '*.md' -type f | sort)
}

# --- project name detection -----------------------------------------

if [ -z "$project_name" ]; then
  if [ -f ".specify/init-options.json" ]; then
    project_name=$(
      python3 -c 'import json,sys; d=json.load(open(".specify/init-options.json")); print(d.get("project_name", d.get("name", "")))' 2>/dev/null || true
    )
  fi
fi
if [ -z "$project_name" ]; then
  project_name="$(basename "$(pwd)")"
fi

# --- agent detection -------------------------------------------------

agent_id="generic"
if [ -f ".specify/init-options.json" ]; then
  agent_id=$(
    python3 -c 'import json,sys; d=json.load(open(".specify/init-options.json")); print(d.get("ai", d.get("agent", "generic")))' 2>/dev/null || echo "generic"
  )
fi

agent_context_file="AGENTS.md"
case "$agent_id" in
  claude)         agent_context_file="CLAUDE.md" ;;
  copilot)        agent_context_file=".github/copilot-instructions.md" ;;
  gemini)         agent_context_file="GEMINI.md" ;;
  cursor|cursor-agent) agent_context_file=".cursorrules" ;;
  windsurf)       agent_context_file=".windsurfrules" ;;
  opencode|codex|kiro-cli|auggie|bob|codebuddy|forge|iflow|junie|kilocode|kimi|pi|qodercli|qwen|roo|shai|tabnine|trae|vibe|generic|*)
                  agent_context_file="AGENTS.md" ;;
esac

# --- helpers --------------------------------------------------------

backup_if_exists() {
  local path="$1"
  if [ -f "$path" ]; then
    local backup="${path}.backup-$(date +%Y%m%d-%H%M%S)"
    cp "$path" "$backup"
    echo "$backup"
  fi
}

substitute_project_name() {
  local content="$1"
  printf '%s\n' "$content" | sed "s|{{PROJECT_NAME}}|${project_name}|g"
}

short_rules_block() {
  cat <<'BLOCK'
## Development Rules

This project follows the speckit-security development discipline. Full
rules live at `docs/DEVELOPMENT-RULES.md`. Agents and contributors MUST
follow these when making changes:

1. **Commit messages** describe the change, not the process of making
   it. No AI attribution. No conversation context. No scrub history.
   Imperative mood, under 72 characters in the subject line.
2. **File structure** — hooks stay in the hooks directory. Scripts in
   `scripts/`. Templates in `templates/`. Tests in `tests/`. Docs in
   `docs/`. Never inline logic where structure belongs.
3. **Code organization** — don't repeat yourself. Extract a helper
   when a function does more than one thing or exceeds 30 lines.
4. **File length** — target < 200 lines per script, hard ceiling 400.
   Split before the next feature lands in an over-long file.
5. **Naming** — kebab-case files, snake_case bash, camelCase JS/TS,
   SCREAMING_SNAKE constants. Boolean names start with is_/has_/can_/should_.
6. **Inline documentation** — comment *why*, not *what*. Explain
   non-obvious decisions, invariants, workarounds, surprising behavior.
7. **Unit tests** — every bug fix lands with a regression test. Every
   new feature has at least one pass case and one failure case. Tests
   are runnable in one command with zero package-manager dependencies.
8. **Readability** — one idea per line. Early returns. No magic numbers.
   Write it the way you'd want to read it at 3 AM during a prod incident.

Violations block PR merge. See `docs/DEVELOPMENT-RULES.md` for the full
rationale, examples, and review checklist.
BLOCK
}

append_section_if_missing() {
  local target="$1"
  local marker="## Development Rules"

  mkdir -p "$(dirname "$target")"

  if [ ! -f "$target" ]; then
    # Create file with a minimal header + the rules block
    {
      echo "# ${project_name}"
      echo
      short_rules_block
    } > "$target"
    echo "created"
    return
  fi

  if grep -qF "$marker" "$target"; then
    if [ $force -eq 0 ]; then
      echo "skipped (section already present — re-run with --force to replace)"
      return
    fi
    # Force mode: remove the old section and re-append
    python3 - "$target" <<'PY'
import re, sys
path = sys.argv[1]
with open(path) as f:
    content = f.read()
# Remove existing "## Development Rules" section up to next H2 or EOF
pattern = re.compile(r'\n## Development Rules\n.*?(?=\n## |\Z)', re.DOTALL)
cleaned = pattern.sub('', content)
with open(path, "w") as f:
    f.write(cleaned.rstrip() + "\n")
PY
  fi

  {
    echo
    short_rules_block
  } >> "$target"
  echo "appended"
}

# --- 1. Full rules → docs/ -----------------------------------------

mkdir -p "$(dirname "$docs_path")"

docs_backup=""
if [ -f "$docs_path" ] && [ $force -eq 0 ]; then
  docs_backup=$(backup_if_exists "$docs_path")
fi

template_content=$(assemble_rules)
rendered=$(substitute_project_name "$template_content")
printf '%s\n' "$rendered" > "$docs_path"

# --- 2. Constitution → .specify/memory/constitution.md --------------

constitution_path=".specify/memory/constitution.md"
constitution_result=$(append_section_if_missing "$constitution_path")

# --- 3. Agent context file → detected per agent ---------------------

context_result=$(append_section_if_missing "$agent_context_file")

# --- summary --------------------------------------------------------

echo
echo "┌──────────────────────────────────────────────────────┐"
echo "│ speckit-security — install-rules                     │"
echo "├──────────────────────────────────────────────────────┤"
printf "│ Project:   %-42s │\n" "$project_name"
printf "│ Agent:     %-42s │\n" "$agent_id"
echo "├──────────────────────────────────────────────────────┤"
printf "│ docs:      %-42s │\n" "$docs_path"
if [ -n "$docs_backup" ]; then
  printf "│   backup:  %-42s │\n" "$docs_backup"
fi
printf "│ constit.:  %-42s (%s)\n" "$constitution_path" "$constitution_result"
printf "│ context:   %-42s (%s)\n" "$agent_context_file" "$context_result"
echo "└──────────────────────────────────────────────────────┘"
echo
echo "Next steps:"
echo "  1. Review docs/DEVELOPMENT-RULES.md and customize for your language"
echo "  2. Commit the three new/updated files"
echo "  3. Reference the rules in code review going forward"
