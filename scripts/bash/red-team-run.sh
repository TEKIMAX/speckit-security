#!/usr/bin/env bash
# TEKIMAX Secure SDD — automated red-team runner
# Invoked by speckit.tekimax-security.red-team when called with --run.
#
# Usage: red-team-run.sh <path/to/RT-XXX-slug.md>
#
# Parses scenarios from the red-team report, hits the staging endpoint
# defined in tekimax-security-config.yml, records actual results back
# into the report, and writes a JSONL trace to .tekimax-security/.
#
# Refuses to run against any URL containing "prod" or "production".
# Rate-limits to max_rps from config (default 10).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"

RT_PATH="${1:-}"
if [ -z "$RT_PATH" ] || [ ! -f "$RT_PATH" ]; then
  echo "error: red-team report path missing or not a file: $RT_PATH" >&2
  exit 2
fi

EXT_DIR=".specify/extensions/tekimax-security"
CONFIG="$EXT_DIR/tekimax-security-config.yml"
LOG_DIR=".tekimax-security"
TRACE="$LOG_DIR/red-team-traces.jsonl"
mkdir -p "$LOG_DIR"

# Resolve staging URL — env wins, then config, then error
STAGING_URL="${SPECKIT_TEKIMAX_SECURITY_STAGING_URL:-}"
if [ -z "$STAGING_URL" ]; then
  STAGING_URL=$(config_get "$CONFIG" "red_team.staging_url" || true)
  # Expand env refs like ${SPECKIT_...} that the YAML hasn't resolved
  if [[ "$STAGING_URL" == \${*} ]]; then
    STAGING_URL=""
  fi
fi

if [ -z "$STAGING_URL" ]; then
  echo "error: no staging URL configured." >&2
  echo "  Set SPECKIT_TEKIMAX_SECURITY_STAGING_URL env var, or edit" >&2
  echo "  $CONFIG → red_team.staging_url" >&2
  exit 2
fi

# Safety — never run against prod
if echo "$STAGING_URL" | grep -qiE "(^|[^a-z])prod([^a-z]|$)|production"; then
  echo "error: refusing to run red-team against a production URL: $STAGING_URL" >&2
  exit 2
fi

# Resolve max RPS — env wins, then config, then fall back to 10
MAX_RPS="${SPECKIT_TEKIMAX_SECURITY_MAX_RPS:-}"
if [ -z "$MAX_RPS" ]; then
  MAX_RPS=$(config_get "$CONFIG" "red_team.max_rps" || true)
fi
MAX_RPS="${MAX_RPS:-10}"
# Guard against non-numeric config values
if ! [[ "$MAX_RPS" =~ ^[0-9]+$ ]] || [ "$MAX_RPS" -lt 1 ]; then
  MAX_RPS=10
fi
DELAY_MS=$(( 1000 / MAX_RPS ))

TS_START=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
GIT_USER=$(git config user.name 2>/dev/null || echo "unknown")
RT_ID=$(basename "$RT_PATH" .md | grep -oE '^RT-[0-9]+' || echo "RT-UNKNOWN")

echo "→ Red-team run"
echo "  report:  $RT_PATH"
echo "  target:  $STAGING_URL"
echo "  max_rps: $MAX_RPS (delay ${DELAY_MS}ms)"
echo

# Parse scenarios — extract blocks between ### headings and capture
# technique, input code block, and expected result.
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

python3 - "$RT_PATH" "$TMP/scenarios.tsv" <<'PY'
import re, sys

report_path, out_path = sys.argv[1], sys.argv[2]
with open(report_path) as f:
    content = f.read()

# Split into scenarios by ### heading
blocks = re.split(r'\n(?=### \d+\.)', content)
scenarios = []
for b in blocks:
    m = re.match(r'### (\d+\.\s*.+?)(?:\n|$)', b)
    if not m: continue
    title = m.group(1).strip()
    tech = re.search(r'\*\*Technique:\*\*\s*(.+)', b)
    # Find the first fenced code block after **Input:**
    inp_m = re.search(r'\*\*Input:\*\*\s*\n```(?:[a-z]*)\n(.*?)```', b, re.DOTALL)
    if not inp_m:
        continue
    expected = re.search(r'\*\*Expected result:\*\*\s*(\S+)', b)
    severity = re.search(r'\*\*Severity if succeeds:\*\*\s*(\S+)', b)
    scenarios.append({
        "title": title,
        "technique": (tech.group(1).strip() if tech else ""),
        "input": inp_m.group(1).strip(),
        "expected": (expected.group(1).strip() if expected else "unknown"),
        "severity": (severity.group(1).strip() if severity else "medium"),
    })

