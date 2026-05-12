#!/usr/bin/env bash
# TEKIMAX Secure SDD — gate-check
# Invoked by speckit.tekimax-security.gate-check
#
# Usage: gate-check.sh <spec-path> [--staged-only] [--json]
#
# Exits 0 on PASS, 1 on BLOCK, 2 on error.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=lib/defaults.sh
source "$SCRIPT_DIR/lib/defaults.sh"
# shellcheck source=lib/scan.sh
source "$SCRIPT_DIR/lib/scan.sh"
# shellcheck source=lib/gates.sh
source "$SCRIPT_DIR/lib/gates.sh"

# --- arg parsing ----------------------------------------------------

SPEC_PATH=""
STAGED_ONLY=0
EMIT_JSON=0
for arg in "$@"; do
  case "$arg" in
    --staged-only) STAGED_ONLY=1 ;;
    --json)        EMIT_JSON=1 ;;
    -*)            ;;
    *)             [ -z "$SPEC_PATH" ] && SPEC_PATH="$arg" ;;
  esac
done

if [ -z "$SPEC_PATH" ] || [ ! -f "$SPEC_PATH" ]; then
  echo "error: spec path missing or not a file: $SPEC_PATH" >&2
  exit 2
fi
require_inside_project "$SPEC_PATH" "spec path"

EXT_DIR=".specify/extensions/tekimax-security"
CONFIG="$EXT_DIR/tekimax-security-config.yml"
LOG_DIR=".tekimax-security"
GATE_LOG="$LOG_DIR/gate-log.jsonl"
mkdir -p "$LOG_DIR"

# --- merge config-driven pattern sets with built-in defaults --------
#
# Built-in defaults live in lib/defaults.sh. User entries extend (not
# replace) them — see docs/CUSTOMIZATION.md. Use ${arr[@]+"${arr[@]}"}
# everywhere to avoid "unbound variable" errors on bash 3.2 (macOS)
# when a user array is empty.

USER_INLINE_PROMPT_PATTERNS=()
while IFS= read -r item; do [ -n "$item" ] && USER_INLINE_PROMPT_PATTERNS+=("$item"); done \
  < <(config_list "$CONFIG" "audit.inline_prompt_patterns")

USER_SECRET_PATTERNS=()
while IFS= read -r item; do [ -n "$item" ] && USER_SECRET_PATTERNS+=("$item"); done \
  < <(config_list "$CONFIG" "audit.secret_patterns")

USER_GATEWAY_ALLOWLIST=()
while IFS= read -r item; do [ -n "$item" ] && USER_GATEWAY_ALLOWLIST+=("$item"); done \
  < <(config_list "$CONFIG" "audit.allowlist.stack_direct_sdk")

USER_INCLUDE_GLOBS=()
while IFS= read -r item; do [ -n "$item" ] && USER_INCLUDE_GLOBS+=("$item"); done \
  < <(config_list "$CONFIG" "audit.include_globs")

USER_EXCLUDE_PATHS=()
while IFS= read -r item; do [ -n "$item" ] && USER_EXCLUDE_PATHS+=("$item"); done \
  < <(config_list "$CONFIG" "audit.exclude_paths")

INLINE_PROMPT_RE="$DEFAULT_INLINE_PROMPT_RE"
for p in ${USER_INLINE_PROMPT_PATTERNS[@]+"${USER_INLINE_PROMPT_PATTERNS[@]}"}; do
  INLINE_PROMPT_RE="${INLINE_PROMPT_RE}|${p}"
done

SECRET_PATTERNS=("${DEFAULT_SECRET_PATTERNS[@]}" ${USER_SECRET_PATTERNS[@]+"${USER_SECRET_PATTERNS[@]}"})
SECRET_RE=$(join_secret_re SECRET_PATTERNS)

GATEWAY_ALLOWLIST=("${DEFAULT_GATEWAY_ALLOWLIST[@]}" ${USER_GATEWAY_ALLOWLIST[@]+"${USER_GATEWAY_ALLOWLIST[@]}"})
INCLUDE_EXTS=("${DEFAULT_INCLUDE_EXTS[@]}" ${USER_INCLUDE_GLOBS[@]+"${USER_INCLUDE_GLOBS[@]}"})
EXCLUDE_PATTERNS=("${DEFAULT_EXCLUDE_PATTERNS[@]}" ${USER_EXCLUDE_PATHS[@]+"${USER_EXCLUDE_PATHS[@]}"})

INCLUDE_ARGS=()
for ext in "${INCLUDE_EXTS[@]}"; do INCLUDE_ARGS+=("--include=$ext"); done
INCLUDE_ARGS+=("--include=*.env*")
EXCLUDE_RE=$(build_exclude_regex EXCLUDE_PATTERNS)

STAGED_LIST=""
if [ "$STAGED_ONLY" = "1" ]; then
  STAGED_LIST=$(scan_staged_files INCLUDE_EXTS EXCLUDE_PATTERNS)
fi

# --- run gates ------------------------------------------------------

SPEC_ID=$(basename "$SPEC_PATH" .md | grep -oE '^(F|SEC|ADR|INT)-[0-9]+' || echo "UNKNOWN")
SPEC_SLUG=$(basename "$SPEC_PATH" .md | sed -E 's/^(F|SEC|ADR|INT)-[0-9]+-//')

G_A=$(check_gate_a "$SPEC_PATH" "$SPEC_SLUG")
G_B=$(check_gate_b "$SPEC_PATH")
G_C=$(check_gate_c "$SPEC_PATH")
G_D=$(check_gate_d "$SPEC_SLUG" "$G_C")
G_E=$(check_gate_e "$SPEC_SLUG")
G_F=$(check_gate_f "$STAGED_ONLY")
G_G=$(check_gate_g "$SCRIPT_DIR" "$CONFIG")

FAIL=0
for v in "$G_A" "$G_B" "$G_C" "$G_D" "$G_E" "$G_F" "$G_G"; do
  [ "${v%%:*}" = "fail" ] && FAIL=1
done

# --- report ---------------------------------------------------------

if [ "$EMIT_JSON" = "0" ]; then
  render_gate_box "$SPEC_ID" "$G_A" "$G_B" "$G_C" "$G_D" "$G_E" "$G_F" "$G_G"
fi

if [ $FAIL -eq 1 ]; then
  VERDICT="BLOCK"
else
  VERDICT="PASS"
fi

if [ "$EMIT_JSON" = "1" ]; then
  printf '{"tool":"speckit-security","command":"gate-check","spec":"%s","verdict":"%s","staged_only":%s,"gates":{"A":"%s","B":"%s","C":"%s","D":"%s","E":"%s","F":"%s","G":"%s"}}\n' \
    "$SPEC_ID" "$VERDICT" "$STAGED_ONLY" \
    "${G_A//\"/\\\"}" "${G_B//\"/\\\"}" "${G_C//\"/\\\"}" \
    "${G_D//\"/\\\"}" "${G_E//\"/\\\"}" "${G_F//\"/\\\"}" "${G_G//\"/\\\"}"
else
  echo
  echo "VERDICT: $VERDICT"
fi

# --- audit-trail append (hash-chained) ------------------------------

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
  "gates.F" "${G_F%%:*}" \
  "gates.G" "${G_G%%:*}"

[ "$VERDICT" = "PASS" ] && exit 0 || exit 1
