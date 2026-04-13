---
description: "Generate a STRIDE threat model for the current spec"
---

# Threat Model (STRIDE)

Generate a STRIDE threat model for the feature currently being specified
and append it to the active spec file under `## Security / Threat Model`.

## User Input

$ARGUMENTS

## Context

You are operating inside a Spec Kit project augmented with the
**TEKIMAX Secure SDD** extension. A feature spec already exists (created
by `/speckit.specify`). Your job is to produce a rigorous, feature-specific
threat model — not a generic checklist.

## Steps

1. **Locate the active spec** — read the most recently edited file in
   `.specify/specs/` or the file referenced by `$ARGUMENTS`.

2. **Extract the attack surface from the spec**:
   - Entry points (API routes, UI forms, webhooks, agent inputs)
   - Trust boundaries (user ↔ system, system ↔ third party, tenant ↔ tenant)
   - Data flows (what crosses each boundary, what's encrypted)
   - AI surfaces (prompt inputs, model outputs, tool calls)

3. **Run STRIDE against each entry point.** For each of the six
   categories, produce at least one concrete, feature-specific threat.
   Do NOT write generic threats like "user could send bad input" —
   reference the exact field, route, or tool the spec defines.

   | Category | Focus |
   |---|---|
   | **S**poofing | Identity / auth bypass — RBAC, token theft, session hijack |
   | **T**ampering | Request / data modification in transit or at rest |
   | **R**epudiation | Missing audit trail, unattributable actions |
   | **I**nformation Disclosure | PII leakage, prompt injection exfiltration, error verbosity |
   | **D**enial of Service | Rate limit bypass, cost exhaustion, model token bombs |
   | **E**levation of Privilege | Tenant escape, role escalation, tool misuse |

4. **Score each threat** with severity (Critical / High / Medium / Low)
   and likelihood (High / Medium / Low). Compute a risk tier.

5. **Map each threat to a mitigation** drawn from the configured
   stack (read `tekimax-security-config.yml → stack`). Example control
   categories to draw from:
   - PII encryption — field-level encryption / tokenization
   - AI gateway — rate limit, cost ceiling, prompt injection defense
   - Guardrail layer — input/output content safety
   - RBAC / SSO / audit log
   - Schema validation at every boundary (Zod)
   - Edge DDoS / WAF

   If a threat has **no available mitigation** in the stack, flag it as
   `[UNMITIGATED]` and add it to the spec's `## 8. Deferred / Debt`
   section with a remediation plan.

6. **Write the threat model** to the spec file under a new section:

   ```markdown
   ## Security / Threat Model

   **Generated:** <date>
   **Scope:** <feature name>
   **Attack surface:** <brief summary>

   ### Threats

   | ID | Category | Threat | Severity | Likelihood | Mitigation | Status |
   |----|----------|--------|----------|------------|------------|--------|
   | T1 | Spoofing | ... | High | Medium | MFA + short-lived tokens via RBAC provider | ✅ mitigated |
   ...

   ### Unmitigated Risks

   - ...

   ### Notes

   - ...
   ```

7. **Summarize** in the chat: number of threats, number unmitigated,
   overall risk posture, and which gates must be updated.

## Rules

- Every threat must reference a specific spec element — no generic
  boilerplate.
- Every mitigation must reference a specific tool in the stack.
- `[UNMITIGATED]` threats MUST be written into the spec's deferred
  section — never silently dropped.
- If the spec has no AI integration, skip prompt-injection threats but
  still run the other STRIDE categories.
