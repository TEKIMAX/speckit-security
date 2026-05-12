#!/usr/bin/env bash
# Gate decision functions for speckit-security gate-check.sh.
#
# Each check_gate_<x> function returns its verdict as a single line
# on stdout, one of:
#   pass
#   fail: <reason>
#   skip: <reason>
#
# The caller (gate-check.sh) collects these strings, sets the FAIL
# flag when any begin with "fail:", and renders the report.
#
# Functions are pure with respect to the verdict string — they don't
# touch global FAIL counters or the JSONL log. That keeps each gate
# unit-testable in isolation.

# has_section <spec_path> <heading>
#
# Returns 0 if the heading appears as a literal line in the spec.
has_section() {
  local spec="$1" heading="$2"
  grep -qF "$heading" "$spec"
}

# check_gate_a <spec_path> <spec_slug>
#
# Gate A — Data Contract. Requires either "## 2. Data Contract" or
# "## Data Contract" plus a Zod schema file at src/schemas/<slug>.ts
# with no z.any() escape hatches.
check_gate_a() {
  local spec="$1" slug="$2"
  if ! has_section "$spec" "## 2. Data Contract" \
     && ! has_section "$spec" "## Data Contract"; then
    echo "fail: missing Data Contract section"
    return
  fi
  local schema="src/schemas/${slug}.ts"
  if [ ! -f "$schema" ]; then
    echo "fail: missing ${schema}"
    return
  fi
  if grep -q "z\.any()" "$schema"; then
    echo "fail: z.any() in schema"
    return
  fi
  echo "pass"
}

# check_gate_b <spec_path>
#
# Gate B — STRIDE Threat Model. Requires either a "## Security / Threat
# Model" section or a "## Security" section that mentions STRIDE.
# Blocks on any unmitigated High/Critical row. Also blocks when the
# table has only the heading and no threat rows.
check_gate_b() {
  local spec="$1"
  if ! has_section "$spec" "## Security / Threat Model" \
     && ! { has_section "$spec" "## Security" && grep -qi "STRIDE\|Spoofing" "$spec"; }; then
    echo "fail: missing threat model"
    return
  fi
  if grep -q '\[UNMITIGATED\].*\(High\|Critical\)' "$spec"; then
    echo "fail: High/Critical unmitigated threats"
    return
  fi
  if ! grep -qE '^\|[[:space:]]*T[0-9]' "$spec" \
     && ! grep -qE '^\|[[:space:]]*(Spoofing|Tampering|Repudiation|Info|Denial|Elevation)' "$spec"; then
    echo "fail: STRIDE table has no threat rows"
    return
  fi
  echo "pass"
}

# check_gate_c <spec_path>
#
# Gate C — Model Governance. Skips when the spec has no AI integration.
# Blocks on unpinned model versions ("latest", "stable") or missing
# rollback plan.
check_gate_c() {
  local spec="$1"
  if ! grep -qi "AI Integration\|model:" "$spec"; then
    echo "skip: no AI integration"
    return
  fi
  if grep -qE 'latest|"stable"' "$spec"; then
    echo "fail: unpinned model version"
    return
  fi
  if ! grep -qi "Rollback" "$spec"; then
    echo "fail: missing rollback plan"
    return
  fi
  echo "pass"
}

# check_gate_d <spec_slug> <gate_c_verdict>
#
# Gate D — Guardrails. Skips when Gate C reported "skip: no AI
# integration" (no AI features in the spec). Requires both a
# guardrail YAML and a system prompt for the spec slug, plus numeric
# rate_per_user_per_minute and cost_ceiling_usd_per_day in the YAML.
check_gate_d() {
  local slug="$1" gate_c="$2"
  if [ "$gate_c" = "skip: no AI integration" ]; then
    echo "skip: no AI integration"
    return
  fi
  local guardrail="prompts/guardrails/${slug}.yml"
  local sysprompt="prompts/system/${slug}.md"
  if [ ! -f "$guardrail" ] || [ ! -f "$sysprompt" ]; then
    echo "fail: missing prompt or guardrail files"
    return
  fi
  if ! grep -q "blocked_patterns:" "$guardrail" \
     || ! grep -q "redact_patterns:" "$guardrail"; then
    echo "fail: guardrail missing blocked/redact patterns"
    return
  fi
  if ! grep -qE "rate_per_user_per_minute:[[:space:]]*[0-9]" "$guardrail"; then
    echo "fail: rate_per_user_per_minute missing or not numeric"
    return
  fi
  if ! grep -qE "cost_ceiling_usd_per_day:[[:space:]]*[0-9]" "$guardrail"; then
    echo "fail: cost_ceiling_usd_per_day missing or not numeric"
    return
  fi
  echo "pass"
}

