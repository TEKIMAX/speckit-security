# Changelog

All notable changes to `tekimax-security` will be documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) · SemVer.

## [0.2.5] — 2026-04-14

### Added

- **Config read-back for `audit.sh` and `gate-check.sh`.** User
  entries in `tekimax-security-config.yml` now actually extend the
  built-in defaults at runtime, instead of being ignored. Supported
  config keys:
  - `audit.allowlist.stack_direct_sdk` — additional substrings
    treated as "gateway" paths for the direct-SDK-import check
    and Gate F inline-prompt suppression
  - `audit.secret_patterns` — additional ERE alternations for the
    committed-secret scan in both Gate F and the post-implementation
    audit
  - `audit.inline_prompt_patterns` — additional ERE alternations
    for inline-prompt detection in both Gate F and the audit
- **Config read-back for `red-team-run.sh`.** `red_team.max_rps`
  is now read from config (env var still takes precedence).
  `red_team.staging_url` already worked, now goes through the
  shared `config.sh` helper.
- **`scripts/bash/lib/config.sh`** — sourceable YAML reader helper.
  Exposes `config_get` (scalar) and `config_list` (list of strings)
  by dotted path. Missing files and missing keys return empty so
  callers can fall back to defaults without special-casing errors.
  Uses `python3` with the standard library only (no third-party
  YAML package required).
- Four new tests covering the parser at depths 1–3, the audit
  allowlist extension, and the audit secret-pattern extension.

### Changed

- Gate F inline-prompt detection now uses the shared allowlist
  (`is_gateway_allowed`), which matches full path substrings like
  `src/ai/gateway` instead of the previous behavior of excluding
  any file with the literal substring "gateway" anywhere in the
  path. This is stricter by default; projects that previously
  relied on the loose `-v gateway` filter should add their
  gateway path to `audit.allowlist.stack_direct_sdk` in config.
- `gate-check.sh` and `audit.sh` now invoke `python3` (via the
  shared config reader). Previously only `install-rules.sh` and
  `red-team-run.sh` needed python3; now all four do. No new
  third-party dependencies — standard library only.
- Docs under `docs/customization` rewritten to match actual
  read-back behavior.

### Not yet config-driven (tracked for a later release)

- `required_sections` (Gate A/B header text remains hardcoded)
- `audit.file_scope` (grep `--include` flags remain hardcoded)
- `red_team.never_run_against` (intentionally hardcoded as a
  defense-in-depth safety guardrail)

## [0.2.4] — 2026-04-13

### Fixed

- **Inline-prompt detection was over-matching legal and privacy copy.**
  The previous pattern `[Yy]ou[[:space:]]+are[[:space:]]+a` matched
  any second-person construction, so any Terms of Service or Privacy
  Policy page containing clauses like "If you are a California
  resident" or "If you are a HIPAA covered entity" would trip as
  though it were an inline AI system prompt. Tightened to require an
  AI-specific role keyword immediately after the article:

  - `helpful` (matches `"You are a helpful assistant"`)
  - `AI` / `ai` (matches `"You are an AI assistant"`)
  - `virtual`, `assistant`, `chatbot`, `expert`, `friendly`,
    `knowledgeable`, `precise`, `professional`, `skilled`, `senior`,
    `world`, `conversational`, `advanced`, `state-of-the-art`
  - `large language` / `language model` (matches `"You are a large
    language model"` and variants)

  Also now catches ChatML variants (`<|system|>`, `<|im_start|>system`)
  and role-prefix lines (`SYSTEM:`, `Assistant:`) as separate
  alternatives in the same regex.

  Same fix applied to both `scripts/bash/audit.sh` and
  `scripts/bash/gate-check.sh` Gate F so the gate and the audit
  agree.

### Added

- **`tests/audit/skip-legal-prose.sh`** — regression test that plants
  a realistic Terms of Service JSX file containing five different
  second-person legal clauses ("If you are a California resident",
  "If you are a Texas resident", "If you are a HIPAA covered entity",
  etc.) and asserts the audit still passes clean. None of those
  phrases are AI system prompts and none should flag.

