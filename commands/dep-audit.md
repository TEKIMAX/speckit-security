---
description: "Scan project dependencies for known CVEs via osv-scanner / pnpm / npm / yarn (Gate G)"
scripts:
  sh: ../../scripts/bash/dep-audit.sh
---

# Dependency CVE Scan (Gate G)

Scan the project's locked dependencies for known vulnerabilities
published to the OSV database or the relevant package manager's
advisory feed.

## User Input

$ARGUMENTS

## Context

Spec Kit writes application code; it never touches `package.json`,
`Cargo.toml`, `go.mod`, or any other manifest. Vulnerable
dependencies therefore slip past every other gate in this
extension. Gate G closes that loop by scanning the committed
lockfile and failing when findings meet or exceed the configured
severity threshold.

## Steps

1. **Run the dependency audit**:

   ```bash
   bash {SCRIPT}
   ```

   Add `--json` for machine-readable output (CI, dashboards):

   ```bash
   bash {SCRIPT} --json
   ```

2. **Scanner resolution** (first available wins):

   - `osv-scanner` on `PATH` — preferred. Polyglot (npm, pypi,
     cargo, go, maven, gem), no account needed, queries OSV.dev.
   - `pnpm audit` — if `pnpm-lock.yaml` is present.
   - `npm audit` — if `package-lock.json` is present.
   - `yarn npm audit` — if `yarn.lock` is present (Yarn 2+).
   - None available → skip with a clear message (exit 0).

3. **Severity threshold** — read from
   `tekimax-security-config.yml`:

   ```yaml
   dep_audit:
     enabled: true
     fail_on: high    # low | moderate | high | critical
   ```

   `fail_on: high` blocks on any high or critical finding. Set
   `enabled: false` to skip Gate G entirely (useful for repos with
   no runtime dependencies).

4. **Report** — human table by default:

   ```
   ┌─────────────────────────────────────────────────┐
   │ Dependency CVE Scan (Gate G)                    │
   ├─────────────────────────────────────────────────┤
   │ tool: osv-scanner                               │
   │ threshold: high                                 │
   │ critical=0  high=2  moderate=5  low=1           │
   └─────────────────────────────────────────────────┘
   VERDICT: BLOCK (total=8)
   ```

5. **Log** the verdict to
   `.tekimax-security/dep-audit-log.jsonl` (append-only).

## Rules

- Never print the actual SBOM or full advisory payload in the
  console — only counts and verdict. Use `--json` when a machine
  consumer needs detail.
- Gate G does **not** auto-fix. Remediation is a separate
  workflow (bump the direct dep, run `pnpm update`, etc.).
- `osv-scanner` is strictly preferred. Install it once per machine
  and every repo benefits:

  ```bash
  brew install osv-scanner      # macOS
  go install github.com/google/osv-scanner/cmd/osv-scanner@v1
  ```
