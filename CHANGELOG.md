# Changelog

All notable changes to `tekimax-security` will be documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) · SemVer.

## [0.3.1] — 2026-04-16

### Added

- **Gate G — Dependency CVEs.** New `scripts/bash/dep-audit.sh` and
  `speckit.tekimax-security.dep-audit` command. Resolution order:
  `osv-scanner` (polyglot, preferred) → `pnpm audit` → `npm audit`
  → `yarn npm audit`. Skips cleanly when no scanner is available.
  Threshold configurable via `dep_audit.fail_on`
  (`low` | `moderate` | `high` | `critical`, default `high`).
  Opt-out via `dep_audit.enabled: false`. Gate G runs automatically
  as part of `gate-check` and logs to
  `.tekimax-security/dep-audit-log.jsonl`.
- **Polyglot file coverage.** Gate F and the audit now scan Go,
  Rust, Ruby, Java, Kotlin, Swift, PHP, shell, YAML, JSON, TOML,
  Terraform, and Markdown by default — secrets and inline prompts
  commonly live outside TS/Py. Defaults live in
  `lib/defaults.sh:DEFAULT_INCLUDE_EXTS`.
- **`audit.include_globs` and `audit.exclude_paths` config keys**
  to extend the polyglot scan without replacing defaults.
- **`audit.direct_sdk_patterns` config key.** Extend the default
  SDK list (`@google/genai`, `@anthropic-ai/sdk`, `openai`,
  `cohere-ai`, `@mistralai/mistralai`,
  `@aws-sdk/client-bedrock-runtime`, `replicate`, `together-ai`)
  with any provider your stack adopts.
- **`--staged-only` flag** on `audit.sh` and `gate-check.sh`.
  Scans only files in the git index. Pre-commit-hook-friendly: a
  typical change touches <5 files, not the whole tree.
- **`--json` flag** on `audit.sh`, `gate-check.sh`, and
  `dep-audit.sh`. Emits machine-readable findings alongside (or in
  place of) the human table so CI jobs and dashboards don't have
  to re-parse the log file.
- **`build_exclude_regex` and `scan_staged_files`** helpers in
  `lib/defaults.sh` to support polyglot and staged-file scans.
- **Three regression tests:**
  `anchored-allowlist-rejects-prefix-bypass.sh`,
  `polyglot-go-secret.sh`, `env-in-subdirectory.sh`. Suite is 18/18.

### Changed

- **Gateway allowlist uses anchored matching.**
  `_is_gateway_allowed` in `lib/defaults.sh` now matches only at
  the exact path, as a directory prefix with a '/' boundary, or
  with a file-extension append. An entry `src/ai/gateway` no
  longer silently matches `src/ai/gateway-bypass.ts`. Teams that
  relied on the substring match must list full file paths or the
  containing directory.
- **`.env` detection is recursive.** `apps/*/.env`,
  `packages/*/.env.local`, and similar nested env files are now
  detected; previously only the repo root was checked.
  `.env.example`, `.env.sample`, and `.env.template` remain
  allowed.

## [0.3.0] — 2026-04-16

### Added

- **Project-root confinement.** All scripts that accept file path
  arguments now validate paths stay inside the project directory
  using `require_inside_project` in `lib/defaults.sh`. Resolves
  symlinks via `os.path.realpath` and rejects any path that escapes
  `$(pwd -P)`. Applies to `gate-check.sh` (spec path) and
  `install-rules.sh` (`--docs` argument). Prevents path traversal
  via `../..`, absolute paths, and symlink attacks.

- **JSONL injection prevention.** All JSONL output (gate-log,
  audit-log, red-team traces) is now produced by `jsonl_append` and
  `jsonl_append_chained` in `lib/defaults.sh`, which pass every
  value through Python's `json.dumps`. Shell metacharacters in git
  usernames, spec titles, or red-team scenario text can no longer
  break the JSON structure.

- **Tamper-evident hash chain.** Every gate-log JSONL entry now
  includes a `prev_hash` field containing the SHA-256 of the
  previous line (or `"genesis"` for the first entry). Creates a
  lightweight tamper-detection chain without cryptographic signing
  dependencies.

- **`lib/defaults.sh`** — new shared library extracted from the
  duplicated pattern definitions in `audit.sh` and `gate-check.sh`.
  Single source of truth for `DEFAULT_INLINE_PROMPT_RE`,
  `DEFAULT_SECRET_PATTERNS`, `DEFAULT_GATEWAY_ALLOWLIST`, plus
  shared helpers: `join_secret_re`, `_is_gateway_allowed`,
  `require_inside_project`, `jsonl_append`, `jsonl_append_chained`.

