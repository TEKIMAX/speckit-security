---
description: "Full audit — inline prompts, secrets, stack compliance"
scripts:
  sh: ../../scripts/bash/audit.sh
---

# Post-Implementation Audit

Scan the implementation for prompt / secret / stack violations after
`speckit.implement` completes. Wired into the `after_implement` hook.

## User Input

$ARGUMENTS

## Context

Even with gates at SPECIFY and DESIGN, implementation can introduce
new debt: a developer pastes an inline prompt for a quick test, a
secret ends up committed, the AI gateway gets bypassed for
"just one call". This command catches it.

## Steps

1. **Run the audit script**:

   ```bash
   bash {SCRIPT}
   ```

2. **Scan checks**:

   **Inline prompts**
   - Grep `src/**/*.{ts,tsx,js,jsx,py}` for patterns matching a
     system prompt: `you\s+are\s+a`, `as\s+an\s+ai`,
     `^(system|assistant):`, `<\|system\|>`
   - Any match → fail, list files and line numbers.

   **Committed secrets**
   - Grep for `sk_live_`, `sk_test_`, `PRIVATE_KEY`, `BEGIN RSA`,
     `BEGIN OPENSSH`, `xoxb-`, `ghp_`, `ghs_`, `AKIA[0-9A-Z]{16}`,
     `AIza[0-9A-Za-z-_]{35}`, `ya29\\.[0-9A-Za-z-_]+`
   - Any match → fail hard. Print file but NOT the secret value.

   **.env committed**
   - `git ls-files` includes `.env`, `.env.local`, `.env.production`?
   - Any match → fail.

   **Stack compliance** (AI features only)
   - Model calls bypass the configured AI gateway?
     Look for direct model SDK imports (e.g. `@google/genai`,
     `@anthropic-ai/sdk`, `openai`) without going through a gateway
     client. Patterns are configurable in `tekimax-security-config.yml`.
     - Exception: server-to-gateway code paths in `src/ai/gateway.ts`
       may import the raw SDK.
   - PII encryption middleware not wired for PII fields declared in
     the data contract?
   - Guardrail middleware missing from the request pipeline?

   **Guardrail freshness**
   - Any system prompt edited without a version bump in its
     frontmatter?
   - Any guardrail YAML edited without a version bump?

   **Schema drift**
   - Runtime Zod schemas diverged from the ones declared in the spec?
     (Best effort — compare exported type shapes.)

3. **Produce a report**:

   ```
   ┌─────────────────────────────────────────────────┐
   │ Post-Implementation Audit — <spec-id>           │
   ├─────────────────────────────────────────────────┤
   │ Inline prompts             ✅ clean             │
   │ Committed secrets          ❌ 1 finding         │
   │   src/routes/webhook.ts:42                      │
   │ .env committed             ✅ clean             │
   │ Stack compliance           ⚠  1 warning        │
   │   src/ai/chat.ts imports a model SDK directly  │
   │ Guardrail freshness        ✅ clean             │
   │ Schema drift               ✅ clean             │
   └─────────────────────────────────────────────────┘

   VERDICT: BLOCK (1 critical finding)
   ```

4. **Record the audit** in `.tekimax-security/audit-log.jsonl`
   (append-only).

5. **Fail** (non-zero exit) if any critical finding. Warnings do not
   block but are surfaced.

## Rules

- Never print the actual secret value when flagging one — only the
  file path and line.
- The stack-compliance check has known false positives (gateway client
  code); maintain an allow-list in `tekimax-security-config.yml`.
- Audit log is append-only.
