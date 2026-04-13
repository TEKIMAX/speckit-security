---
description: "Verify all security gates pass before implement/ship"
scripts:
  sh: ../../scripts/bash/gate-check.sh
---

# Security Gate Check

Run all TEKIMAX security gates against the active feature and block
progression if any gate fails.

## User Input

$ARGUMENTS

## Context

This command is wired into the `before_implement` hook and MUST pass
before any code is written or deployed. It is the "Ready, Aim, Fire"
enforcement point.

## Steps

1. **Identify the active spec** from `$ARGUMENTS` or the most recent
   spec in `.specify/specs/`.

2. **Run the gate-check script** (see frontmatter `scripts.sh`):

   ```bash
   bash {SCRIPT} <spec-path>
   ```

   The script validates:

   **Gate A — Data Contract**
   - Spec contains `## 2. Data Contract` with sources, schemas, PII
     strategy, bias audit, drift thresholds, retention
   - A Zod schema file exists at `src/schemas/<slug>.ts`
   - No `z.any()` in the schema file
   - PII fields reference a named encryption strategy (field-level
     encrypt / tokenize / hash / omit) — provider is configurable

   **Gate B — Threat Model**
   - Spec contains `## Security / Threat Model`
   - STRIDE table has at least one entry per category (or explicit N/A)
   - No `[UNMITIGATED]` threats at severity High or Critical
   - All mitigations reference a real stack tool

   **Gate C — Model Governance** (if AI feature)
   - Spec contains model provider, name, pinned version
   - No "latest" / unpinned tags
   - Eval baselines present with numeric thresholds
   - Rollback plan has trigger, target, owner, time budget
   - `.tekimax-security/stack.yml` has the pinned version

   **Gate D — Guardrails** (if AI feature)
   - `prompts/guardrails/<slug>.yml` exists and is valid
   - `prompts/system/<slug>.md` exists with non-placeholder prompt body
   - Input has `blocked_patterns`, output has `redact_patterns`
   - Rate limit and cost ceiling are numeric
   - Spec references the configured AI gateway as the router for every model call

   **Gate E — Red Team** (required before VERIFY → OPERATE)
   - `red-team/RT-XXX-<slug>.md` exists
   - At least 3 scenarios per applicable category
   - No succeeded attacks at severity High or Critical without a
     documented remediation

   **Gate F — Inline Content Scan**
   - No inline system prompts in `src/**/*.{ts,tsx,js,jsx,py}`
     (regex: `you\s+are\s+a|as\s+an\s+ai|system\s*prompt`)
   - No committed secrets (`sk_live_`, `PRIVATE_KEY`, `BEGIN RSA`)
   - No `.env` committed to git

3. **Produce a report**:

   ```
   ┌─────────────────────────────────────────────────┐
   │ Security Gate Check — <spec-id>                 │
   ├─────────────────────────────────────────────────┤
   │ Gate A — Data Contract            ✅ pass       │
   │ Gate B — Threat Model             ✅ pass       │
   │ Gate C — Model Governance         ❌ fail       │
   │   - model version not pinned                    │
   │ Gate D — Guardrails               ✅ pass       │
   │ Gate E — Red Team                 ⚠  skipped    │
   │ Gate F — Inline Content Scan      ✅ pass       │
   └─────────────────────────────────────────────────┘

   VERDICT: BLOCK
   ```

4. **If any gate fails**, exit non-zero with the list of failures.
   The `before_implement` hook will prevent implementation from
   proceeding.

5. **If all gates pass**, record a signed entry in
   `.tekimax-security/gate-log.jsonl`:

   ```jsonl
   {"spec":"F-001","phase":"before_implement","verdict":"PASS","ts":"2026-04-12T23:59:00Z","user":"<git user>","gates":{"A":"pass","B":"pass","C":"pass","D":"pass","E":"skipped","F":"pass"}}
   ```

## Rules

- Never emit `PASS` if any required gate is skipped.
- Never silently lower a fail to a warn — the `enforcement` setting
  in config controls only whether the hook blocks, not whether the
  verdict is truthful.
- Gate-log is append-only. Never rewrite prior entries.
