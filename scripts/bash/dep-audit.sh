#!/usr/bin/env bash
# TEKIMAX Secure SDD — dependency CVE scan (Gate G)
# Invoked by speckit.tekimax-security.dep-audit or from gate-check.sh.
#
# Resolution order (first available wins):
#   1. osv-scanner  — polyglot, fast, no account needed (OSV.dev)
#   2. pnpm audit   — if pnpm-lock.yaml present and pnpm on PATH
#   3. npm audit    — if package-lock.json present and npm on PATH
#   4. yarn npm audit — if yarn.lock present (Yarn 2+)
#   5. Skip cleanly if none are available (exit 0).
#
# Threshold configurable via dep_audit.fail_on (low|moderate|high|
# critical). Default: high. Emit JSON with --json. Opt-out via
# dep_audit.enabled: false.
#
# Exits 0 when no findings meet/exceed the threshold, 1 when they do.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"
# shellcheck source=lib/defaults.sh
source "$SCRIPT_DIR/lib/defaults.sh"

EXT_DIR=".specify/extensions/tekimax-security"
CONFIG="$EXT_DIR/tekimax-security-config.yml"
LOG_DIR=".tekimax-security"
DEP_LOG="$LOG_DIR/dep-audit-log.jsonl"
mkdir -p "$LOG_DIR"

EMIT_JSON=0
for arg in "$@"; do
  case "$arg" in
    --json) EMIT_JSON=1 ;;
  esac
done

ENABLED=$(config_get "$CONFIG" "dep_audit.enabled" 2>/dev/null || true)
[ -z "$ENABLED" ] && ENABLED="true"
FAIL_ON=$(config_get "$CONFIG" "dep_audit.fail_on" 2>/dev/null || true)
[ -z "$FAIL_ON" ] && FAIL_ON="high"

if [ "$ENABLED" = "false" ]; then
  echo "dep-audit skipped (disabled via config)"
  [ "$EMIT_JSON" = "1" ] && echo '{"tool":"none","verdict":"SKIP","reason":"disabled"}'
  exit 0
fi

severity_weight() {
  case "${1:-unknown}" in
    critical|CRITICAL) echo 4 ;;
    high|HIGH)         echo 3 ;;
    moderate|MODERATE|medium|MEDIUM) echo 2 ;;
    low|LOW)           echo 1 ;;
    *)                 echo 0 ;;
  esac
}
THRESHOLD=$(severity_weight "$FAIL_ON")

TOOL=""
if command -v osv-scanner >/dev/null 2>&1; then
  TOOL="osv-scanner"
elif [ -f pnpm-lock.yaml ] && command -v pnpm >/dev/null 2>&1; then
  TOOL="pnpm"
elif [ -f package-lock.json ] && command -v npm >/dev/null 2>&1; then
  TOOL="npm"
elif [ -f yarn.lock ] && command -v yarn >/dev/null 2>&1; then
  TOOL="yarn"
fi

if [ -z "$TOOL" ]; then
  echo "dep-audit skipped (no scanner available — install osv-scanner for polyglot coverage, or pnpm/npm/yarn for lockfile audit)"
  [ "$EMIT_JSON" = "1" ] && echo '{"tool":"none","verdict":"SKIP","reason":"no-scanner-available"}'
  exit 0
fi

# Confine scan to the project root — refuse to run if the cwd is
# somehow outside the tree.
require_inside_project "." "project root"

CRIT=0; HIGH=0; MOD=0; LOW=0; TOTAL=0
WORST=0
FINDINGS_JSON="[]"