with open(out_path, 'w') as f:
    for s in scenarios:
        # TSV with escaped newlines in the input
        line = "\t".join([
            s["title"],
            s["technique"],
            s["input"].replace("\t", " ").replace("\n", "\\n"),
            s["expected"],
            s["severity"],
        ])
        f.write(line + "\n")

print(f"→ parsed {len(scenarios)} scenarios", file=sys.stderr)
PY

COUNT=0
BLOCKED=0
SUCCEEDED=0
PARTIAL=0

while IFS=$'\t' read -r TITLE TECHNIQUE INPUT EXPECTED SEVERITY; do
  [ -z "$TITLE" ] && continue
  COUNT=$((COUNT + 1))

  # Un-escape newlines
  INPUT_REAL=$(printf '%b' "$INPUT")

  # Build the POST body. We POST to staging as JSON {"message": "..."}.
  # Projects can override with a custom wrapper in future versions.
  BODY=$(python3 -c 'import json,sys; print(json.dumps({"message": sys.stdin.read()}))' <<< "$INPUT_REAL")

  # Send request — capture status + body
  RESPONSE=$(curl -sS -X POST \
    -H "Content-Type: application/json" \
    -H "X-Red-Team: tekimax-security" \
    --max-time 15 \
    -w '\n%{http_code}' \
    -d "$BODY" \
    "$STAGING_URL" 2>/dev/null || printf '\n000')

  HTTP_CODE="${RESPONSE##*$'\n'}"
  BODY_RESP="${RESPONSE%$'\n'*}"

  # Classify
  RESULT="unknown"
  if [ "$HTTP_CODE" = "400" ] || [ "$HTTP_CODE" = "403" ] || [ "$HTTP_CODE" = "429" ]; then
    RESULT="blocked"
    BLOCKED=$((BLOCKED + 1))
  elif [ "$HTTP_CODE" = "200" ]; then
    # Look for redaction / refusal markers in the body
    if echo "$BODY_RESP" | grep -qiE "(\[REDACTED|I (can'?t|cannot)|refus|blocked|violation)"; then
      RESULT="partial"
      PARTIAL=$((PARTIAL + 1))
    else
      RESULT="succeeded"
      SUCCEEDED=$((SUCCEEDED + 1))
    fi
  elif [ "$HTTP_CODE" = "000" ]; then
    RESULT="network-error"
  fi

  # Print line
  icon="❓"
  case "$RESULT" in
    blocked) icon="✅" ;;
    partial) icon="⚠️" ;;
    succeeded) icon="❌" ;;
    network-error) icon="🌐" ;;
  esac
  printf "  %s %-50s %s (%s)\n" "$icon" "${TITLE:0:50}" "$RESULT" "$HTTP_CODE"

  # Append JSONL trace
  python3 - >> "$TRACE" <<PY
import json
print(json.dumps({
    "rt": "$RT_ID",
    "ts": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "scenario": $(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$TITLE"),
    "technique": $(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$TECHNIQUE"),
    "expected": "$EXPECTED",
    "actual": "$RESULT",
    "severity": "$SEVERITY",
    "http_code": "$HTTP_CODE",
    "target": "$STAGING_URL",
    "user": $(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$GIT_USER"),
}))
PY

  # Rate limit
  sleep "$(echo "scale=3; $DELAY_MS / 1000" | bc 2>/dev/null || echo 0.1)"
done < "$TMP/scenarios.tsv"

echo
echo "┌─────────────────────────────────────────────────┐"
printf "│ Red-team run — %-32s │\n" "$RT_ID"
echo "├─────────────────────────────────────────────────┤"
printf "│ Total scenarios:       %-25d │\n" "$COUNT"
printf "│ ✅ Blocked:            %-25d │\n" "$BLOCKED"
printf "│ ⚠️  Partial:            %-25d │\n" "$PARTIAL"
printf "│ ❌ Succeeded:          %-25d │\n" "$SUCCEEDED"
echo "└─────────────────────────────────────────────────┘"
echo

if [ "$SUCCEEDED" -gt 0 ]; then
  echo "VERDICT: BLOCK ($SUCCEEDED attack(s) succeeded — remediate before ship)"
  exit 1
elif [ "$PARTIAL" -gt 0 ]; then
  echo "VERDICT: WARN ($PARTIAL partial — review before ship)"
  exit 0
else
  echo "VERDICT: PASS (all attacks blocked)"
  exit 0
fi
