#!/usr/bin/env bash
# TEKIMAX Secure SDD — gate-check
# Invoked by speckit.tekimax-security.gate-check
#
# Usage: gate-check.sh <spec-path>
#
# Exits 0 on PASS, 1 on BLOCK, 2 on error.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=lib/defaults.sh
source "$SCRIPT_DIR/lib/defaults.sh"

SPEC_PATH="${1:-}"
if [ -z "$SPEC_PATH" ] || [ ! -f "$SPEC_PATH" ]; then
  echo "error: spec path missing or not a file: $SPEC_PATH" >&2
  exit 2
fi
# Confine spec reads to the project directory — prevents path
# traversal via "../..", symlinks, or absolute paths.
require_inside_project "$SPEC_PATH" "spec path"

EXT_DIR=".specify/extensions/tekimax-security"
CONFIG="$EXT_DIR/tekimax-security-config.yml"
LOG_DIR=".tekimax-security"
GATE_LOG="$LOG_DIR/gate-log.jsonl"
mkdir -p "$LOG_DIR"

# --- Config-driven pattern sets (Gate F) ----------------------------
#
# Built-in defaults live in lib/defaults.sh (single source of truth).
# Gate F's inline-prompt and secret checks read their patterns from
# the project config with built-in fallbacks. See docs/customization
# for the config schema.

USER_INLINE_PROMPT_PATTERNS=()
while IFS= read -r item; do
  [ -n "$item" ] && USER_INLINE_PROMPT_PATTERNS+=("$item")
done < <(config_list "$CONFIG" "audit.inline_prompt_patterns")

USER_SECRET_PATTERNS=()
while IFS= read -r item; do
  [ -n "$item" ] && USER_SECRET_PATTERNS+=("$item")
done < <(config_list "$CONFIG" "audit.secret_patterns")

USER_GATEWAY_ALLOWLIST=()
while IFS= read -r item; do
  [ -n "$item" ] && USER_GATEWAY_ALLOWLIST+=("$item")
done < <(config_list "$CONFIG" "audit.allowlist.stack_direct_sdk")

# Use ${arr[@]+"${arr[@]}"} to avoid "unbound variable" on bash 3.2
# when the user arrays are empty (macOS ships bash 3.2 by default).
INLINE_PROMPT_RE="$DEFAULT_INLINE_PROMPT_RE"
for p in ${USER_INLINE_PROMPT_PATTERNS[@]+"${USER_INLINE_PROMPT_PATTERNS[@]}"}; do
  INLINE_PROMPT_RE="${INLINE_PROMPT_RE}|${p}"
done

SECRET_PATTERNS=("${DEFAULT_SECRET_PATTERNS[@]}" ${USER_SECRET_PATTERNS[@]+"${USER_SECRET_PATTERNS[@]}"})
SECRET_RE=$(join_secret_re SECRET_PATTERNS)

GATEWAY_ALLOWLIST=("${DEFAULT_GATEWAY_ALLOWLIST[@]}" ${USER_GATEWAY_ALLOWLIST[@]+"${USER_GATEWAY_ALLOWLIST[@]}"})
is_gateway_allowed() {
  _is_gateway_allowed "$1" GATEWAY_ALLOWLIST
}

SPEC_ID=$(basename "$SPEC_PATH" .md | grep -oE '^(F|SEC|ADR|INT)-[0-9]+' || echo "UNKNOWN")
SPEC_SLUG=$(basename "$SPEC_PATH" .md | sed -E 's/^(F|SEC|ADR|INT)-[0-9]+-//')

FAIL=0
SKIP=0

# Gate results stored as individual variables so the script works on
# bash 3.2 (macOS default, no `declare -A`). Access via `${!varname}`
# indirect expansion in the reporting loop below.
G_A=""
G_B=""
G_C=""
G_D=""
G_E=""
G_F=""

check_section() {
  local heading="$1"
  if grep -qF "$heading" "$SPEC_PATH"; then
    return 0
  else
    return 1
  fi
}

# Gate A — Data Contract
if check_section "## 2. Data Contract" || check_section "## Data Contract"; then
  if [ -f "src/schemas/${SPEC_SLUG}.ts" ]; then
    if grep -q "z\.any()" "src/schemas/${SPEC_SLUG}.ts"; then
      G_A="fail: z.any() in schema"
      FAIL=1
    else
      G_A="pass"
    fi
  else
    G_A="fail: missing src/schemas/${SPEC_SLUG}.ts"
    FAIL=1
  fi
else
  G_A="fail: missing Data Contract section"
  FAIL=1
fi

# Gate B — Threat Model
# Verify the STRIDE table has actual content rows, not just a heading
# with an empty table.
if check_section "## Security / Threat Model" || { check_section "## Security" && grep -qi "STRIDE\|Spoofing" "$SPEC_PATH"; }; then
  if grep -q '\[UNMITIGATED\].*\(High\|Critical\)' "$SPEC_PATH"; then
    G_B="fail: High/Critical unmitigated threats"
    FAIL=1
  elif ! grep -qE '^\|[[:space:]]*T[0-9]' "$SPEC_PATH" && \
       ! grep -qE '^\|[[:space:]]*(Spoofing|Tampering|Repudiation|Info|Denial|Elevation)' "$SPEC_PATH"; then
    G_B="fail: STRIDE table has no threat rows"
    FAIL=1
  else
    G_B="pass"
  fi
else
  G_B="fail: missing threat model"
  FAIL=1
fi

