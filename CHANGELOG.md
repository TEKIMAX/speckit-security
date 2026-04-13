# Changelog

All notable changes to `tekimax-security` will be documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) · SemVer.

## [0.2.0] — 2026-04-13

### Added
- **Automated red-team runner** (`scripts/bash/red-team-run.sh`) —
  parses `red-team/RT-XXX-*.md` scenario blocks, POSTs each input to a
  staging endpoint, classifies responses (blocked / partial / succeeded
  based on HTTP code and refusal markers), writes a JSONL trace to
  `.tekimax-security/red-team-traces.jsonl`, and exits non-zero on any
  succeeded attack.
- **Safety guards**: refuses any URL matching `prod`/`production`,
  rate-limits per `red_team.max_rps` (default 10), injects
  `X-Red-Team: tekimax-security` header.
- **Public catalog submission draft** in `catalog/` — ready for
  community catalog PR (submission gated on user confirmation).

### Fixed
- `gate-check.sh` — POSIX `[[:space:]]` instead of `\s` so inline
  prompts actually match on macOS.
- `audit.sh` — `set -e` no longer terminates on the last `[` test;
  empty-array check swapped for counter sum.
- `.extensionignore` — now excludes `.git/` to prevent working-tree
  git directory leaking into installed extensions.

## [0.1.0] — 2026-04-13

### Added
- Initial extension scaffold targeting Spec Kit `>= 0.1.0`
- Seven commands:
  - `speckit.tekimax-security.data-contract`
  - `speckit.tekimax-security.threat-model`
  - `speckit.tekimax-security.model-governance`
  - `speckit.tekimax-security.guardrails`
  - `speckit.tekimax-security.gate-check`
  - `speckit.tekimax-security.audit`
  - `speckit.tekimax-security.red-team`
- Five integration hooks: `after_specify`, `after_plan`,
  `before_implement`, `after_implement`, `before_analyze`
- Six gate checks (A–F): Data Contract, Threat Model, Model Governance,
  Guardrails, Red Team, Inline Content Scan
- Bash helper scripts: `gate-check.sh`, `audit.sh`
- Templates: STRIDE threat model, red team scenarios, data contract,
  model governance, guardrail YAML, eval YAML, security gate checklist
- Config template with TEKIMAX stack defaults

### Notes
- Alpha release. API may change before `1.0.0`.
- Bundled for private install via `specify extension add --dev`.
- Public catalog submission planned for `0.2.0`.
