---
description: "Generate input/output guardrail config for AI features"
---

# Guardrails

Catch **Prompt Debt** at SPECIFY. Generate a versioned guardrail config
that sits on the AI Gateway and filters both directions.

## User Input

$ARGUMENTS

## Context

No AI feature ships without input validation, output redaction, and
prompt-injection defense. This command produces the `.yml` config the
runtime loads at startup (consumed by your AI gateway middleware), and
the `.md` file that documents intent.

## Steps

1. **Read the active spec**. If no AI integration, exit with
   "no guardrails required".

2. **Identify the feature slug** from the spec file name.

3. **Generate** `prompts/guardrails/<slug>.yml` with these mandatory
   sections:

   ```yaml
   slug: <slug>
   spec: <spec-id>
   version: 1.0.0
   owner: <from spec>
   updated: <date>

   input:
     max_length: <reasoned from spec, default 4000>
     blocked_patterns:
       - "ignore previous instructions"
       - "system prompt"
       - "reveal your instructions"
       - "you are now"
       - "disregard"
       # Add feature-specific patterns inferred from the spec
     allowed_languages: [en]
     strip_html: true
     reject_on_injection: true

   output:
     max_length: <reasoned from spec>
     redact_patterns:
       - pattern: "\\b\\d{3}-\\d{2}-\\d{4}\\b"  # SSN
         replace: "[REDACTED-SSN]"
       - pattern: "\\b\\d{16}\\b"                # card numbers
         replace: "[REDACTED-CARD]"
       - pattern: "\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\\b"
         replace: "[REDACTED-EMAIL]"
       # Add PII patterns from the data contract
     banned_phrases: []
     require_citations: <true if spec says grounded>

   limits:
     rate_per_user_per_minute: <from spec non-functional>
     cost_ceiling_usd_per_day: <from spec non-functional>

   escalation:
     on_blocked_input: log_and_reject
     on_redacted_output: log_and_return
     on_cost_exceeded: throttle
   ```

4. **Generate** `prompts/system/<slug>.md` with frontmatter, intent,
   constraints, and the full system prompt text (never leave blank):

   ```markdown
   # System Prompt — <slug>

   **Spec:** <id>
   **Owner:** <name>
   **Version:** 1.0.0
   **Model:** <provider/model/version>
   **Updated:** <date>

   ## Intent
   <one-line purpose>

   ## Constraints
   - MUST: <from spec>
   - MUST NOT: <from spec>
   - Output format: <from spec>

   ## System Prompt (v1.0.0)

   ```
   <full system prompt text — never placeholder>
   ```
   ```

5. **Wire the guardrail into the spec**. Add to `## 3. AI Integration`:

   ```markdown
   - System prompt: `prompts/system/<slug>.md` (v1.0.0)
   - Guardrail: `prompts/guardrails/<slug>.yml` (v1.0.0)
   - Gateway: configured AI gateway (loads guardrail on request/response)
   - Filter: configured guardrail layer (layered content safety)
   ```

6. **Verify no inline prompt strings** exist anywhere in `src/`.
   If found, fail and list the files.

7. **Summarize**: files created, blocked patterns, PII redactions,
   limits set.

## Rules

- Never leave the system prompt body empty or as a placeholder.
- Never use a `.txt` or inline string for the prompt — always markdown
  file with frontmatter.
- `rate_per_user_per_minute` and `cost_ceiling_usd_per_day` must be
  numbers — no "TBD".
- If the runtime does not route through the configured AI gateway,
  fail and block the command.