# Gate C — Model Governance (AI features only)
if grep -qi "AI Integration\|model:" "$SPEC_PATH"; then
  if grep -qE 'latest|"stable"' "$SPEC_PATH"; then
    G_C="fail: unpinned model version"
    FAIL=1
  elif ! grep -qi "Rollback" "$SPEC_PATH"; then
    G_C="fail: missing rollback plan"
    FAIL=1
  else
    G_C="pass"
  fi
else
  G_C="skip: no AI integration"
  SKIP=1
fi

# Gate D — Guardrails (AI features only)
# Verify rate limit and cost ceiling are present and numeric, not
# just that patterns exist.
if [ "$G_C" != "skip: no AI integration" ]; then
  GUARDRAIL_FILE="prompts/guardrails/${SPEC_SLUG}.yml"
  if [ -f "$GUARDRAIL_FILE" ] && [ -f "prompts/system/${SPEC_SLUG}.md" ]; then
    if ! grep -q "blocked_patterns:" "$GUARDRAIL_FILE" || \
       ! grep -q "redact_patterns:" "$GUARDRAIL_FILE"; then
      G_D="fail: guardrail missing blocked/redact patterns"
      FAIL=1
    elif ! grep -qE "rate_per_user_per_minute:[[:space:]]*[0-9]" "$GUARDRAIL_FILE"; then
      G_D="fail: rate_per_user_per_minute missing or not numeric"
      FAIL=1
    elif ! grep -qE "cost_ceiling_usd_per_day:[[:space:]]*[0-9]" "$GUARDRAIL_FILE"; then
      G_D="fail: cost_ceiling_usd_per_day missing or not numeric"
      FAIL=1
    else
      G_D="pass"
    fi
  else
    G_D="fail: missing prompt or guardrail files"
    FAIL=1
  fi
else
  G_D="skip: no AI integration"
fi

# Gate E — Red Team (optional; required before ship)
if ls red-team/RT-*-"${SPEC_SLUG}".md >/dev/null 2>&1; then
  G_E="pass"
else
  G_E="skip: no red-team report (required before ship)"
  SKIP=1
fi

# Gate F — Inline Content Scan
INLINE_HIT=0
if [ -d src ]; then
  raw_hits=$(grep -rIliE "$INLINE_PROMPT_RE" \
       --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.py" \
       src 2>/dev/null || true)
  # Drop allowlisted files
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if ! is_gateway_allowed "$f"; then
      INLINE_HIT=1
      break
    fi
  done <<< "$raw_hits"
fi
SECRET_HIT=0
if grep -rIl -E "($SECRET_RE)" \
     --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" \
     . 2>/dev/null | grep -vE "(node_modules|\.git/|\.next/|out/|\.source/|\.wrangler/|dist/)" | grep -q .; then
  SECRET_HIT=1
fi
ENV_COMMITTED=0
if git ls-files 2>/dev/null | grep -qE '^\.env(\..*)?$'; then
  ENV_COMMITTED=1
fi

if [ $INLINE_HIT -eq 0 ] && [ $SECRET_HIT -eq 0 ] && [ $ENV_COMMITTED -eq 0 ]; then
  G_F="pass"
else
  msgs=""
  [ $INLINE_HIT -eq 1 ] && msgs="${msgs}inline-prompts "
  [ $SECRET_HIT -eq 1 ] && msgs="${msgs}committed-secrets "
  [ $ENV_COMMITTED -eq 1 ] && msgs="${msgs}.env-committed "
  G_F="fail: ${msgs}"
  FAIL=1
fi

# Report
echo
echo "┌─────────────────────────────────────────────────┐"
printf "│ Security Gate Check — %-26s │\n" "$SPEC_ID"
echo "├─────────────────────────────────────────────────┤"
for key in A B C D E F; do
  label=""
  case $key in
    A) label="Gate A — Data Contract" ;;
    B) label="Gate B — Threat Model" ;;
    C) label="Gate C — Model Governance" ;;
    D) label="Gate D — Guardrails" ;;
    E) label="Gate E — Red Team" ;;
    F) label="Gate F — Inline Content Scan" ;;
  esac
  varname="G_$key"
  status="${!varname}"
  icon="✅"
  case "$status" in
    fail:*) icon="❌" ;;
    skip:*) icon="⚠ " ;;
  esac
  printf "│ %-30s %s  %-9s │\n" "$label" "$icon" "${status%%:*}"
  if [ "${status%%:*}" = "fail" ] || [ "${status%%:*}" = "skip" ]; then
    printf "│   %-45s │\n" "${status#*: }"
  fi
done
echo "└─────────────────────────────────────────────────┘"

if [ $FAIL -eq 1 ]; then
  VERDICT="BLOCK"
else
  VERDICT="PASS"
fi
echo
echo "VERDICT: $VERDICT"

# Append to gate log (JSONL) — uses jsonl_append_chained from
# lib/defaults.sh for tamper-evident hash chain (each line includes
# the SHA-256 of the previous line).
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
USER=$(git config user.name 2>/dev/null || echo "unknown")
PHASE="${SPECKIT_PHASE:-before_implement}"
jsonl_append_chained "$GATE_LOG" \
  "spec"    "$SPEC_ID" \
  "phase"   "$PHASE" \
  "verdict" "$VERDICT" \
  "ts"      "$TS" \
  "user"    "$USER" \
  "gates.A" "${G_A%%:*}" \
  "gates.B" "${G_B%%:*}" \
  "gates.C" "${G_C%%:*}" \
  "gates.D" "${G_D%%:*}" \
  "gates.E" "${G_E%%:*}" \
  "gates.F" "${G_F%%:*}"

if [ "$VERDICT" = "PASS" ]; then
  exit 0
else
  exit 1
fi
