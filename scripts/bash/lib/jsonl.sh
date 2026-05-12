#!/usr/bin/env bash
# JSONL writers for speckit-security audit trails.
#
# All audit-trail writes flow through Python so shell metacharacters in
# values cannot corrupt the output (e.g. a quote in a user name, a
# newline in a finding message). Sourced by scripts that append to
# .tekimax-security/*.jsonl logs.
#
# Usage (sourced):
#     source "$(dirname "$0")/lib/jsonl.sh"
#     jsonl_append "$LOG" "key1" "val1" "key2" "val2"
#     jsonl_append_chained "$LOG" "key1" "val1"   # adds prev_hash field

# Guard: JSONL writers use Python for safe JSON encoding and SHA-256
# hashing. Fail fast so a missing python3 is visible immediately rather
# than silently producing malformed logs.
if ! command -v python3 >/dev/null 2>&1; then
  echo "error: speckit-security requires python3 but it is not installed." >&2
  echo "  Install Python 3 and ensure it is on your PATH." >&2
  exit 2
fi

# jsonl_append <file> <key1> <val1> ...
#
# Safely appends a JSONL line to <file>. Pairs of arguments become
# key-value entries; values that parse as integers are stored as JSON
# numbers, everything else as strings. Dot-notation keys produce one
# level of nesting (e.g. "gates.A" → {"gates": {"A": ...}}).
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
    try:
        val = int(val)
    except (ValueError, TypeError):
        pass
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
# SHA-256 of the previous line in <file> (or "genesis" if the file is
# empty/missing). Creates a tamper-evident hash chain without any
# cryptographic signing dependencies.
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
