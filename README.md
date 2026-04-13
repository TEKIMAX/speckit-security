# speckit-security

### Security gates for spec-driven development with AI agents

> A [GitHub Spec Kit](https://github.com/github/spec-kit) extension that
> adds threat modeling (STRIDE), red teaming, AI guardrails, data
> contracts, and model-governance gates to the SDD lifecycle.
> Catches prompt injection, committed secrets, unpinned models, and
> undeclared PII **before code ships**.

**📘 Documentation: [speckit.tekimax.com](https://speckit.tekimax.com)**

[![Spec Kit Extension](https://img.shields.io/badge/spec--kit-extension-7c3aed)](https://github.com/github/spec-kit)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.2.4-green)](CHANGELOG.md)
[![Status](https://img.shields.io/badge/status-alpha-orange)]()
[![Docs](https://img.shields.io/badge/docs-speckit.tekimax.com-7c3aed)](https://speckit.tekimax.com)
[![Tests](https://github.com/TEKIMAX/speckit-security/actions/workflows/test.yml/badge.svg)](https://github.com/TEKIMAX/speckit-security/actions/workflows/test.yml)
[![Made by TEKIMAX](https://img.shields.io/badge/made%20by-TEKIMAX-fbbf24)](https://tekimax.com)

> **Built on top of [GitHub Spec Kit](https://github.com/github/spec-kit).**
> Spec Kit handles the spec-driven development lifecycle; this extension
> layers security gates on top. Install Spec Kit first, then add this
> extension alongside it.

---

## Why this exists

Spec Kit is excellent at turning a specification into code. It does
**not** enforce security: no threat model, no guardrails, no red team,
no model governance. In production AI systems, those are the gaps where
compounding technical debt lives.

`tekimax-security` plugs directly into Spec Kit's extension system and
adds **six security gates** to the SDD lifecycle. Each gate is a
command, backed by a template and a check script, that the AI agent
follows automatically via Spec Kit hooks.

---

## What it adds

| Command | Hook | Catches |
|---|---|---|
| `/speckit.tekimax-security.data-contract` | `after_specify` | Data debt — unvetted sources, unprotected PII, undeclared schemas, hidden bias |
| `/speckit.tekimax-security.threat-model` | `after_plan` | Design-time security flaws via STRIDE |
| `/speckit.tekimax-security.model-governance` | manual (DESIGN) | Model debt — unpinned versions, no rollback, no eval baselines |
| `/speckit.tekimax-security.guardrails` | manual (SPECIFY) | Prompt debt — no input validation, no output redaction, no injection defense |
| `/speckit.tekimax-security.gate-check` | `before_implement` | Blocks implementation until all security sections pass |
| `/speckit.tekimax-security.audit` | `after_implement` | Inline prompts, committed secrets, direct SDK imports, guardrail drift |
| `/speckit.tekimax-security.red-team` | `before_analyze` | Adversarial testing — prompt injection, jailbreak, extraction, auth bypass |
| `/speckit.tekimax-security.install-rules` | manual | Installs a `DEVELOPMENT-RULES.md` into your project — commit hygiene, file structure, DRY, naming, inline docs, unit test rules |

---

## Installation

> Requires [Spec Kit](https://github.com/github/spec-kit) `>= 0.1.0`.

```bash
# 1. Clone the extension
git clone https://github.com/TEKIMAX/speckit-security.git

# 2. Install into your Spec Kit project
cd /path/to/your-project
specify extension add --dev /path/to/speckit-security

# 3. Verify
specify extension list
# → ✓ TEKIMAX Secure SDD (v0.2.2)
#       Security-first extension for Spec Kit
#       Commands: 8 | Hooks: 5 | Status: Enabled
```

---

## Usage

Once installed, the extension's commands become available in your AI
agent (Claude Code, Copilot, Gemini CLI). The typical flow:

```bash
# Phase 1 — SPECIFY
/speckit.specify                          # Spec Kit creates the spec
/speckit.tekimax-security.data-contract   # auto-triggered via hook
/speckit.tekimax-security.guardrails      # for AI features

# Phase 2 — DESIGN
/speckit.plan                             # Spec Kit plans
/speckit.tekimax-security.threat-model    # auto-triggered via hook
/speckit.tekimax-security.model-governance

# Phase 3 — IMPLEMENT
/speckit.tasks                            # Spec Kit breaks down work
/speckit.tekimax-security.gate-check      # before_implement hook — blocks if gates fail
/speckit.implement                        # Spec Kit writes code
/speckit.tekimax-security.audit           # after_implement hook — inline prompt / secret scan

# Phase 4 — VERIFY
/speckit.tekimax-security.red-team        # adversarial scenarios
/speckit.analyze                          # Spec Kit final analysis
```

---

## The Six Security Gates

| Gate | Phase | Enforces |
|---|---|---|
| **A — Data Contract** | SPECIFY | Zod schemas, PII strategy, bias audit, drift thresholds, retention |
| **B — Threat Model** | DESIGN | STRIDE table, no High/Critical unmitigated threats |
| **C — Model Governance** | DESIGN | Version pinning, eval baselines, rollback plan |
| **D — Guardrails** | SPECIFY/DESIGN | Input/output filters, rate limits, cost ceilings |
| **E — Red Team** | VERIFY | Adversarial scenarios, no succeeded High/Critical attacks |
| **F — Inline Content Scan** | IMPLEMENT | No inline prompts, no secrets, no `.env` committed |

Each gate produces a signed entry in `.tekimax-security/gate-log.jsonl`
for compliance audit trails.

---

## Configuration

After installation, copy the template config and customize:

```bash
cp .specify/extensions/tekimax-security/config/tekimax-security-config.template.yml \
   .specify/extensions/tekimax-security/tekimax-security-config.yml
```

Key settings:

```yaml
enforcement: strict        # warn = advise only, strict = hooks block
stack:
  ai_gateway: <your-gateway>
  guardrails: <your-guardrail-provider>
  pii_encryption: field-level-encryption
  rbac: <your-rbac-provider>
```

---

## Reference stack

The extension is **stack-agnostic** — it enforces the *existence* of
security controls, not specific vendor choices. Configure your stack
in `tekimax-security-config.yml`. Common categories you'll need to
fill in:

- **AI gateway** — middleware for all model calls (rate limit, cost ceiling, injection defense)
- **Guardrail layer** — content safety filtering, both directions
- **PII encryption** — field-level encryption / tokenization for personal data
- **RBAC + SSO + audit log** — identity, authorization, attribution
- **Schema validation** — runtime type/shape enforcement at every boundary (default: Zod)
- **Runtime** — where the code executes (edge / server)
- **Monitoring** — drift, latency, cost

Swap any of these in `tekimax-security-config.yml` to match your team's
existing tools. See [docs/CUSTOMIZATION.md](docs/CUSTOMIZATION.md) for
the full customization guide (config file, template overrides, hook
toggling, allowlists, env vars, and more).

> **This is one layer, not the whole program.** `speckit-security`
> is a starting point. It enforces a specific class of checks at
> spec and commit time. It is **not** a replacement for SAST,
> dependency scanning, runtime monitoring, compliance platforms,
> penetration testing, or any of the other security tooling your
> team already uses. Extend it with your own checks via config
> overrides, template overrides, forks, or sibling extensions —
> see the customization guide.

---

## Philosophy

> **Speed − Discipline = Compounding Debt**
>
> **Spec-Driven Discipline × AI Velocity = Sustainable Speed**

Spec Kit gives you velocity. This extension gives you the discipline.
Together, they compound quality instead of debt.

---

## Roadmap

- [x] **v0.2.0** — Automated red team runner (hit staging, record results)
- [x] **v0.2.2** — Rules bind the AI agent at runtime via constitution + context files
- [x] **v0.2.3** — Audit precision fixes (build artifact exclusion, tighter secret patterns)
- [x] **v0.2.4** — Inline-prompt precision (stop flagging legal prose)
- [ ] Formal plugin system for custom gates and audit checks
- [ ] GitHub Actions workflow template for running gate-check in CI
- [ ] Integration with DeepTeam for automated adversarial eval
- [ ] Public community catalog submission

---

## Security

Found a vulnerability? Please report it privately to
**security@tekimax.com** — see [SECURITY.md](SECURITY.md) for the
responsible disclosure policy. Please do **not** open a public issue
for security reports.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). External contributions are
welcome; we use an issue-first workflow so we can discuss direction
before you invest in a PR. All contributors agree to the
[Code of Conduct](CODE_OF_CONDUCT.md).

## License

Apache 2.0 — see [LICENSE](LICENSE).

---

**Made with care by [Christian Kaman](https://tekimax.com) at [TEKIMAX](https://tekimax.com).**
*For AI builders who care about shipping secure products fast.*

Questions, feedback, or bugs: [open an issue](https://github.com/TEKIMAX/speckit-security/issues)
or email **support@tekimax.com**.