case "$TOOL" in
  osv-scanner)
    OUT=$(osv-scanner --format=json --recursive . 2>/dev/null || true)
    if [ -n "$OUT" ]; then
      parsed=$(DEP_AUDIT_JSON="$OUT" python3 <<'PY' 2>/dev/null || true
import json, os, sys
try:
    data = json.loads(os.environ.get("DEP_AUDIT_JSON", "{}"))
except Exception:
    print("0|0|0|0|0"); print("[]"); sys.exit(0)
crit=high=mod=low=total=0
findings=[]
for r in data.get("results", []):
    for pkg in r.get("packages", []):
        pkg_info = pkg.get("package", {})
        name = pkg_info.get("name", "?")
        for v in pkg.get("vulnerabilities", []):
            total += 1
            sev = "unknown"
            for s in v.get("severity", []):
                score = str(s.get("score", ""))
                up = score.upper()
                if "CRITICAL" in up or score.startswith(("9","10")): sev = "critical"
                elif "HIGH" in up or score.startswith(("7","8")):    sev = "high"
                elif "MEDIUM" in up or score.startswith(("4","5","6")): sev = "moderate"
                elif "LOW" in up or score.startswith(("0","1","2","3")): sev = "low"
            if sev == "critical": crit += 1
            elif sev == "high":   high += 1
            elif sev == "moderate": mod += 1
            elif sev == "low":    low += 1
            findings.append({"id": v.get("id",""), "pkg": name, "severity": sev, "summary": v.get("summary","")[:200]})
print(f"{crit}|{high}|{mod}|{low}|{total}")
print(json.dumps(findings[:50]))
PY
)
      line1=$(printf '%s' "$parsed" | sed -n '1p')
      line2=$(printf '%s' "$parsed" | sed -n '2p')
      IFS='|' read -r CRIT HIGH MOD LOW TOTAL <<EOF
$line1
EOF
      [ -n "$line2" ] && FINDINGS_JSON="$line2"
    fi
    ;;
  pnpm)
    OUT=$(pnpm audit --json 2>/dev/null || true)
    if [ -n "$OUT" ]; then
      parsed=$(DEP_AUDIT_JSON="$OUT" python3 <<'PY' 2>/dev/null || true
import json, os, sys
try:
    data = json.loads(os.environ.get("DEP_AUDIT_JSON", "{}"))
except Exception:
    print("0|0|0|0|0"); print("[]"); sys.exit(0)
meta = data.get("metadata", {}).get("vulnerabilities", {})
crit = meta.get("critical", 0); high = meta.get("high", 0)
mod  = meta.get("moderate", 0); low = meta.get("low", 0)
total = crit + high + mod + low
findings = []
for adv in (data.get("advisories") or {}).values():
    findings.append({"id": adv.get("github_advisory_id") or adv.get("id",""),
                     "pkg": adv.get("module_name",""),
                     "severity": adv.get("severity","unknown"),
                     "summary": (adv.get("title","") or "")[:200]})
print(f"{crit}|{high}|{mod}|{low}|{total}")
print(json.dumps(findings[:50]))
PY
)
      line1=$(printf '%s' "$parsed" | sed -n '1p')
      line2=$(printf '%s' "$parsed" | sed -n '2p')
      IFS='|' read -r CRIT HIGH MOD LOW TOTAL <<EOF
$line1
EOF
      [ -n "$line2" ] && FINDINGS_JSON="$line2"
    fi
    ;;
  npm)
    OUT=$(npm audit --json 2>/dev/null || true)
    if [ -n "$OUT" ]; then
      parsed=$(DEP_AUDIT_JSON="$OUT" python3 <<'PY' 2>/dev/null || true
import json, os, sys
try:
    data = json.loads(os.environ.get("DEP_AUDIT_JSON", "{}"))
except Exception:
    print("0|0|0|0|0"); print("[]"); sys.exit(0)
meta = data.get("metadata", {}).get("vulnerabilities", {})
crit = meta.get("critical", 0); high = meta.get("high", 0)
mod  = meta.get("moderate", 0); low = meta.get("low", 0)
total = crit + high + mod + low
findings = []
for name, v in (data.get("vulnerabilities") or {}).items():
    findings.append({"id": f"npm:{name}", "pkg": name,
                     "severity": v.get("severity","unknown"),
                     "summary": ""})
print(f"{crit}|{high}|{mod}|{low}|{total}")
print(json.dumps(findings[:50]))
PY
)
      line1=$(printf '%s' "$parsed" | sed -n '1p')
      line2=$(printf '%s' "$parsed" | sed -n '2p')
      IFS='|' read -r CRIT HIGH MOD LOW TOTAL <<EOF
