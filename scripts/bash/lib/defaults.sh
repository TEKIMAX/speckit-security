#!/usr/bin/env bash
# Shared security-pattern defaults for speckit-security scripts.
#
# Sourced by audit.sh and gate-check.sh so both scripts use the same
# canonical pattern sets. User config extends these — see config.sh
# for the reader and docs/CUSTOMIZATION.md for the schema.
#
# Usage:
#     source "$SCRIPT_DIR/lib/defaults.sh"

# Guard: defaults.sh uses Python for path resolution and JSONL writing.
if ! command -v python3 >/dev/null 2>&1; then
  echo "error: speckit-security requires python3 but it is not installed." >&2
  exit 2
fi

# ── Path confinement ────────────────────────────────────────────────
#
# require_inside_project <path> <label>
#
# Resolves <path> to its canonical absolute form and verifies it lives
# inside the current working directory (the project root). Exits with
# error code 2 if the path escapes the project — prevents path
# traversal via "../..", symlinks, or absolute paths passed as args.
#
# Uses `pwd -P` (physical path, no symlinks) and Python's
# os.path.realpath so the check works on both macOS and Linux.
require_inside_project() {
  local target="$1"
  local label="${2:-path}"
  local project_root
  project_root="$(pwd -P)"

  local resolved
  resolved=$(python3 -c "
import os, sys
# Resolve the target relative to the project root
target = sys.argv[1]
root = sys.argv[2]
# If target is relative, join with root first
if not os.path.isabs(target):
    target = os.path.join(root, target)
resolved = os.path.realpath(target)
print(resolved)
" "$target" "$project_root")

  # Check the resolved path starts with the project root
  if [[ "$resolved" != "$project_root"* ]]; then
    echo "error: $label escapes the project root." >&2
    echo "  resolved: $resolved" >&2
    echo "  project:  $project_root" >&2
    echo "  speckit-security scripts are confined to the project directory." >&2
    exit 2
  fi
}

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

# join_secret_re <array-name>
#
# Joins the named array into a single ERE alternation string, printed
# to stdout. Usage:
#   SECRET_RE=$(join_secret_re SECRET_PATTERNS)
#
# Uses eval instead of nameref (local -n) for bash 3.2 compatibility
# (macOS default). The array name is trusted — always a hardcoded
# constant from our own scripts, never user input.
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
#
# Uses eval for bash 3.2 compatibility (see join_secret_re above).
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

# jsonl_append <file> <arg1> <arg2> ...
#
# Safely appends a JSONL line to <file>. All arguments after <file>
# are passed to Python as sys.argv and assembled into the JSON object
# there, so shell metacharacters in values cannot break the output.
#
# Each pair of arguments is a key-value pair. Values that look like
# integers are stored as JSON numbers; everything else as strings.
# Nested objects use dot-notation keys (e.g. "gates.A" "pass").
jsonl_append() {
  local file="$1"; shift
  python3 - "$file" "$@" <<'PY'
import json, sys

path = sys.argv[1]
pairs = sys.argv[2:]
obj = {}
for i in range(0, len(pairs), 2):
    key = pairs[i]
    val = pairs[i + 1]
    # Attempt integer conversion for numeric fields
    try:
        val = int(val)
    except (ValueError, TypeError):
        pass
    # Support dot-notation for one level of nesting (e.g. "gates.A")
    parts = key.split(".", 1)
    if len(parts) == 2:
        obj.setdefault(parts[0], {})[parts[1]] = val
    else:
        obj[key] = val

with open(path, "a") as f:
    f.write(json.dumps(obj) + "\n")
PY
}

# jsonl_append_chained <file> <key1> <val1> ...
#
# Like jsonl_append but adds a "prev_hash" field containing the
# SHA-256 of the previous line in <file> (or "genesis" if the file
# is empty/missing). Creates a lightweight tamper-evident hash chain
# without any cryptographic signing dependencies.
jsonl_append_chained() {
  local file="$1"; shift
  python3 - "$file" "$@" <<'PY'
import hashlib, json, os, sys

path = sys.argv[1]
pairs = sys.argv[2:]
obj = {}
for i in range(0, len(pairs), 2):
    key = pairs[i]
    val = pairs[i + 1]
    try:
        val = int(val)
    except (ValueError, TypeError):
        pass
    parts = key.split(".", 1)
    if len(parts) == 2:
        obj.setdefault(parts[0], {})[parts[1]] = val
    else:
        obj[key] = val

# Compute prev_hash from the last line of the existing file
prev_hash = "genesis"
if os.path.isfile(path):
    with open(path, "rb") as f:
        lines = f.read().rstrip(b"\n").split(b"\n")
        if lines and lines[-1]:
            prev_hash = "sha256:" + hashlib.sha256(lines[-1]).hexdigest()

obj["prev_hash"] = prev_hash

with open(path, "a") as f:
    f.write(json.dumps(obj) + "\n")
PY
}
