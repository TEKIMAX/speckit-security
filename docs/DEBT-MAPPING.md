# AI Technical Debt — Mapping to Gates

The AI technical debt taxonomy defines four debt categories. Each maps
to a gate in `tekimax-security` where it gets caught — or prevented
entirely.

| Debt category | Caught at | Gate | Command |
|---|---|---|---|
| **Data debt** — unvetted sources, undeclared schemas, unprotected PII, bias, drift | SPECIFY | A — Data Contract | `data-contract` |
| **Model debt** — unpinned versions, no eval, no rollback, no attack surface | DESIGN | C — Model Governance | `model-governance` |
| **Prompt debt** — inline prompts, no guardrails, injection vulnerabilities, no redaction | SPECIFY → IMPLEMENT | D — Guardrails + F — Inline Scan | `guardrails`, `audit` |
| **Organizational debt** — no ownership, no governance, no red team, unknown costs | DESIGN → VERIFY | B — Threat Model + E — Red Team | `threat-model`, `red-team` |

---

## Strategic vs reckless debt

This extension doesn't eliminate all technical debt — it makes debt
**strategic by default**.

**Strategic debt** in a gated SDD flow:
- Spec explicitly marks a section `[DEFERRED: v2]` with a remediation plan
- Gate check notes the deferral, risk level, and timeline
- OPERATE phase includes monitoring for the known gap
- PR description references the linked follow-up ticket

**Reckless debt is structurally impossible** when followed correctly:
- Can't implement without a spec (Spec Kit)
- Can't implement without passing gates (this extension)
- Can't deploy without verification and red team (gate E)
- Every deferral is documented in the spec itself (no hidden shortcuts)

---

## Reference

- [Spec Kit](https://github.com/github/spec-kit)
- Martin Fowler — [Spec-Driven Development with Kiro, spec-kit, Tessl](https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html)
