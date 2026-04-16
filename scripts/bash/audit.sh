#!/usr/bin/env bash
# TEKIMAX Secure SDD — post-implementation audit
# Invoked by speckit.tekimax-security.audit
#
# Scans src/ for inline prompts, committed secrets, stack violations.
# Exits 0 clean, 1 on critical finding, 2 on error.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=lib/defaults.sh
source "$SCRIPT_DIR/lib/defaults.sh"

EXT_DIR=".specify/extensions/tekimax-security"
CONFIG="$EXT_DIR/tekimax-security-config.yml"
LOG_DIR=".tekimax-security"
AUDIT_LOG="$LOG_DIR/audit-log.jsonl"
mkdir -p "$LOG_DIR"

# --- Config with fallbacks ------------------------------------------
#
# Built-in defaults live in lib/defaults.sh (single source of truth).
# Override any list by defining the same key in
# tekimax-security-config.yml. See docs/customization for details.

# Let the project override the defaults. Reads are additive: any value
# in the config is appended to the built-ins so a missing config still
# gives the full built-in coverage.
USER_SECRET_PATTERNS=()
while IFS= read -r item; do
  [ -n "$item" ] && USER_SECRET_PATTERNS+=("$item")
done < <(config_list "$CONFIG" "audit.secret_patterns")

USER_GATEWAY_ALLOWLIST=()
while IFS= read -r item; do
  [ -n "$item" ] && USER_GATEWAY_ALLOWLIST+=("$item")
done < <(config_list "$CONFIG" "audit.allowlist.stack_direct_sdk")

USER_INLINE_PROMPT_PATTERNS=()
while IFS= read -r item; do
  [ -n "$item" ] && USER_INLINE_PROMPT_PATTERNS+=("$item")
done < <(config_list "$CONFIG" "audit.inline_prompt_patterns")

# Compose final pattern sets
SECRET_PATTERNS=("${DEFAULT_SECRET_PATTERNS[@]}" "${USER_SECRET_PATTERNS[@]}")
GATEWAY_ALLOWLIST=("${DEFAULT_GATEWAY_ALLOWLIST[@]}" "${USER_GATEWAY_ALLOWLIST[@]}")

SECRET_RE=$(join_secret_re SECRET_PATTERNS)

# Build the inline prompt regex. If the user supplied patterns, they
# extend the default alternation.
INLINE_PROMPT_RE="$DEFAULT_INLINE_PROMPT_RE"
for p in "${USER_INLINE_PROMPT_PATTERNS[@]}"; do
  INLINE_PROMPT_RE="${INLINE_PROMPT_RE}|${p}"
done

# Helper — is $1 (a file path) allowed by the gateway allowlist?
is_gateway_allowed() {
  _is_gateway_allowed "$1" GATEWAY_ALLOWLIST
}

CRITICAL=0
WARN=0
declare -a FINDINGS

add_finding() {
  local level="$1"; shift
  FINDINGS+=("$level|$*")
  case "$level" in
    CRITICAL) CRITICAL=$((CRITICAL + 1)) ;;
    WARN)     WARN=$((WARN + 1)) ;;
  esac
  return 0
}

# 1. Inline prompts
if [ -d src ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    # Skip files under any allowlisted gateway path — the gateway
    # client legitimately references model SDKs and prompts.
    if is_gateway_allowed "$f"; then
      continue
    fi
    add_finding "CRITICAL" "inline-prompt: $f"
  done < <(grep -rIliE "$INLINE_PROMPT_RE" \
             --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.py" \
             src 2>/dev/null || true)
fi

# 2. Committed secrets (print file only, never the value)
while IFS= read -r f; do
  [ -z "$f" ] && continue
  add_finding "CRITICAL" "committed-secret: $f"
done < <(grep -rIlE "($SECRET_RE)" \
           --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.py" --include="*.env*" \
           . 2>/dev/null | grep -vE "(node_modules|\.git/|dist/|\.next/|out/|\.source/|\.wrangler/)" || true)

# 3. .env committed
if git ls-files 2>/dev/null | grep -qE '^\.env(\..*)?$'; then
  add_finding "CRITICAL" ".env-committed"
fi

# 4. Stack compliance — direct SDK imports outside gateway
if [ -d src ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if ! is_gateway_allowed "$f"; then
      add_finding "WARN" "direct-sdk-import: $f"
    fi
  done < <(grep -rIlE "from ['\"]@(google/genai|anthropic-ai/sdk|openai)['\"]" \
             --include="*.ts" --include="*.tsx" --include="*.js" \
             src 2>/dev/null || true)
fi

# 5. Guardrail freshness — edited without version bump
if [ -d prompts ]; then
  for f in prompts/guardrails/*.yml prompts/system/*.md; do
    [ -f "$f" ] || continue
    if [ -d .git ]; then
      if git diff --cached --name-only 2>/dev/null | grep -qF "$f"; then
        if ! git diff --cached "$f" | grep -q '^+version:'; then
          add_finding "WARN" "guardrail-edit-without-version-bump: $f"
        fi
      fi
    fi
  done
fi

# 6. Guardrail completeness — verify required keys exist.
# Guardrails without numeric rate limits or cost ceilings are
# incomplete and leave the feature unprotected against cost/rate abuse.
if [ -d prompts/guardrails ]; then
  for f in prompts/guardrails/*.yml; do
    [ -f "$f" ] || continue
    if ! grep -q "blocked_patterns:" "$f"; then
      add_finding "WARN" "guardrail-missing-blocked_patterns: $f"
    fi
    if ! grep -q "redact_patterns:" "$f"; then
      add_finding "WARN" "guardrail-missing-redact_patterns: $f"
    fi
    if ! grep -qE "rate_per_user_per_minute:[[:space:]]*[0-9]" "$f"; then
      add_finding "WARN" "guardrail-missing-rate-limit: $f"
    fi
    if ! grep -qE "cost_ceiling_usd_per_day:[[:space:]]*[0-9]" "$f"; then
      add_finding "WARN" "guardrail-missing-cost-ceiling: $f"
    fi
  done
fi

# Report
echo
echo "┌─────────────────────────────────────────────────┐"
echo "│ Post-Implementation Audit                       │"
echo "├─────────────────────────────────────────────────┤"
if [ $((CRITICAL + WARN)) -eq 0 ]; then
  printf "│ %-48s │\n" "No findings. Clean."
else
  for f in "${FINDINGS[@]}"; do
    lvl="${f%%|*}"
    msg="${f#*|}"
    icon="❌"
    if [ "$lvl" = "WARN" ]; then icon="⚠ "; fi
    printf "│ %s %-45s │\n" "$icon" "${msg:0:45}"
  done
fi
echo "└─────────────────────────────────────────────────┘"

TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
USER=$(git config user.name 2>/dev/null || echo "unknown")
VERDICT="PASS"
[ $CRITICAL -gt 0 ] && VERDICT="BLOCK"
jsonl_append "$AUDIT_LOG" \
  "ts"       "$TS" \
  "user"     "$USER" \
  "critical" "$CRITICAL" \
  "warn"     "$WARN" \
  "verdict"  "$VERDICT"

echo
echo "VERDICT: $VERDICT (critical=$CRITICAL, warn=$WARN)"

[ $CRITICAL -eq 0 ] && exit 0 || exit 1
