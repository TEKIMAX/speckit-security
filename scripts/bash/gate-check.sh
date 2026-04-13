#!/usr/bin/env bash
# TEKIMAX Secure SDD — gate-check
# Invoked by speckit.tekimax-security.gate-check
#
# Usage: gate-check.sh <spec-path>
#
# Exits 0 on PASS, 1 on BLOCK, 2 on error.

set -euo pipefail

SPEC_PATH="${1:-}"
if [ -z "$SPEC_PATH" ] || [ ! -f "$SPEC_PATH" ]; then
  echo "error: spec path missing or not a file: $SPEC_PATH" >&2
  exit 2
fi

EXT_DIR=".specify/extensions/tekimax-security"
CONFIG="$EXT_DIR/tekimax-security-config.yml"
LOG_DIR=".tekimax-security"
GATE_LOG="$LOG_DIR/gate-log.jsonl"
mkdir -p "$LOG_DIR"

SPEC_ID=$(basename "$SPEC_PATH" .md | grep -oE '^(F|SEC|ADR|INT)-[0-9]+' || echo "UNKNOWN")
SPEC_SLUG=$(basename "$SPEC_PATH" .md | sed -E 's/^(F|SEC|ADR|INT)-[0-9]+-//')

FAIL=0
SKIP=0
declare -A G

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
      G[A]="fail: z.any() in schema"
      FAIL=1
    else
      G[A]="pass"
    fi
  else
    G[A]="fail: missing src/schemas/${SPEC_SLUG}.ts"
    FAIL=1
  fi
else
  G[A]="fail: missing Data Contract section"
  FAIL=1
fi

# Gate B — Threat Model
if check_section "## Security / Threat Model" || check_section "## Security" && grep -qi "STRIDE\|Spoofing" "$SPEC_PATH"; then
  if grep -q '\[UNMITIGATED\].*\(High\|Critical\)' "$SPEC_PATH"; then
    G[B]="fail: High/Critical unmitigated threats"
    FAIL=1
  else
    G[B]="pass"
  fi
else
  G[B]="fail: missing threat model"
  FAIL=1
fi

# Gate C — Model Governance (AI features only)
if grep -qi "AI Integration\|model:" "$SPEC_PATH"; then
  if grep -qE 'latest|"stable"' "$SPEC_PATH"; then
    G[C]="fail: unpinned model version"
    FAIL=1
  elif ! grep -qi "Rollback" "$SPEC_PATH"; then
    G[C]="fail: missing rollback plan"
    FAIL=1
  else
    G[C]="pass"
  fi
else
  G[C]="skip: no AI integration"
  SKIP=1
fi

# Gate D — Guardrails (AI features only)
if [ "${G[C]}" != "skip: no AI integration" ]; then
  if [ -f "prompts/guardrails/${SPEC_SLUG}.yml" ] && [ -f "prompts/system/${SPEC_SLUG}.md" ]; then
    if grep -q "blocked_patterns:" "prompts/guardrails/${SPEC_SLUG}.yml" && \
       grep -q "redact_patterns:" "prompts/guardrails/${SPEC_SLUG}.yml"; then
      G[D]="pass"
    else
      G[D]="fail: guardrail missing blocked/redact patterns"
      FAIL=1
    fi
  else
    G[D]="fail: missing prompt or guardrail files"
    FAIL=1
  fi
else
  G[D]="skip: no AI integration"
fi

# Gate E — Red Team (optional; required before ship)
if ls red-team/RT-*-"${SPEC_SLUG}".md >/dev/null 2>&1; then
  G[E]="pass"
else
  G[E]="skip: no red-team report (required before ship)"
  SKIP=1
fi

# Gate F — Inline Content Scan
INLINE_HIT=0
if [ -d src ]; then
  hits=$(grep -rIliE "(you[[:space:]]+are[[:space:]]+a|as[[:space:]]+an[[:space:]]+ai|<\|system\|>)" \
       --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.py" \
       src 2>/dev/null | grep -v "gateway" || true)
  if [ -n "$hits" ]; then
    INLINE_HIT=1
  fi
fi
SECRET_HIT=0
if grep -rIl -E "(sk_live_|PRIVATE_KEY|BEGIN RSA|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_\-]{35})" \
     --include="*.ts" --include="*.tsx" --include="*.js" --include="*.py" \
     . 2>/dev/null | grep -v "node_modules" | grep -q .; then
  SECRET_HIT=1
fi
ENV_COMMITTED=0
if git ls-files 2>/dev/null | grep -qE '^\.env(\..*)?$'; then
  ENV_COMMITTED=1
fi

if [ $INLINE_HIT -eq 0 ] && [ $SECRET_HIT -eq 0 ] && [ $ENV_COMMITTED -eq 0 ]; then
  G[F]="pass"
else
  msgs=""
  [ $INLINE_HIT -eq 1 ] && msgs="${msgs}inline-prompts "
  [ $SECRET_HIT -eq 1 ] && msgs="${msgs}committed-secrets "
  [ $ENV_COMMITTED -eq 1 ] && msgs="${msgs}.env-committed "
  G[F]="fail: ${msgs}"
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
  status="${G[$key]}"
  icon="✅"
  [[ "$status" == fail:* ]] && icon="❌"
  [[ "$status" == skip:* ]] && icon="⚠ "
  printf "│ %-30s %s  %-9s │\n" "$label" "$icon" "${status%%:*}"
  if [[ "$status" == fail:* || "$status" == skip:* ]]; then
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

# Append to gate log (JSONL)
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
USER=$(git config user.name 2>/dev/null || echo "unknown")
PHASE="${SPECKIT_PHASE:-before_implement}"
printf '{"spec":"%s","phase":"%s","verdict":"%s","ts":"%s","user":"%s","gates":{"A":"%s","B":"%s","C":"%s","D":"%s","E":"%s","F":"%s"}}\n' \
  "$SPEC_ID" "$PHASE" "$VERDICT" "$TS" "$USER" \
  "${G[A]%%:*}" "${G[B]%%:*}" "${G[C]%%:*}" "${G[D]%%:*}" "${G[E]%%:*}" "${G[F]%%:*}" \
  >> "$GATE_LOG"

[ "$VERDICT" = "PASS" ] && exit 0 || exit 1
