# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

`speckit-security` is a **third-party extension for [GitHub Spec Kit](https://github.com/github/spec-kit)** that adds seven security gates (data contract, threat model, model governance, guardrails, red team, inline-content scan, dependency CVEs) to the spec-driven-development lifecycle. It is shipped as a directory tree that `specify extension add` copies into a consuming project under `.specify/extensions/tekimax-security/` — there is no compile step and no JS/TS runtime for the extension itself. The execution surface is **POSIX bash + python3**.

The repo also contains two adjacent, self-contained sub-projects: `docs-site/` (Next.js + Fumadocs documentation site) and `workers/chat/` (Cloudflare Worker for the docs chat). They share the parent only for proximity — neither is wired into the extension's runtime path.

## Commands

### Tests (extension)

```bash
bash tests/run.sh                       # all suites
bash tests/run.sh gate-check            # one suite (gate-check or audit)
bash tests/gate-check/pass-clean.sh     # one test
```

Tests are zero-dependency POSIX bash. No package manager, no test framework, no language runtime beyond bash + python3 + standard unix tools (`grep`, `sed`). Every test creates a temp fixture via `lib/fixture.sh`, runs a script from `scripts/bash/`, and asserts against captured output with helpers from `lib/assert.sh`. CI runs the same `tests/run.sh` on both `ubuntu-latest` and `macos-latest`.

### Lint (extension)

```bash
find scripts/bash tests -name "*.sh" -type f -print0 \
  | xargs -0 shellcheck --severity=warning \
    --exclude=SC1083,SC1091,SC2034,SC2086,SC2154,SC2155
```

The `--exclude` list is load-bearing — CI uses the same set. Don't trim it without checking `.github/workflows/test.yml`.

### Smoke-test the extension end-to-end against a real Spec Kit project

```bash
specify init /tmp/dev-test --ai claude --no-git
cd /tmp/dev-test
specify extension add --dev /path/to/speckit-security

# To pick up local changes, you must reinstall — there's no hot reload:
specify extension remove tekimax-security
specify extension add --dev /path/to/speckit-security

# Run the scripts directly against a fixture spec:
bash .specify/extensions/tekimax-security/scripts/bash/gate-check.sh \
  .specify/specs/<some-spec>.md
bash .specify/extensions/tekimax-security/scripts/bash/audit.sh
```

### Docs site (`docs-site/`)

```bash
cd docs-site
pnpm install        # postinstall runs fumadocs-mdx
pnpm dev            # next dev
pnpm build          # next build
pnpm types:check    # fumadocs-mdx && next typegen && tsc --noEmit
pnpm lint           # eslint
```

### Chat worker (`workers/chat/`)

```bash
cd workers/chat
pnpm dev            # wrangler dev
pnpm publish        # wrangler deploy
pnpm typecheck      # tsc --noEmit
pnpm build:context  # regenerates docs corpus from docs-site/
```

## Architecture

### How a command actually runs

Each slash command flows through four layers:

1. **`extension.yml`** — registers the command (`speckit.tekimax-security.<name>`), declares which hook (if any) auto-triggers it (`after_specify`, `after_plan`, `before_implement`, `after_implement`, `before_analyze`), and points at the command markdown file.
2. **`commands/<name>.md`** — spec-kit frontmatter file. Has a `scripts.sh:` field pointing at the bash script that does the real work. The body is the AI-agent prompt that wraps the script invocation.
3. **`scripts/bash/<name>.sh`** — does the actual security check. Reads optional user config from `.specify/extensions/tekimax-security/tekimax-security-config.yml`, falls back to built-in defaults from `scripts/bash/lib/defaults.sh`, writes findings to stdout and an append-only JSONL audit trail at `.tekimax-security/gate-log.jsonl`.
4. **`templates/<artifact>.md`** — the structured artifact the command writes into the user's spec (threat-model-stride.md, guardrail.yml, etc.).

A new command requires all four pieces plus a test under `tests/<command>/` and a CHANGELOG entry — see `docs/DEVELOPMENT-RULES.md §2`.

### Shared bash helpers in `scripts/bash/lib/`

- `defaults.sh` — single source of truth for built-in pattern sets (`DEFAULT_INLINE_PROMPT_RE`, `DEFAULT_SECRET_RE`, etc.) and for `require_inside_project`, a Python-backed path-traversal guard. Every script that takes a user-supplied path must call this guard before reading.
- `config.sh` — `config_list <yaml-path> <key>` reads list-valued config keys. All list-valued keys are **additive**: user entries *extend* defaults (built-ins are never replaced silently). This is an intentional design contract — preserve it.

User-config arrays are read with the `${arr[@]+"${arr[@]}"}` idiom because macOS ships bash 3.2 by default, where `${arr[@]}` on an empty array fails under `set -u`. This is everywhere — don't "simplify" it.

### Gate F is polyglot, Gate A is TypeScript-opinionated

Gate A (Data Contract) looks for `src/schemas/<slug>.ts` (Zod). Gate F (inline-content scan) scans TS/JS/Py/Go/Rust/Ruby/Java/Kotlin/Swift/PHP/Sh/YAML/JSON/TOML/Terraform/Markdown by default. When extending Gate F support, add the extension to the default `audit.include_globs` in `defaults.sh` rather than hardcoding in `audit.sh` / `gate-check.sh`.

### Audit-log invariants (security-critical)

`.tekimax-security/gate-log.jsonl` is **append-only with a SHA-256 hash chain** for tamper detection. JSONL writes go through a Python helper to prevent injection via crafted spec fields. Never rewrite or truncate prior entries; never bypass the hash chain when adding a new field. The open-source edition gives an audit *trail*, not signed audit *integrity* — keep that distinction in docs.

### Hard rules from `docs/DEVELOPMENT-RULES.md`

These are enforced in review:

- **Commit messages**: imperative subject under 72 chars, prefix with the area (`gate-check:`, `audit:`, `scripts:`, `templates:`, `docs:`). Never include AI tool attribution, internal review history (e.g. "strip X references"), or process commentary. Write the *why* in the body.
- **No `Co-Authored-By` trailer** for AI models — this project has not adopted that convention.
- **One bash script per command**, in `scripts/bash/` (never at the repo root, never inlined into command markdown).
- **POSIX-portable bash**: use `[[:space:]]` (not `\s`) in `grep -E`; functions ending with a `[` test under `set -e` terminate silently — use `case` or explicit `return 0`; gate empty-array expansions with `${arr[@]+"${arr[@]}"}` for macOS bash 3.2.
- **Tests with every bug fix.** New gates land with a pass case and a block case. New bash helpers land with a test per distinct input shape.
- **CHANGELOG `## [Unreleased]`** is updated in the same commit as user-visible changes.

### What gets shipped vs. what stays in the repo

`.extensionignore` controls what `specify extension add` copies into a user's project. `tests/`, `CONTRIBUTING.md`, `docs/draft/`, `.github/`, and `.git/` are deliberately excluded — the installed extension is the minimal runtime surface. When adding a dev-only file or directory, update `.extensionignore` so it doesn't ship.

## Sub-projects (not part of the extension runtime)

- `docs-site/` — Next.js 16 + Fumadocs (Tailwind, MDX). Deployed via `.github/workflows/docs-deploy.yml`. Source for `speckit.tekimax.com`.
- `workers/chat/` — Cloudflare Worker (Wrangler) serving the docs chat (Llama 3.3 70B on Workers AI). The grounding corpus is generated from `docs-site/` content by `docs-site/scripts/build-chat-context.mjs` (also runnable from the worker as `pnpm build:context`). Cloudflare native rate limiter, 20 req / 60s per IP.
- `catalog/` — submission artifacts for the Spec Kit community catalog (`entry.json`, `PR-BODY.md`). Bumped in lockstep with `extension.yml → version`.