# check_gate_e <spec_slug>
#
# Gate E — Red Team. Looks for any red-team/RT-*-<slug>.md report.
# Skips (with warning) when absent so spec authors aren't blocked
# during SPECIFY/DESIGN; flips to required in pre-ship review.
check_gate_e() {
  local slug="$1"
  if ls red-team/RT-*-"${slug}".md >/dev/null 2>&1; then
    echo "pass"
  else
    echo "skip: no red-team report (required before ship)"
  fi
}

# check_gate_f <staged_only_flag>
#
# Gate F — Inline Content Scan (polyglot). Uses scan_* helpers from
# lib/scan.sh against the configured pattern sets. Returns "pass" or
# "fail: <kinds>" listing which scan categories tripped.
#
# Reads the same globals as scan_inline_prompts / scan_secrets:
#   STAGED_LIST, INCLUDE_ARGS, EXCLUDE_RE, INLINE_PROMPT_RE,
#   SECRET_RE, GATEWAY_ALLOWLIST
check_gate_f() {
  local staged="$1"
  local inline_hit=0 secret_hit=0 env_hit=0

  if [ -n "$(scan_inline_prompts "$staged")" ]; then
    inline_hit=1
  fi
  if [ -n "$(scan_secrets "$staged")" ]; then
    secret_hit=1
  fi
  if [ -n "$(scan_env_files)" ]; then
    env_hit=1
  fi

  if [ $inline_hit -eq 0 ] && [ $secret_hit -eq 0 ] && [ $env_hit -eq 0 ]; then
    echo "pass"
    return
  fi
  local msgs=""
  [ $inline_hit -eq 1 ] && msgs="${msgs}inline-prompts "
  [ $secret_hit -eq 1 ] && msgs="${msgs}committed-secrets "
  [ $env_hit -eq 1 ]    && msgs="${msgs}.env-committed "
  echo "fail: ${msgs% }"
}

# check_gate_g <script_dir> <config_path>
#
# Gate G — Dependency CVEs. Delegates to dep-audit.sh when available
# and not disabled via config. Skip cleanly when no scanner is
# installed.
check_gate_g() {
  local script_dir="$1" config="$2"
  local enabled
  enabled=$(config_get "$config" "dep_audit.enabled" 2>/dev/null || true)
  [ -z "$enabled" ] && enabled="true"
  if [ "$enabled" = "false" ]; then
    echo "skip: disabled via config"
    return
  fi
  if [ ! -x "$script_dir/dep-audit.sh" ]; then
    echo "skip: dep-audit.sh not installed"
    return
  fi
  local out
  out=$("$script_dir/dep-audit.sh" 2>&1 || true)
  case "$out" in
    *"VERDICT: PASS"*)  echo "pass" ;;
    *"VERDICT: BLOCK"*) echo "fail: vulnerable deps at/above threshold" ;;
    *)                  echo "skip: no scanner available" ;;
  esac
}

# render_gate_box <spec_id> <gate_a> <gate_b> ... <gate_g>
#
# Prints the human-readable result box for the seven gates. Each gate
# argument is the verdict string from check_gate_<x>.
render_gate_box() {
  local spec_id="$1"
  shift
  local -a results=("$@")
  local -a labels=(
    "Gate A — Data Contract"
    "Gate B — Threat Model"
    "Gate C — Model Governance"
    "Gate D — Guardrails"
    "Gate E — Red Team"
    "Gate F — Inline Content Scan"
    "Gate G — Dependency CVEs"
  )
  echo
  echo "┌─────────────────────────────────────────────────┐"
  printf "│ Security Gate Check — %-26s │\n" "$spec_id"
  echo "├─────────────────────────────────────────────────┤"
  local i status icon
  for i in 0 1 2 3 4 5 6; do
    status="${results[$i]}"
    icon="✅"
    case "$status" in
      fail:*) icon="❌" ;;
      skip:*) icon="⚠ " ;;
    esac
    printf "│ %-30s %s  %-9s │\n" "${labels[$i]}" "$icon" "${status%%:*}"
    case "${status%%:*}" in
      fail|skip) printf "│   %-45s │\n" "${status#*: }" ;;
    esac
  done
  echo "└─────────────────────────────────────────────────┘"
}
