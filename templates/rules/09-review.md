## 9. Review checklist

Before opening a PR, confirm:

- [ ] Commit messages follow §1 — no internal context leaks, imperative mood, under 72 chars
- [ ] New files live in the right directory per §2
- [ ] No duplicated code across scripts, templates, or docs per §3
- [ ] Files are under the hard ceiling per §4
- [ ] Names follow the conventions in §5
- [ ] Inline comments explain *why*, not *what* per §6
- [ ] New behavior has at least one test per §7
- [ ] Bug fixes land with a regression test
- [ ] CHANGELOG `## [Unreleased]` updated
- [ ] `tests/run.sh` (or project equivalent) passes locally
- [ ] User-visible documentation updated if behavior changed

---

## Enforcement

These rules are enforced by:

1. **Human review** — reviewers reference this doc in comments
2. **CI test suite** — all tests pass on every PR
3. **Spec-kit post-implementation audit** (if using `speckit-security`)
   catches inline prompts, committed secrets, and direct SDK imports

Violations **block** PR merge.

Ask for guidance early if you're unsure whether a change complies —
it's cheaper than rewriting after review.

---

*Installed by `/speckit.tekimax-security.install-rules` · Customize freely for your project.*
