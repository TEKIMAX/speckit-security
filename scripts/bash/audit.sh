#!/usr/bin/env bash
# TEKIMAX Secure SDD — post-implementation audit
# Invoked by speckit.tekimax-security.audit
#
# Usage: audit.sh [--staged-only] [--json]
#
# Scans for inline prompts, committed secrets, direct-SDK imports,
# stale guardrails, and guardrail completeness. Exits 0 clean, 1 on
# critical finding, 2 on error.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=lib/defaults.sh
source "$SCRIPT_DIR/lib/defaults.sh"

STAGED_ONLY=0
EMIT_JSON=0
for arg in "$@"; do
  case "$arg" in
    --staged-only) STAGED_ONLY=1 ;;
    --json)        EMIT_JSON=1 ;;
  esac
done

EXT_DIR=".specify/extensions/tekimax-security"
CONFIG="$EXT_DIR/tekimax-security-config.yml"
LOG_DIR=".tekimax-security"
AUDIT_LOG="$LOG_DIR/audit-log.jsonl"
mkdir -p "$LOG_DIR"

# --- Config with fallbacks ------------------------------------------
#
# Built-in defaults live in lib/defaults.sh (single source of truth).
# Override or extend any list by defining the same key in
# tekimax-security-config.yml. See docs/customization for details.

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

USER_DIRECT_SDK_PATTERNS=()
while IFS= read -r item; do
  [ -n "$item" ] && USER_DIRECT_SDK_PATTERNS+=("$item")
done < <(config_list "$CONFIG" "audit.direct_sdk_patterns")

USER_INCLUDE_GLOBS=()
while IFS= read -r item; do
  [ -n "$item" ] && USER_INCLUDE_GLOBS+=("$item")
done < <(config_list "$CONFIG" "audit.include_globs")

USER_EXCLUDE_PATHS=()
while IFS= read -r item; do
  [ -n "$item" ] && USER_EXCLUDE_PATHS+=("$item")
done < <(config_list "$CONFIG" "audit.exclude_paths")

# Compose final pattern sets.
# Use ${arr[@]+"${arr[@]}"} to avoid "unbound variable" on bash 3.2
# when the user arrays are empty (macOS ships bash 3.2 by default).
SECRET_PATTERNS=("${DEFAULT_SECRET_PATTERNS[@]}" ${USER_SECRET_PATTERNS[@]+"${USER_SECRET_PATTERNS[@]}"})
GATEWAY_ALLOWLIST=("${DEFAULT_GATEWAY_ALLOWLIST[@]}" ${USER_GATEWAY_ALLOWLIST[@]+"${USER_GATEWAY_ALLOWLIST[@]}"})
DIRECT_SDK_PATTERNS=("${DEFAULT_DIRECT_SDK_PATTERNS[@]}" ${USER_DIRECT_SDK_PATTERNS[@]+"${USER_DIRECT_SDK_PATTERNS[@]}"})
INCLUDE_EXTS=("${DEFAULT_INCLUDE_EXTS[@]}" ${USER_INCLUDE_GLOBS[@]+"${USER_INCLUDE_GLOBS[@]}"})
EXCLUDE_PATTERNS=("${DEFAULT_EXCLUDE_PATTERNS[@]}" ${USER_EXCLUDE_PATHS[@]+"${USER_EXCLUDE_PATHS[@]}"})

SECRET_RE=$(join_secret_re SECRET_PATTERNS)

INLINE_PROMPT_RE="$DEFAULT_INLINE_PROMPT_RE"
for p in ${USER_INLINE_PROMPT_PATTERNS[@]+"${USER_INLINE_PROMPT_PATTERNS[@]}"}; do
  INLINE_PROMPT_RE="${INLINE_PROMPT_RE}|${p}"
done

# Build direct-SDK import regex. Escape special chars in each package
# name so slashes and hyphens behave as literals in the final ERE.
SDK_RE=""
for p in "${DIRECT_SDK_PATTERNS[@]}"; do
  esc=$(printf '%s' "$p" | sed 's/[][\/.^$*+?{}|()\\]/\\&/g')
  if [ -z "$SDK_RE" ]; then SDK_RE="$esc"; else SDK_RE="$SDK_RE|$esc"; fi
done

# Helper — is $1 (a file path) allowed by the gateway allowlist?
is_gateway_allowed() {
  _is_gateway_allowed "$1" GATEWAY_ALLOWLIST
}

# Build grep --include= args + exclude regex once.
INCLUDE_ARGS=()
for ext in "${INCLUDE_EXTS[@]}"; do INCLUDE_ARGS+=("--include=$ext"); done
INCLUDE_ARGS+=("--include=*.env*")
EXCLUDE_RE=$(build_exclude_regex EXCLUDE_PATTERNS)

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

