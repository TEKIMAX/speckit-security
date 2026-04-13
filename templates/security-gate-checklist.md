# Security Gate — {{SPEC_ID}}

**Reviewer:**
**Date:**
**Phase transition:** {{FROM}} → {{TO}}

---

## Gate A — Data Contract
- [ ] `## 2. Data Contract` section present and complete
- [ ] Zod schema file at `src/schemas/{{FEATURE_SLUG}}.ts` (no `z.any()`)
- [ ] Every PII field has a named encryption strategy (field-encrypt / tokenize / hash / omit)
- [ ] Bias audit done or explicitly deferred
- [ ] Drift thresholds numeric
- [ ] Retention policy documented

## Gate B — Threat Model
- [ ] `## Security / Threat Model` section present
- [ ] STRIDE covers all six categories (or explicit N/A)
- [ ] No High/Critical unmitigated threats
- [ ] Every mitigation references a real stack tool

## Gate C — Model Governance (AI features only)
- [ ] Provider + model + version pinned (no "latest")
- [ ] Eval baselines have numeric thresholds
- [ ] Rollback plan: trigger + target + owner + time budget

## Gate D — Guardrails (AI features only)
- [ ] `prompts/guardrails/{{FEATURE_SLUG}}.yml` exists and valid
- [ ] `prompts/system/{{FEATURE_SLUG}}.md` has non-placeholder prompt
- [ ] Input blocked_patterns + output redact_patterns set
- [ ] Rate limit and cost ceiling numeric
- [ ] AI gateway confirmed as router for every model call

## Gate E — Red Team (VERIFY → OPERATE only)
- [ ] `red-team/RT-XXX-{{FEATURE_SLUG}}.md` exists
- [ ] At least 3 scenarios per applicable category
- [ ] No succeeded High/Critical attacks unremediated

## Gate F — Inline Content Scan
- [ ] No inline system prompts in `src/`
- [ ] No committed secrets
- [ ] `.env` not committed

---

**Verdict:** PASS / BLOCK
**Signed by:**
**Notes:**
