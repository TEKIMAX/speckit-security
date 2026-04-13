#!/usr/bin/env bash
# TEKIMAX Secure SDD — post-implementation audit
# Invoked by speckit.tekimax-security.audit
#
# Scans src/ for inline prompts, committed secrets, stack violations.
# Exits 0 clean, 1 on critical finding, 2 on error.

set -euo pipefail

LOG_DIR=".tekimax-security"
AUDIT_LOG="$LOG_DIR/audit-log.jsonl"
mkdir -p "$LOG_DIR"

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
    add_finding "CRITICAL" "inline-prompt: $f"
  done < <(grep -rIliE "([Yy]ou[[:space:]]+are[[:space:]]+(a|an)[[:space:]]+(helpful|AI|virtual|assistant|chatbot|expert|friendly|knowledgeable|precise|professional|skilled|senior|world|large[[:space:]]+language|language[[:space:]]+model|conversational|advanced|state-of-the-art)|<\|system\|>|<\|im_start\|>system|^[[:space:]]*(system|assistant|SYSTEM|ASSISTANT)[[:space:]]*:[[:space:]])" \
             --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.py" \
             src 2>/dev/null | grep -v "gateway" || true)
fi

# 2. Committed secrets (print file only, never the value)
while IFS= read -r f; do
  [ -z "$f" ] && continue
  add_finding "CRITICAL" "committed-secret: $f"
done < <(grep -rIlE "(sk_live_[0-9a-zA-Z]{24,}|sk_test_[0-9a-zA-Z]{24,}|-----BEGIN (RSA |EC |DSA |OPENSSH |ENCRYPTED )?PRIVATE KEY-----|xoxb-[0-9a-zA-Z-]{20,}|ghp_[0-9a-zA-Z]{36}|gho_[0-9a-zA-Z]{36}|ghs_[0-9a-zA-Z]{36}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_\-]{35})" \
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
    if [[ "$f" != *"src/ai/gateway"* ]]; then
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
printf '{"ts":"%s","user":"%s","critical":%d,"warn":%d,"verdict":"%s"}\n' \
  "$TS" "$USER" "$CRITICAL" "$WARN" "$VERDICT" >> "$AUDIT_LOG"

echo
echo "VERDICT: $VERDICT (critical=$CRITICAL, warn=$WARN)"

[ $CRITICAL -eq 0 ] && exit 0 || exit 1
