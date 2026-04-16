#!/usr/bin/env bash
# Config reader for speckit-security scripts.
#
# Parses tekimax-security-config.yml using a minimal Python helper
# and exposes sourceable functions for reading scalars and lists by
# dotted path. Not a full YAML parser; handles the specific shapes
# found in config/tekimax-security-config.template.yml only:
#
#   - Top-level scalars:           key: value
#   - Nested mappings up to 3-deep: a.b.c
#   - Lists of strings:             key:\n  - item
#   - Quoted and unquoted scalars
#   - '#' line comments
#
# Usage (sourced into other scripts):
#
#     source "$(dirname "$0")/lib/config.sh"
#     value=$(config_get "$CONFIG" "red_team.staging_url")
#     mapfile -t patterns < <(config_list "$CONFIG" "audit.secret_patterns")
#
# If the config file is missing or the key is absent, both functions
# print nothing and exit 0, so callers can fall back to their built-in
# defaults without special-casing errors.

# Guard: config parsing requires Python 3. Fail fast with a clear
# message instead of silently falling back to empty values (which
# would weaken security coverage without any visible error).
if ! command -v python3 >/dev/null 2>&1; then
  echo "error: speckit-security requires python3 but it is not installed." >&2
  echo "  Install Python 3 and ensure it is on your PATH." >&2
  exit 2
fi

# Shared Python parser used by both config_get and config_list. It
# prints either a single scalar line or the list items one per line
# for the requested dotted path.
_config_query() {
  local file="$1"
  local path="$2"
  local mode="$3"  # "scalar" | "list"
  [ -n "$file" ] && [ -f "$file" ] || return 0
  python3 - "$file" "$path" "$mode" <<'PY'
import sys, re

file_path, dotted, mode = sys.argv[1], sys.argv[2], sys.argv[3]

def unquote(s):
    s = s.strip()
    if len(s) >= 2 and s[0] == s[-1] and s[0] in ('"', "'"):
        return s[1:-1]
    return s

with open(file_path) as f:
    raw_lines = f.readlines()

# Parse into a nested Python dict/list structure. Indent-driven,
# YAML subset only.
root = {}
stack = [(-1, root)]  # (indent, container)

for raw in raw_lines:
    line = raw.rstrip("\n")
    if not line.strip() or line.lstrip().startswith("#"):
        continue
    stripped = line.lstrip(" ")
    indent = len(line) - len(stripped)

    while stack and stack[-1][0] >= indent:
        stack.pop()
    parent = stack[-1][1]

    if stripped.startswith("- "):
        # List item. If parent is still a dict (because we didn't know
        # it would become a list), convert it by replacing it in its
        # own parent. We track lists via the '[]' sentinel placeholder.
        value = unquote(stripped[2:])
        if isinstance(parent, list):
            parent.append(value)
        continue

    m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*)$", stripped)
    if not m:
        continue
    key, rest = m.group(1), m.group(2)
    # Strip inline comments from unquoted scalars
    if rest and not (rest.startswith('"') or rest.startswith("'")):
        rest = re.sub(r"\s+#.*$", "", rest).rstrip()

    if rest:
        # Scalar
        if isinstance(parent, dict):
            parent[key] = unquote(rest)
        continue

    # Empty value: start a new block. We don't know yet whether it
    # will be a dict or a list, so create a list by default; if we
    # see a non-'-' child it'll be converted to a dict below.
    new_block = []
    if isinstance(parent, dict):
        parent[key] = new_block
    stack.append((indent, new_block))

# Second pass conversion: any 'list' that was actually used as a
# mapping (because a nested `key: value` was encountered) will
# already be wrong in the parse above. To handle mappings-in-blocks
# correctly, re-run the parse with a smarter strategy that decides
# container type on first child.
# -- simpler: re-parse with a peek ahead.

def parse(lines):
    root = {}
    stack = [(-1, root)]

    # Precompute (indent, kind, content) tuples
    entries = []
    for raw in lines:
        line = raw.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        stripped = line.lstrip(" ")
        indent = len(line) - len(stripped)
        entries.append((indent, stripped))

    for i, (indent, stripped) in enumerate(entries):
        while stack and stack[-1][0] >= indent:
            stack.pop()
        parent = stack[-1][1]

        if stripped.startswith("- "):
            value = unquote(stripped[2:])
            if isinstance(parent, list):
                parent.append(value)
            continue

        m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*)$", stripped)
        if not m:
            continue
        key, rest = m.group(1), m.group(2)
        if rest and not (rest.startswith('"') or rest.startswith("'")):
            rest = re.sub(r"\s+#.*$", "", rest).rstrip()

        if rest:
            if isinstance(parent, dict):
                parent[key] = unquote(rest)
            continue

        # Peek at next non-empty entry to decide container type
        next_entry = None
        for j in range(i + 1, len(entries)):
            next_entry = entries[j]
            break
        if next_entry and next_entry[0] > indent and next_entry[1].startswith("- "):
            new_block = []
        else:
            new_block = {}
        if isinstance(parent, dict):
            parent[key] = new_block
        stack.append((indent, new_block))

    return root

tree = parse(raw_lines)

node = tree
for part in dotted.split("."):
    if isinstance(node, dict) and part in node:
        node = node[part]
    else:
        sys.exit(0)

if mode == "scalar":
    if isinstance(node, (str, int, float, bool)):
        print(node)
elif mode == "list":
    if isinstance(node, list):
        for item in node:
            if isinstance(item, (str, int, float, bool)):
                print(item)
PY
}

config_get() {
  _config_query "$1" "$2" scalar
}

config_list() {
  _config_query "$1" "$2" list
}
