# Changelog

All notable changes to `tekimax-security` will be documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) · SemVer.

## [0.2.1] — 2026-04-13

### Added

- **New command** `speckit.tekimax-security.install-rules` — installs a
  `docs/DEVELOPMENT-RULES.md` into the user's project covering commit
  message hygiene, file structure, code organization (DRY, helper
  extraction), file length targets, naming conventions, inline
  documentation rules, and incremental unit test requirements.
- **Generic development rules template** at
  `templates/development-rules.md` — stack-agnostic, customizable,
  ships via the new install command.
- **Contributor development rules** at `docs/DEVELOPMENT-RULES.md` —
  repo-specific discipline for anyone contributing to
  `speckit-security` itself.
- **Agent compatibility matrix** at `docs/AGENT-COMPATIBILITY.md` —
  documents which agents are hands-on verified versus inferred from
  Spec Kit's supported list. Claude Code, OpenCode, GitHub Copilot,
  Gemini CLI, and Cursor are verified end-to-end.
- **Zero-dependency test suite** at `tests/` with 5 initial tests
  covering the critical `gate-check` and `audit` paths:
  - `gate-check/pass-clean.sh`
  - `gate-check/block-no-data-contract.sh`
  - `gate-check/block-inline-prompt.sh` (regression test for the
    POSIX `grep` bug)
  - `audit/pass-clean.sh`
  - `audit/block-committed-secret.sh` (regression test for the
    `set -e` early-exit bug)
- **Test runner** at `tests/run.sh` — runs every suite or a single
  test, prints human-readable summary, zero runtime dependencies
  beyond POSIX bash.
- **Assertion helpers** at `tests/lib/assert.sh` and fixture builder
  at `tests/lib/fixture.sh` for reuse across tests.
- **Test documentation** at `tests/README.md` — how to run tests, what
  each test covers, how to write a new one.

### Changed

- **`extension.yml`** — registers the new eighth command
  `install-rules`.
- **`CONTRIBUTING.md`** — references the development rules doc and
  the tests directory.
- **`README.md`** — links the new customization, agent compatibility,
  development rules, and tests docs.

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
