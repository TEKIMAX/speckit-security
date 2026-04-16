# Customizing `speckit-security`

`speckit-security` is designed to be stack-agnostic. You can adapt it
to your team's conventions, tools, and policies without forking the
repo. This guide walks through every supported customization point in
v0.3.1.

## What's new in v0.3.1

- `audit.include_globs` and `audit.exclude_paths` extend the polyglot
  default scan coverage.
- `audit.direct_sdk_patterns` extends the built-in list of provider
  SDKs flagged outside the gateway.
- `dep_audit.*` configures Gate G — dependency CVE scanning via
  `osv-scanner` or the project's package manager.
- `--staged-only` and `--json` flags on `audit.sh`,
  `gate-check.sh`, and `dep-audit.sh` make pre-commit hooks and CI
  integrations cheap.
- Allowlist matching is anchored — `src/ai/gateway` no longer
  silently matches `src/ai/gateway-bypass.ts`. Add full file paths
  or directories to the allowlist.

> **Note on extensibility:** v0.2.0 does **not** expose a formal plugin
> system for registering custom commands, gates, or audit checks.
> That's a planned feature for a later release — see
> [Roadmap](#future-plugin-system) below. For now, the customization
> story below covers every real adjustment you can make today.

---

## Contents

1. [Configuration file](#1-configuration-file)
2. [Environment variables](#2-environment-variables)
3. [Template overrides](#3-template-overrides)
4. [Enabling / disabling hooks](#4-enabling--disabling-hooks)
5. [Allowlisting direct SDK imports](#5-allowlisting-direct-sdk-imports)
6. [Adjusting secret and inline-prompt patterns](#6-adjusting-secret-and-inline-prompt-patterns)
7. [Red team runner configuration](#7-red-team-runner-configuration)
8. [Gate log and audit log paths](#8-gate-log-and-audit-log-paths)
9. [Forking the extension](#9-forking-the-extension)
10. [Writing a sibling extension](#10-writing-a-sibling-extension)
11. [Future plugin system](#future-plugin-system)

---

## 1. Configuration file

The primary customization surface is the per-project config file:

```
.specify/extensions/tekimax-security/tekimax-security-config.yml
```

Copy the template after installing the extension:

```bash
cp .specify/extensions/tekimax-security/config/tekimax-security-config.template.yml \
   .specify/extensions/tekimax-security/tekimax-security-config.yml
```

### Enforcement mode

```yaml
enforcement: warn        # warn  = hooks advise but never block
                         # strict = hooks block on any gate failure
```

Start in `warn` while your team gets used to the gates. Flip to
`strict` once gate coverage is stable and the team agrees to it.

### Required spec sections

Tell `gate-check` which sections a feature spec must contain before it
can proceed past SPECIFY.

```yaml
required_sections:
  - "Data Contract"
  - "AI Integration"
  - "Security"
  - "Verification"
```

You can add your own (e.g. `"Data Residency"` for EU-scoped projects)
without modifying any extension code.

### Stack declarations

These are **informational** — `speckit-security` is stack-agnostic, so
these values don't enforce specific vendors. They document what your
team uses so threat models and gate checks can reference the right
tools.

```yaml
stack:
  ai_gateway: <your-ai-gateway>
  guardrails: <your-guardrail-provider>
  pii_encryption: field-level-encryption
  rbac: <your-rbac-provider>
  runtime: <your-runtime>
  schema: zod
  storage: <your-storage>
```

Replace the placeholders with whatever your team uses (or leave them
generic).

---

## 2. Environment variables

The bash scripts read a small set of environment variables that
override values from the config file. Useful for CI, staging runs, and
machine-specific overrides without editing committed files.

| Variable | Used by | Purpose |
|---|---|---|
| `SPECKIT_PHASE` | `gate-check.sh` | Phase label recorded in the gate-log JSONL entry (defaults to `before_implement`) |
| `SPECKIT_TEKIMAX_SECURITY_STAGING_URL` | `red-team-run.sh` | Staging endpoint the red-team runner POSTs scenarios to |
| `SPECKIT_TEKIMAX_SECURITY_MAX_RPS` | `red-team-run.sh` | Rate limit for the red-team runner (default: 10 requests/second) |

Set these in your shell, your CI environment, or via a `.env` file
that your shell loads before running `specify` commands.

```bash
export SPECKIT_TEKIMAX_SECURITY_STAGING_URL="https://staging.example.internal/api/ai"
export SPECKIT_TEKIMAX_SECURITY_MAX_RPS=5
```

**Safety guardrail:** `red-team-run.sh` refuses any URL matching the
regex `(^|[^a-z])prod([^a-z]|$)|production`. Your staging URL must not
contain those tokens.

---

## 3. Template overrides

`speckit-security` ships seven reference templates under
`templates/`. You can override any of them without touching the
extension by using Spec Kit's standard template resolution stack.

Spec Kit resolves templates in this order (first match wins):

1. **Project-local overrides** — `.specify/templates/overrides/`
2. **Installed template packs** — `.specify/templates/packs/<pack-id>/`
3. **Extension-provided templates** — `.specify/extensions/tekimax-security/templates/`
4. **Core templates**

To override, say, the STRIDE threat model template with your own
version:

```bash
mkdir -p .specify/templates/overrides
cp .specify/extensions/tekimax-security/templates/threat-model-stride.md \
   .specify/templates/overrides/threat-model-stride.md
# edit the copy to match your conventions
```

The AI agent will pick up your version on the next
`/speckit.tekimax-security.threat-model` run.

Overridable templates:

- `threat-model-stride.md`
- `data-contract.md`
- `model-governance.md`
- `guardrail.yml`
- `red-team-scenarios.md`
- `eval.yml`
- `security-gate-checklist.md`

---

## 4. Enabling / disabling hooks

The extension registers five phase hooks. Four of them are
interactive (they prompt the user), one is required. You control hook
behavior at two levels:

### Disable a single hook by marking it optional in the installed manifest

Edit `.specify/extensions/tekimax-security/extension.yml` and change
`optional: false` to `optional: true` for the hook you want to make
interactive:

```yaml
hooks:
  before_implement:
    command: "speckit.tekimax-security.gate-check"
    optional: true   # was false — now prompts instead of auto-running
```

> This edits the installed copy in `.specify/`, not the upstream repo.
> Reinstalling the extension (`specify extension remove` +
> `specify extension add`) will reset the change.

### Disable the entire extension for a session

```bash
specify extension disable tekimax-security
# ... do work without the gates running ...
specify extension enable tekimax-security
```

### Remove the extension entirely

```bash
specify extension remove tekimax-security
```

---

## 5. Allowlisting direct SDK imports

The post-implementation audit flags direct model SDK imports outside
your AI gateway layer. If your gateway client needs to import a raw
SDK (which it does), add the file path to the allowlist so the audit
doesn't flag it:

```yaml
audit:
  allowlist:
    stack_direct_sdk:
      - "src/ai/gateway.ts"
      - "src/ai/gateway-test.ts"
```

Wildcards follow glob semantics: `src/ai/gateways/*.ts` allows every
file in a gateway directory.

---

## 6. Adjusting secret and inline-prompt patterns

Both the gate-check and the audit scripts detect committed secrets and
inline prompts using configurable regex patterns. User entries
**extend** the built-in defaults:

```yaml
audit:
  inline_prompt_patterns:
    - "you\\s+are\\s+a"
    - "as\\s+an\\s+ai"
    - "^(system|assistant):"
    - "<\\|system\\|>"
    # Add your own — e.g. a company-specific marker
    - "// PROMPT-START"

  secret_patterns:
    - "sk_live_"
    - "PRIVATE_KEY"
    # Add tokens specific to your stack
    - "my_company_internal_[A-Za-z0-9]{32,}"

  # Polyglot default is TS/JS/Py/Go/Rs/Ruby/Java/Kt/Swift/PHP/Sh/
  # YAML/JSON/TOML/TF/MD. Add extra extensions here if your codebase
  # uses them.
  include_globs:
    - "*.vue"
    - "*.svelte"

  # Extends the default exclude list (node_modules, .git, dist, build,
  # target, .next, out, .venv, venv, coverage, .tekimax-security).
  exclude_paths:
    - "fixtures/"
    - "examples/"

  # Extends the default direct-SDK list (@google/genai,
  # @anthropic-ai/sdk, openai, cohere-ai, @mistralai/mistralai,
  # @aws-sdk/client-bedrock-runtime, replicate, together-ai).
  direct_sdk_patterns:
    - "fireworks-ai"
    - "@groq/groq-sdk"
```

The defaults catch the common cases. Tune them to your codebase.

## 7. Dependency CVE scanning (Gate G)

`dep-audit.sh` runs automatically as Gate G during `gate-check`
and can also be invoked directly
(`/speckit.tekimax-security.dep-audit`).

```yaml
dep_audit:
  enabled: true            # set to false to skip Gate G entirely
  fail_on: high            # low | moderate | high | critical
```

Scanner resolution order (first available wins):

1. **`osv-scanner`** on `PATH` — preferred. Polyglot (npm, pypi,
   cargo, go, maven, gem), no account needed, queries OSV.dev.
   Install once per machine:

   ```bash
   brew install osv-scanner                                        # macOS
   go install github.com/google/osv-scanner/cmd/osv-scanner@v1    # anywhere
   ```

2. `pnpm audit` — if `pnpm-lock.yaml` is present.
3. `npm audit` — if `package-lock.json` is present.
4. `yarn npm audit` — if `yarn.lock` is present (Yarn 2+).
5. Skip cleanly if none are available (exit 0).

## 8. Pre-commit / CI friction knobs

Both `audit.sh` and `gate-check.sh` take two flags that make them
cheap to call in tight feedback loops.

| Flag | Effect |
|---|---|
| `--staged-only` | Scan only files in the git index (added/copied/modified). Typical pre-commit scan touches <5 files. |
| `--json`        | Emit a machine-readable findings object in addition to (or in place of) the human table. Safe for CI log parsing. |

Examples:

```bash
# Pre-commit hook
bash .specify/extensions/tekimax-security/scripts/bash/audit.sh --staged-only

# CI
bash .specify/extensions/tekimax-security/scripts/bash/gate-check.sh \
  ".specify/specs/F-042-checkout.md" --json \
  | tee gate-check-report.json
```

## 9. Allowlist matching rules

The `audit.allowlist.stack_direct_sdk` entries are matched against
file paths using an **anchored** rule:

- `src/ai/gateway`          — matches the exact path,
                              `src/ai/gateway.ts`, or any
                              `src/ai/gateway/…` subdirectory
- `src/ai/gateway-bypass.ts` — is **not** matched by
                              `src/ai/gateway`. List it
                              explicitly or use a directory entry
                              instead.

Use full file paths for single-file allowlists; use directory
entries (`workers/ai`, `src/platform/ai`) to cover a whole area.

---

## 7. Red team runner configuration

```yaml
red_team:
  staging_url: "${SPECKIT_TEKIMAX_SECURITY_STAGING_URL}"
  max_rps: 10
  never_run_against:
    - "prod"
    - "production"
```

- `staging_url` — the endpoint the runner POSTs to. Use an env var
  reference (`${...}`) to keep it out of git.
- `max_rps` — soft rate limit enforced by the runner's sleep loop.
- `never_run_against` — regex tokens that cause the runner to refuse.
  Add any other markers your team uses for production (`live`,
  `main-api`, internal domain names).

---

## 8. Gate log and audit log paths

By default the logs live under `.tekimax-security/` at the project
root. You can redirect them elsewhere:

```yaml
gate_log:
  path: ".tekimax-security/gate-log.jsonl"
  audit_log_path: ".tekimax-security/audit-log.jsonl"
```

Common reasons to move them:

- **Shared volume** — mount a common logs directory across CI jobs
- **Git-tracked compliance trail** — put them under a path that's
  committed (we recommend keeping them gitignored locally and
  shipping them to object storage instead)
- **Multi-tenant projects** — separate logs per service

---

## 9. Forking the extension

If the customization above isn't enough — for example, you need to
add a new command or change the gate-check logic — fork the repo:

```bash
gh repo fork TEKIMAX/speckit-security --clone
cd speckit-security
# make changes
specify extension remove tekimax-security  # if installed
specify extension add --dev .
```

Please also open an issue upstream describing the change you needed.
If it's broadly useful we'll merge it back; if it's company-specific
we can help you design it as a sibling extension instead (see below).

---

## 10. Writing a sibling extension

The most powerful customization path: write your own Spec Kit
extension that coexists with `speckit-security` and uses the same
hook system.

Your sibling extension can:

- Register **its own commands** under a different namespace (e.g.
  `speckit.your-company.custom-check`)
- Hook into the same phase transitions (`before_implement`,
  `after_implement`, etc.) and run before or after our hooks
- Read the same gate-log and audit-log files we write
- Read your company's config from its own config file

See the [Spec Kit Extension Development Guide](https://github.com/github/spec-kit/blob/main/extensions/EXTENSION-DEVELOPMENT-GUIDE.md)
for the extension manifest schema and command format.

---

## Future plugin system

`speckit-security` v0.2.0 does **not** have a formal plugin system for
users to register custom commands, gates, or audit checks that
integrate directly with our extension. This is a deliberate choice for
this release — a premature plugin API locks in the wrong shape before
we understand real usage.

A plugin system is on the roadmap for a later release. Likely shape:

- `plugins/` directory inside `.specify/extensions/tekimax-security/`
- YAML manifests describing custom gates, audit checks, and red-team
  scenario sources
- Bash or script hooks that `gate-check.sh` and `audit.sh` load at
  runtime and run as first-class gates alongside A–F

If you have a concrete use case — you want to add a custom gate, pull
red team scenarios from an external source, or register a
company-specific audit check — **please open an issue** describing
what you need. Real use cases shape the plugin API; we'd rather build
it around validated demand than speculation.

---

## Need something not covered here?

- **Open an issue:** https://github.com/TEKIMAX/speckit-security/issues
- **Security concerns:** security@tekimax.com
- **General questions:** support@tekimax.com