- **Guardrail completeness audit (check #6).** `audit.sh` now warns
  on any guardrail YAML file missing `blocked_patterns`,
  `redact_patterns`, `rate_per_user_per_minute`, or
  `cost_ceiling_usd_per_day`.

- **`never_run_against` config wired into red-team runner.** The
  `red_team.never_run_against` config list is now read and checked
  against the staging URL, in addition to the hardcoded `prod` /
  `production` regex guard.

- **Security Model docs page** at `/docs/security` — covers script
  confinement, JSONL injection prevention, hash chain, guardrail
  architecture (spec-time, implementation-time, runtime), secret
  detection patterns, red-team safety layers, and chat Worker
  defenses.

- **Python 3 guard.** `config.sh` and `defaults.sh` now error
  immediately with a clear message if `python3` is not installed,
  instead of silently degrading to empty config reads.

- **Chat Worker response size cap.** 64 KiB `TransformStream`
  backstop on streamed AI responses.

- **Chat Worker CORS hardening.** Localhost origins
  (`localhost:3000-3999`) are no longer allowed in production by
  default. Requires explicit `ALLOW_LOCAL_ORIGINS=true` env var.

### Changed

- **Gate B (Threat Model)** now verifies the STRIDE table contains
  at least one content row (e.g. `| T1 | Spoofing |`), not just
  the section heading. Empty threat model tables fail the gate.

- **Gate D (Guardrails)** now verifies `rate_per_user_per_minute`
  and `cost_ceiling_usd_per_day` are present and numeric in the
  guardrail YAML, not just that `blocked_patterns` and
  `redact_patterns` keys exist.

- **ShellCheck is now enforcing in CI.** Removed `|| true` from the
  shellcheck step in `test.yml` so lint failures block PRs.

- **Secret patterns unified.** `gate-check.sh` Gate F previously
  used a smaller subset of patterns than `audit.sh`. Both now share
  the full set from `lib/defaults.sh`, including `DSA`, `ENCRYPTED`
  private key variants, `xoxb-` Slack tokens, and `gho_`/`ghs_`
  GitHub tokens.

### Fixed

- **Gate B operator precedence.** The `||`/`&&` check for the
  threat model heading was parsed as `A || (B && C)` instead of the
  intended `(A || B) && C`, meaning the STRIDE/Spoofing grep was
  skipped when the `## Security / Threat Model` heading was found.
  Added explicit `{ }` grouping.

## [0.2.6] — 2026-04-14

### Added

- **Docs chat (Ask AI).** New `/chat` page on the docs site backed
  by a Cloudflare Worker running Llama 3.3 70B via Workers AI. The
  full docs corpus (~14k tokens) is embedded in the system prompt
  as a grounding context, so the model only answers from what's
  actually in the docs and cites page URLs when it does. No RAG,
  no embeddings — the corpus is small enough to stuff into context.
- `workers/chat/` — Cloudflare Worker source, wrangler config, and
  deployment README. Zero external API keys required (Workers AI
  uses a Cloudflare binding). CORS restricted to the docs origin
  plus localhost for local development. Basic input validation
  (message count, per-message size, total payload size).
- `docs-site/scripts/build-chat-context.mjs` — build-time
  generator that concatenates every `.mdx` under
  `content/docs/` and `content/articles/` into
  `workers/chat/src/context.generated.ts`. Strips frontmatter,
  imports, `<Mermaid>`, and `<Cards>` blocks while preserving
  prose, headings, and code fences. Tags each section with its
  public URL so the model can cite pages.
- "Ask AI" link in the main nav, `/chat/` entry in `sitemap.ts`,
  and Open Graph metadata for the chat page.
- **Native Cloudflare rate limiting on the chat Worker.**
  Cloudflare's native WAF rate limiting is now enterprise-only,
  but Workers ship their own built-in rate limiter binding that's
  free and part of the runtime. Configured in `wrangler.toml`
  under `[[unsafe.bindings]]` (binding schema is pre-GA but the
  runtime is stable): 20 requests per 60 seconds per client IP,
  keyed on `CF-Connecting-IP`. Zero external services, no Redis,
  no secrets, no Upstash account. Chat UI renders a friendly
  "you're sending messages too fast" error on 429s.

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
