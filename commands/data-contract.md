---
description: "Declare the data contract (sources, schemas, PII, bias, drift)"
---

# Data Contract

Declare and validate the data contract for the active feature spec.
This catches **Data Debt** at the SPECIFY phase — unvetted sources,
unprotected PII, undeclared schemas, and hidden bias.

## User Input

$ARGUMENTS

## Context

Spec Kit just produced a spec. Before it moves to DESIGN, we need an
explicit, machine-readable data contract. No data handling exists unless
it's declared here.

## Steps

1. **Read the active spec** and identify every data input and output
   referenced in the user stories, acceptance criteria, and AI integration
   section.

2. **For each data source**, produce:
   - **Name and origin** (user form, external API, DB table, model output)
   - **Trust classification** — `vetted` (we control it) or `unvetted`
     (user or third party)
   - **Schema** — a Zod schema in `src/schemas/<feature>.ts`. Write the
     actual schema code, not a description.
   - **PII fields** — which fields contain personal data. For each,
     name the encryption strategy: `field-encrypt`, `tokenize`, `hash`,
     or `omit`. The concrete provider (field-level encryption service)
     is configured in `tekimax-security-config.yml → stack.pii_encryption`.
   - **Bias risk** — what demographic/segment biases could this data
     introduce? If model training or filtering is involved, what
     segments must be represented for fairness?
   - **Drift thresholds** — what constitutes acceptable deviation from
     baseline? How is drift detected (real-time monitoring, scheduled eval)?
   - **Retention and deletion** — how long is the data kept, who can
     delete it, where does `DELETE` propagate?

3. **Generate the Zod schema file**. For each source, write a Zod
   schema with:
   - Strict types (no `z.any()`)
   - Branded types for PII (`z.string().brand<"Email">()`)
   - Max length constraints
   - Refinements for domain rules
   - A parsed inference type (`export type Foo = z.infer<typeof FooSchema>`)

4. **Append the data contract section** to the spec under `## 2. Data Contract`:

   ```markdown
   ## 2. Data Contract

   ### Sources

   | Name | Origin | Trust | Schema | PII? |
   |------|--------|-------|--------|------|
   | user_profile | auth provider /me | vetted | `UserProfileSchema` | email, name |
   ...

   ### Schemas

   All schemas live in `src/schemas/<feature>.ts` (Zod).

   ### PII Handling

   | Field | Strategy | Tool |
   |-------|----------|------|
   | email | tokenize | <configured provider> |
   | full_name | field-encrypt | <configured provider> |

   ### Bias Audit

   - Segments that must be represented: ...
   - Known bias risks: ...
   - Mitigation: ...

   ### Drift Monitoring

   - Baseline: ...
   - Threshold: ...
   - Detection: ...

   ### Retention

   - TTL: ...
   - Deletion path: ...
   ```

5. **Verify every AI prompt context uses encrypted/tokenized fields**
   for PII. If the spec's system prompt receives raw PII, flag it as
   a blocker and refuse to pass until the spec is updated.

6. **Summarize**: number of sources, schemas generated, PII fields
   protected, bias risks flagged.

## Rules

- No `z.any()` in any generated schema.
- Every PII field must have a named encryption strategy — no "TBD".
- Bias audit may be marked `[DEFERRED: v2]` but must then appear in
  the spec's deferred section with a remediation date.
- The Zod schema file is the source of truth — the runtime must import
  from it, never redeclare.
