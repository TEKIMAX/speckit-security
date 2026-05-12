#!/usr/bin/env bash
# lib/jsonl.sh exposes jsonl_append (plain) and jsonl_append_chained
# (with prev_hash). Both produce valid JSON; the chained writer links
# each entry's prev_hash to the SHA-256 of the previous line.
#
# Expected: two-line file, both lines valid JSON, second line's
# prev_hash == sha256(first line).

set -euo pipefail
source "$(dirname "$0")/../lib/assert.sh"
source "$(dirname "$0")/../lib/fixture.sh"

fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT

# --- jsonl_append produces valid JSON with dotted keys --------------
cat > "$fixture/plain.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
source "$REPO_ROOT/scripts/bash/lib/jsonl.sh"
jsonl_append "$fixture/plain.jsonl" \
  "spec" "F-001" \
  "verdict" "PASS" \
  "gates.A" "pass" \
  "gates.B" "fail"
EOF
bash "$fixture/plain.sh"
assert_file_exists "$fixture/plain.jsonl" "plain log"

python3 - "$fixture/plain.jsonl" <<'PY'
import json, sys
lines = open(sys.argv[1]).read().splitlines()
assert len(lines) == 1, f"expected 1 line, got {len(lines)}"
obj = json.loads(lines[0])
assert obj["spec"] == "F-001"
assert obj["verdict"] == "PASS"
assert obj["gates"] == {"A": "pass", "B": "fail"}
PY

# --- jsonl_append_chained adds prev_hash; second entry links --------
cat > "$fixture/chained.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
source "$REPO_ROOT/scripts/bash/lib/jsonl.sh"
jsonl_append_chained "$fixture/chained.jsonl" "step" "one"
jsonl_append_chained "$fixture/chained.jsonl" "step" "two"
EOF
bash "$fixture/chained.sh"

python3 - "$fixture/chained.jsonl" <<'PY'
import hashlib, json, sys
lines = open(sys.argv[1], "rb").read().rstrip(b"\n").split(b"\n")
assert len(lines) == 2, f"expected 2 lines, got {len(lines)}"
a, b = json.loads(lines[0]), json.loads(lines[1])
assert a["step"] == "one" and a["prev_hash"] == "genesis"
expected = "sha256:" + hashlib.sha256(lines[0]).hexdigest()
assert b["prev_hash"] == expected, f"chain broken: {b['prev_hash']} != {expected}"
PY

echo "✓ $(basename "$0")"
