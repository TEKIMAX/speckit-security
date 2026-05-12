#!/usr/bin/env bash
# Shared security-pattern defaults for speckit-security scripts.
#
# Sourced by audit.sh and gate-check.sh so both scripts use the same
# canonical pattern sets. User config extends these — see config.sh
# for the reader and docs/CUSTOMIZATION.md for the schema.
#
# Path confinement (require_inside_project) lives in lib/path.sh and
# JSONL writers (jsonl_append, jsonl_append_chained) live in
# lib/jsonl.sh. This file sources both so existing callers that only
# `source lib/defaults.sh` continue to get the full surface.
#
# Usage:
#     source "$SCRIPT_DIR/lib/defaults.sh"

_DEFAULTS_DIR="${BASH_SOURCE[0]%/*}"
# shellcheck source=path.sh
source "$_DEFAULTS_DIR/path.sh"
# shellcheck source=jsonl.sh
source "$_DEFAULTS_DIR/jsonl.sh"

# ── Pattern defaults ───────────────────────────────────────────────

# Inline prompt detection — ERE regex alternation.
# Catches common system-prompt preambles and chat-ML markers.
DEFAULT_INLINE_PROMPT_RE='([Yy]ou[[:space:]]+are[[:space:]]+(a|an)[[:space:]]+(helpful|AI|virtual|assistant|chatbot|expert|friendly|knowledgeable|precise|professional|skilled|senior|world|large[[:space:]]+language|language[[:space:]]+model|conversational|advanced|state-of-the-art)|<\|system\|>|<\|im_start\|>system|^[[:space:]]*(system|assistant|SYSTEM|ASSISTANT)[[:space:]]*:[[:space:]])'

# Secret patterns — ERE fragments joined into an alternation by callers.
DEFAULT_SECRET_PATTERNS=(
  'sk_live_[0-9a-zA-Z]{24,}'
  'sk_test_[0-9a-zA-Z]{24,}'
  '-----BEGIN (RSA |EC |DSA |OPENSSH |ENCRYPTED )?PRIVATE KEY-----'
  'xoxb-[0-9a-zA-Z-]{20,}'
  'ghp_[0-9a-zA-Z]{36}'
  'gho_[0-9a-zA-Z]{36}'
  'ghs_[0-9a-zA-Z]{36}'
  'AKIA[0-9A-Z]{16}'
  'AIza[0-9A-Za-z_\-]{35}'
)

# Gateway allowlist — paths whose imports of model SDKs are considered
# legitimate (the gateway client itself). Match is anchored: an entry
# matches only at an exact path, as a directory prefix with a '/'
# boundary, or with a file-extension append. See _is_gateway_allowed.
DEFAULT_GATEWAY_ALLOWLIST=(
  'src/ai/gateway'
)

# Polyglot file extensions scanned by Gate F and the audit. Secrets and
# inline prompts frequently live outside TS/Py — CI YAML, Terraform,
# shell scripts are common leak sources. User config extends this via
# audit.include_globs.
DEFAULT_INCLUDE_EXTS=(
  "*.ts" "*.tsx" "*.js" "*.jsx" "*.mjs" "*.cjs"
  "*.py" "*.rb" "*.go" "*.rs" "*.java" "*.kt" "*.swift" "*.php"
  "*.sh" "*.bash" "*.zsh"
  "*.yml" "*.yaml" "*.json" "*.toml" "*.tf" "*.tfvars"
  "*.md" "*.mdx"
)

# Path fragments skipped during recursive scans. User config extends
# this via audit.exclude_paths.
DEFAULT_EXCLUDE_PATTERNS=(
  "node_modules/"
  ".git/"
  "dist/"
  "build/"
  "target/"
  "vendor/"
  ".next/"
  "out/"
  ".source/"
  ".wrangler/"
  ".venv/"
  "venv/"
  "__pycache__/"
  ".tekimax-security/"
  "coverage/"
  ".nuxt/"
)

