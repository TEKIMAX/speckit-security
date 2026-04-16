# Update `tekimax-security` to v0.3.0 in community catalog

Updates the TEKIMAX Secure SDD extension catalog entry from v0.2.0 to
v0.3.0 with security hardening, new gates, and a docs site.

## What changed since v0.2.0

### Security hardening (v0.3.0)

- **Project-root confinement** — all scripts validate file paths stay
  inside the project directory (prevents path traversal and symlink attacks)
- **JSONL injection prevention** — all log output uses Python `json.dumps`
  (shell metacharacters in values cannot break JSON structure)
- **Tamper-evident hash chain** — every gate-log entry includes the SHA-256
  of the previous line for lightweight tamper detection
- **Guardrail completeness audit** — warns on missing rate limits or
  cost ceilings in guardrail YAML files
- **Gate B** now verifies STRIDE table has actual content rows
- **Gate D** now verifies rate limit and cost ceiling are numeric
- ShellCheck enforcing in CI

### Features added since v0.2.0

- **8 commands** (was 7): added `install-rules` for project-wide
  development discipline
- **Docs site** at [speckit.tekimax.com](https://speckit.tekimax.com)
  with full docs, Security Model page, and AI chat
- **Ask AI** grounded docs chat at
  [speckit.tekimax.com/chat](https://speckit.tekimax.com/chat)
- **Config read-back** — user config extends built-in defaults for
  secret patterns, inline-prompt patterns, and gateway allowlist
- **15 automated tests** covering gate-check, audit, config parser,
  and install-rules (zero external deps, POSIX bash only)

## The eight commands

| Command | Hook | Catches |
|---|---|---|
| `data-contract` | `after_specify` | Data debt — unvetted sources, unprotected PII, undeclared schemas |
| `threat-model` | `after_plan` | Design-time security flaws via STRIDE |
| `model-governance` | manual | Model debt — unpinned versions, no rollback, no eval baselines |
| `guardrails` | manual | Prompt debt — no input validation, no output redaction |
| `gate-check` | `before_implement` | Blocks until all six security gates pass |
| `audit` | `after_implement` | Inline prompts, committed secrets, SDK imports, guardrail drift |
| `red-team` | `before_analyze` | Adversarial testing — prompt injection, jailbreak, extraction |
| `install-rules` | manual | Development discipline — commit hygiene, DRY, naming, tests |

## Verification

- [x] `extension.yml` validates (v0.3.0)
- [x] Installs cleanly via `specify extension add --dev`
- [x] All 8 commands register correctly
- [x] 15/15 tests pass on macOS and Ubuntu
- [x] ShellCheck passes on all scripts
- [x] `.extensionignore` excludes dev-only files
- [x] Apache 2.0 license included
- [x] Zero open Dependabot vulnerabilities

## Links

- Repo: https://github.com/TEKIMAX/speckit-security
- Docs: https://speckit.tekimax.com
- Changelog: https://github.com/TEKIMAX/speckit-security/blob/main/CHANGELOG.md
- Release: https://github.com/TEKIMAX/speckit-security/releases/tag/v0.3.0

## Compatibility

Requires `speckit_version >= 0.1.0`.
