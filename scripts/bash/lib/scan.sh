#!/usr/bin/env bash
# File-scan helpers shared by gate-check.sh (Gate F) and audit.sh.
#
# Each helper prints file paths with matches, one per line. Callers
# count or accumulate the output. Reads patterns and modes from
# well-known globals to keep the public signatures simple — this is
# bash's accepted alternative to passing many parameters by reference.
#
# Required globals (set by the caller before invoking):
#   STAGED_LIST          — newline-separated paths (when STAGED_ONLY=1)
#   INCLUDE_ARGS         — array of grep --include=*.<ext> args
#   EXCLUDE_RE           — ERE alternation for paths to exclude
#   INLINE_PROMPT_RE     — ERE for inline-prompt detection
#   SECRET_RE            — ERE alternation for secret patterns
#   GATEWAY_ALLOWLIST    — array of anchored allowlist entries
#
# Usage (sourced):
#     source "$(dirname "$0")/lib/scan.sh"
#     hits=$(scan_inline_prompts "$STAGED_ONLY")

# scan_inline_prompts <staged_only_flag>
#
# Prints paths under src/ (or filtered staged files) that contain
# inline-prompt patterns AND are not under the gateway allowlist.
# Returns no output when STAGED_LIST is empty in staged mode, or when
# src/ is absent in recursive mode.
scan_inline_prompts() {
  local staged="$1"
  if [ "$staged" = "1" ]; then
    [ -z "${STAGED_LIST:-}" ] && return 0
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      [ -f "$f" ] || continue
      _is_gateway_allowed "$f" GATEWAY_ALLOWLIST && continue
      grep -liE "$INLINE_PROMPT_RE" "$f" >/dev/null 2>&1 && printf '%s\n' "$f"
    done <<< "$STAGED_LIST"
  else
    [ -d src ] || return 0
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      _is_gateway_allowed "$f" GATEWAY_ALLOWLIST && continue
      printf '%s\n' "$f"
    done < <(grep -rIliE "$INLINE_PROMPT_RE" "${INCLUDE_ARGS[@]}" src 2>/dev/null || true)
  fi
}

# scan_secrets <staged_only_flag>
#
# Prints paths containing secret patterns. In recursive mode, applies
# EXCLUDE_RE to drop dist/, node_modules/, etc.
scan_secrets() {
  local staged="$1"
  if [ "$staged" = "1" ]; then
    [ -z "${STAGED_LIST:-}" ] && return 0
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      [ -f "$f" ] || continue
      grep -lE "($SECRET_RE)" "$f" >/dev/null 2>&1 && printf '%s\n' "$f"
    done <<< "$STAGED_LIST"
  else
    grep -rIlE "($SECRET_RE)" "${INCLUDE_ARGS[@]}" . 2>/dev/null \
      | { if [ -n "${EXCLUDE_RE:-}" ]; then grep -vE "($EXCLUDE_RE)"; else cat; fi; } \
      || true
  fi
}

# scan_env_files
#
# Prints committed .env paths from the git index, recursive. Allows
# .env.example / .env.sample / .env.template to remain as docs. Empty
# output when not in a git work tree.
scan_env_files() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  git ls-files 2>/dev/null \
    | grep -E '(^|/)\.env($|\.)' \
    | grep -vE '\.env\.(example|sample|template)$' \
    || true
}
