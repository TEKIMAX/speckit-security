# Add `tekimax-security` to community catalog

Adds the TEKIMAX Secure SDD extension to the community catalog.

## What it does

`tekimax-security` is a security-first extension for Spec Kit. It plugs
into the SDD lifecycle and adds six security gates:

| Gate | Phase | Catches |
|---|---|---|
| Data Contract | SPECIFY | Unvetted sources, unprotected PII, undeclared schemas |
| Threat Model | DESIGN | STRIDE coverage, unmitigated high/critical threats |
| Model Governance | DESIGN | Unpinned versions, missing rollback plans, no eval baselines |
| Guardrails | SPECIFY/IMPLEMENT | Inline prompts, missing input validation / output redaction |
| Red Team | VERIFY | Automated adversarial testing against staging |
| Inline Content Scan | IMPLEMENT | Committed secrets, direct SDK imports |

It provides 7 commands, 5 hooks wired into spec-kit's
`after_specify`/`after_plan`/`before_implement`/`after_implement`/
`before_analyze` phases, and an automated red-team runner that can
execute generated attack scenarios against a staging endpoint.

## Why it's useful

Spec Kit excels at the generic SDD lifecycle but does not enforce
security — threat modeling, AI guardrails, and adversarial testing.
This extension fills that gap without forking or replacing spec-kit.

## Verification

- [x] `extension.yml` validates
- [x] Installs cleanly via `specify extension add --dev`
- [x] All 7 commands register correctly in `.claude/skills/`
- [x] Gate-check and audit scripts tested end-to-end
- [x] `.extensionignore` excludes dev-only files
- [x] Apache 2.0 license included

## Links

- Repo: https://github.com/TEKIMAX/speckit-security
- Docs: https://github.com/TEKIMAX/speckit-security/blob/main/docs/GETTING-STARTED.md
- Changelog: https://github.com/TEKIMAX/speckit-security/blob/main/CHANGELOG.md

## Compatibility

Requires `speckit_version >= 0.1.0`. Tested against 0.6.2.