STAGED_LIST=""
if [ "$STAGED_ONLY" = "1" ]; then
  STAGED_LIST=$(scan_staged_files INCLUDE_EXTS EXCLUDE_PATTERNS)
fi

# 1. Inline prompts
if [ "$STAGED_ONLY" = "1" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    [ -f "$f" ] || continue
    if is_gateway_allowed "$f"; then continue; fi
    if grep -liE "$INLINE_PROMPT_RE" "$f" >/dev/null 2>&1; then
      add_finding "CRITICAL" "inline-prompt: $f"
    fi
  done <<< "$STAGED_LIST"
else
  if [ -d src ]; then
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      if is_gateway_allowed "$f"; then continue; fi
      add_finding "CRITICAL" "inline-prompt: $f"
    done < <(grep -rIliE "$INLINE_PROMPT_RE" "${INCLUDE_ARGS[@]}" src 2>/dev/null || true)
  fi
fi

# 2. Committed secrets (print file only, never the value)
if [ "$STAGED_ONLY" = "1" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    [ -f "$f" ] || continue
    if grep -lE "($SECRET_RE)" "$f" >/dev/null 2>&1; then
      add_finding "CRITICAL" "committed-secret: $f"
    fi
  done <<< "$STAGED_LIST"
else
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    add_finding "CRITICAL" "committed-secret: $f"
  done < <(grep -rIlE "($SECRET_RE)" "${INCLUDE_ARGS[@]}" . 2>/dev/null \
             | { if [ -n "$EXCLUDE_RE" ]; then grep -vE "($EXCLUDE_RE)"; else cat; fi; } || true)
fi

# 3. .env committed — recursive (apps/*/.env, packages/*/.env.local).
# .env.example / .env.sample / .env.template remain allowed.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    add_finding "CRITICAL" ".env-committed: $f"
  done < <(git ls-files 2>/dev/null \
             | grep -E '(^|/)\.env($|\.)' \
             | grep -vE '\.env\.(example|sample|template)$' || true)
fi

# 4. Stack compliance — direct SDK imports outside gateway
if [ -d src ] && [ -n "$SDK_RE" ]; then
  if [ "$STAGED_ONLY" = "1" ]; then
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      [ -f "$f" ] || continue
      if is_gateway_allowed "$f"; then continue; fi
      if grep -lE "from ['\"]($SDK_RE)['\"]" "$f" >/dev/null 2>&1 || \
         grep -lE "require\(['\"]($SDK_RE)['\"]\)" "$f" >/dev/null 2>&1; then
        add_finding "WARN" "direct-sdk-import: $f"
      fi
    done <<< "$STAGED_LIST"
  else
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      if is_gateway_allowed "$f"; then continue; fi
      add_finding "WARN" "direct-sdk-import: $f"
    done < <(grep -rIlE "(from ['\"]($SDK_RE)['\"]|require\(['\"]($SDK_RE)['\"]\))" \
               "${INCLUDE_ARGS[@]}" src 2>/dev/null || true)
  fi
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
if [ "$EMIT_JSON" = "0" ]; then
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
fi

TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
USER=$(git config user.name 2>/dev/null || echo "unknown")
VERDICT="PASS"
[ $CRITICAL -gt 0 ] && VERDICT="BLOCK"
jsonl_append "$AUDIT_LOG" \
  "ts"          "$TS" \
  "user"        "$USER" \
  "critical"    "$CRITICAL" \
  "warn"        "$WARN" \
  "verdict"     "$VERDICT" \
  "staged_only" "$STAGED_ONLY"

if [ "$EMIT_JSON" = "1" ]; then
  items=""
  for f in "${FINDINGS[@]}"; do
    lvl="${f%%|*}"
    msg="${f#*|}"
    kind="${msg%%: *}"
    rest="${msg#*: }"
    esc=$(printf '%s' "$rest" | sed 's/\\/\\\\/g; s/"/\\"/g')
    entry=$(printf '{"level":"%s","kind":"%s","detail":"%s"}' "$lvl" "$kind" "$esc")
    if [ -z "$items" ]; then items="$entry"; else items="$items,$entry"; fi
  done
  printf '{"tool":"speckit-security","command":"audit","verdict":"%s","critical":%d,"warn":%d,"staged_only":%s,"findings":[%s]}\n' \
    "$VERDICT" "$CRITICAL" "$WARN" "$STAGED_ONLY" "$items"
else
  echo
  echo "VERDICT: $VERDICT (critical=$CRITICAL, warn=$WARN)"
fi

[ $CRITICAL -eq 0 ] && exit 0 || exit 1