$line1
EOF
      [ -n "$line2" ] && FINDINGS_JSON="$line2"
    fi
    ;;
  yarn)
    OUT=$(yarn npm audit --all --recursive --json 2>/dev/null || true)
    if [ -n "$OUT" ]; then
      parsed=$(DEP_AUDIT_JSON="$OUT" python3 <<'PY' 2>/dev/null || true
import json, os
crit=high=mod=low=total=0
findings=[]
for line in (os.environ.get("DEP_AUDIT_JSON", "").splitlines()):
    line=line.strip()
    if not line: continue
    try:
        obj=json.loads(line)
    except Exception:
        continue
    sev=(obj.get("severity") or "").lower()
    if sev=="critical": crit+=1
    elif sev=="high":   high+=1
    elif sev=="moderate": mod+=1
    elif sev=="low":    low+=1
    total+=1
    findings.append({"id": obj.get("id",""), "pkg": obj.get("value",""), "severity": sev, "summary": (obj.get("children",{}).get("Issue","") or "")[:200]})
print(f"{crit}|{high}|{mod}|{low}|{total}")
print(json.dumps(findings[:50]))
PY
)
      line1=$(printf '%s' "$parsed" | sed -n '1p')
      line2=$(printf '%s' "$parsed" | sed -n '2p')
      IFS='|' read -r CRIT HIGH MOD LOW TOTAL <<EOF
$line1
EOF
      [ -n "$line2" ] && FINDINGS_JSON="$line2"
    fi
    ;;
esac

if   [ "${CRIT:-0}" -gt 0 ]; then WORST=4
elif [ "${HIGH:-0}" -gt 0 ]; then WORST=3
elif [ "${MOD:-0}" -gt 0 ];  then WORST=2
elif [ "${LOW:-0}" -gt 0 ];  then WORST=1
else WORST=0; fi

VERDICT="PASS"
[ "$WORST" -ge "$THRESHOLD" ] && VERDICT="BLOCK"

if [ "$EMIT_JSON" = "0" ]; then
  echo
  echo "┌─────────────────────────────────────────────────┐"
  echo "│ Dependency CVE Scan (Gate G)                    │"
  echo "├─────────────────────────────────────────────────┤"
  printf "│ tool: %-42s│\n" "$TOOL"
  printf "│ threshold: %-37s│\n" "$FAIL_ON"
  printf "│ critical=%s  high=%s  moderate=%s  low=%s%*s│\n" \
    "${CRIT:-0}" "${HIGH:-0}" "${MOD:-0}" "${LOW:-0}" 15 ""
  echo "└─────────────────────────────────────────────────┘"
  echo "VERDICT: $VERDICT (total=${TOTAL:-0})"
else
  printf '{"tool":"%s","verdict":"%s","threshold":"%s","counts":{"critical":%s,"high":%s,"moderate":%s,"low":%s,"total":%s},"findings":%s}\n' \
    "$TOOL" "$VERDICT" "$FAIL_ON" \
    "${CRIT:-0}" "${HIGH:-0}" "${MOD:-0}" "${LOW:-0}" "${TOTAL:-0}" \
    "$FINDINGS_JSON"
fi

TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
USER_NAME=$(git config user.name 2>/dev/null || echo "unknown")
jsonl_append "$DEP_LOG" \
  "ts"        "$TS" \
  "user"      "$USER_NAME" \
  "tool"      "$TOOL" \
  "threshold" "$FAIL_ON" \
  "critical"  "${CRIT:-0}" \
  "high"      "${HIGH:-0}" \
  "moderate"  "${MOD:-0}" \
  "low"       "${LOW:-0}" \
  "verdict"   "$VERDICT"

[ "$VERDICT" = "PASS" ] && exit 0 || exit 1
