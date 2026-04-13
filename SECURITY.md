# Security Policy

## Reporting a vulnerability

**Please do not report security vulnerabilities through public GitHub
issues, discussions, or pull requests.**

If you believe you have found a security vulnerability in
`tekimax-security` — whether in the extension itself, its gate-check
logic, the red-team runner, or any shipped template — please report it
privately by email:

**security@tekimax.com**

Please include:

- A description of the issue and its impact
- Steps to reproduce (or a proof-of-concept)
- The version of `tekimax-security` affected (run `specify extension info tekimax-security`)
- Your environment: OS, spec-kit version, AI agent used
- Whether you'd like public credit in the advisory after remediation

## What to expect

- **Acknowledgment within 48 hours** of your report (business days).
- **Initial triage within 5 business days** — we'll tell you whether
  the report is accepted, the severity rating we've assigned, and a
  rough remediation timeline.
- **Fix and coordinated disclosure**: we aim to release a patched
  version within 30 days for High and Critical severity issues, and
  within 90 days for Medium and Low.
- **Credit**: if you'd like, we'll credit you in the release notes and
  CHANGELOG under a "Security" section. Anonymous reports are also
  welcome.

## Scope

**In scope**:

- `tekimax-security` extension code (commands, scripts, templates, manifest)
- The gate-check and audit bash scripts (`scripts/bash/*.sh`)
- The automated red-team runner (`red-team-run.sh`)
- Guardrail and threat-model templates that could produce unsafe outputs
- Integration points with spec-kit's hook system
- Documentation that could mislead users into insecure configurations

**Out of scope**:

- Vulnerabilities in [github/spec-kit](https://github.com/github/spec-kit) itself
  — please report those to the spec-kit maintainers
- Vulnerabilities in third-party tools referenced in our templates
  (AI gateways, RBAC providers, PII encryption services, etc.) —
  please report to those vendors directly
- Issues caused by misconfiguration where the documentation clearly
  warns against the insecure configuration
- Theoretical issues without demonstrated exploitability
- Rate-limit bypasses against systems you do not own

## Our commitments

- We will not take legal action against researchers who follow this
  policy in good faith.
- We will not share your personal information without your consent.
- We will keep you informed during the investigation and remediation.

## Responsible disclosure timeline

We follow a 90-day disclosure timeline by default:

| Day | Event |
|---|---|
| 0 | Vulnerability reported to security@tekimax.com |
| 2 | Acknowledgment sent |
| 5 | Initial triage complete |
| 30 | Target fix date for High / Critical |
| 90 | Target public disclosure date |

If you need an extension or believe faster disclosure is warranted,
let us know in your report.

## PGP

If your report contains sensitive information, request our PGP key in
your first email and we'll respond with it.

---

Thank you for helping keep `tekimax-security` and its users secure.

— The TEKIMAX team · support@tekimax.com · https://tekimax.com
