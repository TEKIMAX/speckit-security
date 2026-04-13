# Getting Started with TEKIMAX Secure SDD

A 10-minute walkthrough from zero to a feature with passing security gates.

## Prerequisites

- [Spec Kit](https://github.com/github/spec-kit) `>= 0.1.0` installed
  (`uv tool install specify-cli`)
- An AI agent wired up (Claude Code, Copilot, or Gemini CLI)
- Git

## 1. Create a Spec Kit project

```bash
specify init my-secure-app
cd my-secure-app
```

## 2. Install `tekimax-security`

```bash
git clone https://github.com/TEKIMAX/speckit-security.git ../speckit-security
specify extension add --dev ../speckit-security
specify extension list
```

You should see `✓ TEKIMAX Secure SDD (v0.1.0)` with 7 commands and 5 hooks.

## 3. Copy and customize the config

```bash
cp .specify/extensions/tekimax-security/config/tekimax-security-config.template.yml \
   .specify/extensions/tekimax-security/tekimax-security-config.yml
```

Flip `enforcement: warn` → `enforcement: strict` when you're ready to
block on failures.

## 4. Create a feature spec

In your AI agent:

```
/speckit.specify build a user feedback form that uses Gemini to summarize comments
```

The `after_specify` hook will prompt you to run
`speckit.tekimax-security.data-contract`. Say yes. The agent will:

- Read the new spec
- Generate a Zod schema file at `src/schemas/<slug>.ts`
- Append a `## 2. Data Contract` section with sources, PII strategy,
  bias audit, drift thresholds, and retention

## 5. Plan and threat model

```
/speckit.plan
```

The `after_plan` hook will prompt for the STRIDE threat model. It
produces a `## Security / Threat Model` section with a category-by-
category table and maps every threat to a TEKIMAX stack mitigation.

## 6. Wire up guardrails and governance

```
/speckit.tekimax-security.guardrails
/speckit.tekimax-security.model-governance
```

These create `prompts/system/<slug>.md`, `prompts/guardrails/<slug>.yml`,
pin the model version, and write the rollback plan.

## 7. Gate check

```
/speckit.tasks
```

The `before_implement` hook now runs `gate-check`. You'll see:

```
┌─────────────────────────────────────────────────┐
│ Security Gate Check — F-001                     │
├─────────────────────────────────────────────────┤
│ Gate A — Data Contract            ✅ pass       │
│ Gate B — Threat Model             ✅ pass       │
│ Gate C — Model Governance         ✅ pass       │
│ Gate D — Guardrails               ✅ pass       │
│ Gate E — Red Team                 ⚠  skipped    │
│ Gate F — Inline Content Scan      ✅ pass       │
└─────────────────────────────────────────────────┘
VERDICT: PASS
```

## 8. Implement and audit

```
/speckit.implement
```

The `after_implement` hook runs `audit`, scanning for inline prompts,
committed secrets, direct SDK imports, and guardrail drift.

## 9. Red team before shipping

```
/speckit.tekimax-security.red-team
```

Generates 7+ adversarial scenarios in `red-team/RT-001-<slug>.md`.
Execute them manually against staging or pass `--run` with a staging
URL configured.

## 10. Ship

Once Gate E (Red Team) is green with no High/Critical successes,
`gate-check` returns PASS at the `before_ship` phase and you can deploy.

---

**That's the whole flow.** Spec Kit handles the generic SDD lifecycle.
`tekimax-security` enforces the security gates automatically via hooks,
so developers never have to remember to run them.