# Direct-SDK import patterns flagged outside the gateway allowlist.
# User config extends this via audit.direct_sdk_patterns.
DEFAULT_DIRECT_SDK_PATTERNS=(
  "@google/genai"
  "@anthropic-ai/sdk"
  "openai"
  "cohere-ai"
  "@mistralai/mistralai"
  "@aws-sdk/client-bedrock-runtime"
  "replicate"
  "together-ai"
)

# ── Helpers operating on the pattern arrays ────────────────────────
#
# All take an array NAME (not the array itself) and read it via `eval`
# for bash 3.2 compatibility (macOS default ships bash 3.2; nameref
# `local -n` requires 4.3+). The array name is always a hardcoded
# constant from our own scripts, never user input.

# join_secret_re <array-name>
#
# Joins the named array into a single ERE alternation, printed to
# stdout. Usage:
#   SECRET_RE=$(join_secret_re SECRET_PATTERNS)
join_secret_re() {
  local _arrname=$1
  local result=""
  eval "local _items=(\"\${${_arrname}[@]}\")"
  for p in "${_items[@]}"; do
    if [ -z "$result" ]; then
      result="$p"
    else
      result="${result}|${p}"
    fi
  done
  printf '%s' "$result"
}

# _is_gateway_allowed <path> <allowlist-array-name>
#
# Returns 0 if the file path matches any entry in the named allowlist,
# using an anchored rule:
#   - exact match                        (src/ai/gateway)
#   - directory prefix with '/' boundary (src/ai/gateway/foo.ts)
#   - file-extension append              (src/ai/gateway.ts)
#   - nested occurrence                  (apps/api/src/ai/gateway/...)
# Crucially: src/ai/gateway does NOT silently match
# src/ai/gateway-bypass.ts — teams list full file paths or directory
# entries to cover a whole area.
_is_gateway_allowed() {
  local path="${1#./}"
  local _arrname=$2
  eval "local _items=(\"\${${_arrname}[@]}\")"
  for entry in "${_items[@]}"; do
    local e="${entry%/}"
    case "$path" in
      "$e"|"$e"/*|"$e".*|*/"$e"|*/"$e"/*|*/"$e".*) return 0 ;;
    esac
  done
  return 1
}

# build_exclude_regex <array-name>
#
# Prints an ERE alternation suitable for `grep -vE "(...)"` from the
# named array. Path separators and regex metacharacters are escaped.
build_exclude_regex() {
  local _arrname=$1
  eval "local _items=(\"\${${_arrname}[@]}\")"
  local re="" item esc
  for item in "${_items[@]}"; do
    esc=$(printf '%s' "$item" | sed 's/[][\.^$*+?{}|()\\/]/\\&/g')
    if [ -z "$re" ]; then re="$esc"; else re="$re|$esc"; fi
  done
  printf '%s' "$re"
}

# scan_staged_files <include-array> <exclude-array>
#
# Prints the list of files in the git index (added/copied/modified)
# filtered to the named include-extension array and minus the named
# exclude-path array. Empty output when not in a git work tree.
scan_staged_files() {
  local _incname=$1
  local _excname=$2
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return 0
  fi
  eval "local _includes=(\"\${${_incname}[@]}\")"
  eval "local _excludes=(\"\${${_excname}[@]}\")"

  local inc_re="" pat ext_pat
  for pat in "${_includes[@]}"; do
    ext_pat="${pat#\*}"
    ext_pat=$(printf '%s' "$ext_pat" | sed 's/\./\\./g; s/\*/.\*/g')
    if [ -z "$inc_re" ]; then inc_re="$ext_pat\$"; else inc_re="$inc_re|$ext_pat\$"; fi
  done

  local exc_re=""
  for pat in "${_excludes[@]}"; do
    local esc
    esc=$(printf '%s' "$pat" | sed 's/[][\.^$*+?{}|()\\/]/\\&/g')
    if [ -z "$exc_re" ]; then exc_re="$esc"; else exc_re="$exc_re|$esc"; fi
  done

  git diff --cached --name-only --diff-filter=ACM 2>/dev/null \
    | grep -E "(${inc_re})" 2>/dev/null \
    | { if [ -n "$exc_re" ]; then grep -vE "($exc_re)"; else cat; fi; } \
    || true
}