Test suite is now 11 tests (was 10). All pass on macOS bash 3.2.

## [0.2.3] — 2026-04-13

### Fixed

- **`audit.sh` and `gate-check.sh` secret detection** — two classes
  of false positives eliminated, found by running the audit against
  the project's own `docs-site/`:

  1. **Build-artifact walking.** The scripts walked the filesystem
     for secret patterns and hit compiled output under `.next/`,
     `out/`, `.source/`, and `.wrangler/`. Those directories are
     gitignored but the scripts weren't excluding them. Added all
     four to the exclusion regex alongside `node_modules/`, `.git/`,
     and `dist/`.

  2. **Pattern over-matching.** The previous regexes matched bare
     prefixes like `sk_live_`, `sk_test_`, and the bare identifier
     `PRIVATE_KEY`. Documentation and example code that *mentions*
     these patterns tripped the audit. Tightened to require real
     key material:
     - `sk_live_[0-9a-zA-Z]{24,}` (Stripe live keys are 24+ chars)
     - `sk_test_[0-9a-zA-Z]{24,}`
     - Full PEM header `-----BEGIN (RSA |EC |DSA |OPENSSH |ENCRYPTED )?PRIVATE KEY-----`
       instead of bare `PRIVATE_KEY` or `BEGIN RSA`
     - `ghp_[0-9a-zA-Z]{36}`, `gho_...`, `ghs_...` for GitHub tokens
     - `xoxb-[0-9a-zA-Z-]{20,}` for Slack bot tokens
     - `AKIA[0-9A-Z]{16}` and `AIza[0-9A-Za-z_-]{35}` unchanged

### Added

- **Two regression tests** for the fixes above:
  - `tests/audit/skip-build-artifacts.sh` — plants real-looking
    key material inside `.next/` and `out/` via `printf` runtime
    assembly (so the literals never appear in committed source)
    and asserts the audit still passes clean
  - `tests/audit/skip-doc-mentions.sh` — plants bare doc-style
    mentions of prefixes in a `src/` file and asserts the audit
    still passes clean

Test suite is now 10 tests (was 8). All pass on macOS bash 3.2.

## [0.2.2] — 2026-04-13

### Changed

- **`install-rules` command** now writes to three targets instead of
  one, so the rules are binding on the AI agent at runtime instead
  of sitting in a docs file the agent may never read:
  1. `docs/DEVELOPMENT-RULES.md` — full human-readable reference
     (unchanged behavior, existing files backed up with timestamp)
  2. `.specify/memory/constitution.md` — spec-kit constitution, read
     by every spec-kit-aware agent at session start. Appends a
     `## Development Rules` section with the 8 key principles and
     a pointer to the full doc. Safe to re-run — skips if the
     section already exists unless `--force` is passed.
  3. Agent-specific context file — detected from
     `.specify/init-options.json` and mapped per agent:
     - `claude` → `CLAUDE.md`
     - `copilot` → `.github/copilot-instructions.md`
     - `gemini` → `GEMINI.md`
     - `cursor` / `cursor-agent` → `.cursorrules`
     - `windsurf` → `.windsurfrules`
     - everything else → `AGENTS.md` (the emerging cross-agent convention)

- **New helper script** `scripts/bash/install-rules.sh` performs the
  three-target writes atomically. Detects the project name from
  `.specify/init-options.json` or the current directory name.
  Accepts `--docs`, `--project-name`, and `--force` flags. Prints a
  summary box showing which files were created, appended, or skipped.

### Added

- **Three new tests** under `tests/install-rules/`:
  - `writes-three-targets.sh` — claude agent, verifies all three
    files are written and project name is substituted into the docs
  - `agent-fallback.sh` — unknown/generic agent, verifies fallback to
    `AGENTS.md` and constitution creation from scratch
  - `idempotent-append.sh` — running twice doesn't duplicate the
    `## Development Rules` section in the constitution or agent file

Test suite is now 8 tests (was 5). All pass.

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
