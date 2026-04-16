# Update `tekimax-security` to v0.3.1 in community catalog

Updates the TEKIMAX Secure SDD extension catalog entry to v0.3.1 with
a new dependency CVE gate, polyglot scan coverage, and an anchored
gateway allowlist.

## What changed since v0.3.0

### Added in v0.3.1

- **Gate G — Dependency CVEs.** New `dep-audit.sh` and
  `speckit.tekimax-security.dep-audit` command. Resolution chain:
  `osv-scanner` (polyglot, preferred) → `pnpm audit` → `npm audit`
  → `yarn npm audit`. Threshold via `dep_audit.fail_on`
  (`low`|`moderate`|`high`|`critical`, default `high`). Runs
  automatically as part of `gate-check` and logs to
  `.tekimax-security/dep-audit-log.jsonl`.
- **Polyglot file coverage for Gate F and the audit.** TS/JS/Py
  plus Go, Rust, Ruby, Java, Kotlin, Swift, PHP, shell, YAML,
  JSON, TOML, Terraform, Markdown. Secrets and inline prompts
  commonly land in CI YAML and Terraform, not only application
  code.
- **`audit.include_globs`, `audit.exclude_paths`,
  `audit.direct_sdk_patterns`** config keys. Built-in direct-SDK
  list expanded to include `cohere-ai`, `@mistralai/mistralai`,
  `@aws-sdk/client-bedrock-runtime`, `replicate`, `together-ai`.
- **`--staged-only` and `--json` flags** on `audit.sh`,
  `gate-check.sh`, and `dep-audit.sh`. Pre-commit-hook friendly;
  CI-friendly.
- **Recursive `.env` detection.** `apps/*/.env`,
  `packages/*/.env.local`, and similar nested env files are now
  flagged. `.env.example`, `.env.sample`, and `.env.template`
  remain allowed.

### Changed in v0.3.1 (breaking)

- **Gateway allowlist uses anchored matching.** An entry
  `src/ai/gateway` matches the exact path, any subdirectory, or a
  file-extension append. It no longer silently matches
  `src/ai/gateway-bypass.ts`. Projects that relied on the
  substring match must list the full file path or the containing
  directory.

### Carried forward from v0.3.0

- Project-root confinement on all file-path arguments
  (`require_inside_project`) — prevents path traversal and
  symlink attacks.
- JSONL injection prevention (`jsonl_append`,
  `jsonl_append_chained`) — values serialized via Python
  `json.dumps`, shell metacharacters cannot break output.
- Tamper-evident hash chain on every gate-log entry
  (SHA-256 of previous line, no crypto signing dependencies).
- Gate B verifies STRIDE table has content rows, not just a
  heading. Gate D verifies numeric rate limit and cost ceiling.

## The nine commands

| Command | Hook | Catches |
|---|---|---|
| `data-contract` | `after_specify` | Data debt — unvetted sources, unprotected PII, undeclared schemas |
| `threat-model` | `after_plan` | Design-time security flaws via STRIDE |
| `model-governance` | manual | Model debt — unpinned versions, no rollback, no eval baselines |
| `guardrails` | manual | Prompt debt — no input validation, no output redaction |
| `gate-check` | `before_implement` | Blocks until all seven security gates pass |
| `audit` | `after_implement` | Inline prompts, committed secrets, SDK imports, guardrail drift (polyglot) |
| `dep-audit` | part of `gate-check` | Dependency CVEs (Gate G) via osv-scanner / pnpm / npm / yarn |
| `red-team` | `before_analyze` | Adversarial testing — prompt injection, jailbreak, extraction |
| `install-rules` | manual | Development discipline — commit hygiene, DRY, naming, tests |

## Verification

- [x] `extension.yml` validates (v0.3.1)
- [x] Installs cleanly via `specify extension add --dev`
- [x] All 9 commands register correctly
- [x] 18/18 tests pass on macOS and Ubuntu
- [x] ShellCheck passes on all scripts (CI-enforcing)
- [x] `.extensionignore` excludes dev-only files
- [x] Apache 2.0 license included
- [x] Zero open Dependabot vulnerabilities

## Links

- Repo: https://github.com/TEKIMAX/speckit-security
- Docs: https://speckit.tekimax.com
- Changelog: https://github.com/TEKIMAX/speckit-security/blob/main/CHANGELOG.md
- Release: https://github.com/TEKIMAX/speckit-security/releases/tag/v0.3.1

## Compatibility

Requires `speckit_version >= 0.1.0`.
