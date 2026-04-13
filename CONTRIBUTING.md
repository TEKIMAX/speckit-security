# Contributing to `tekimax-security`

Thanks for your interest in contributing. This project is maintained
by TEKIMAX and we welcome external contributions from the community.

We use an **issue-first workflow**: before you invest time in a pull
request, open an issue so we can discuss scope, approach, and
acceptance criteria. This saves everyone rework and gets your
contribution merged faster.

## Code of Conduct

By participating in this project, you agree to abide by the
[Code of Conduct](CODE_OF_CONDUCT.md). Be kind, be precise, be helpful.

## Development rules

Read [docs/DEVELOPMENT-RULES.md](docs/DEVELOPMENT-RULES.md) before
opening a PR. It covers:

- Commit message rules — no internal context leaks, imperative mood
- File structure — where hooks, scripts, templates, tests, docs live
- Code organization — DRY, helper extraction when functions get complex
- File length and complexity targets
- Naming conventions
- Inline documentation (explain *why*, not *what*)
- Unit test rules — add a regression test with every bug fix
- Readability and maintainability principles
- Review checklist

PRs that violate these rules will be asked to update before merge.

## Running tests

Zero-dependency shell tests live in [`tests/`](tests/). Run them with:

```bash
bash tests/run.sh                 # all tests
bash tests/run.sh gate-check      # one suite
bash tests/gate-check/pass-clean.sh  # one test
```

Every bug fix should land with a regression test. See
[tests/README.md](tests/README.md) for the full testing guide and a
copy-paste template for new tests.

## Ways to contribute

- **Report bugs** — open an issue with reproduction steps
- **Suggest features** — open a discussion or issue tagged `enhancement`
- **Improve templates** — the spec, guardrail, threat-model, and
  red-team templates are the heart of the extension. PRs that sharpen
  them are very welcome.
- **Add tests** — the bash scripts need coverage for edge cases
- **Improve docs** — `docs/GETTING-STARTED.md` and the command files
  in `commands/` are our most-read content
- **Port templates to other stacks** — the extension is stack-agnostic
  by design; provider choices live in `tekimax-security-config.yml`.
  Contributions of common stack presets are welcome as long as they
  stay opt-in via config.

## What we will NOT merge (without discussion)

- Changes that lower the strictness of any gate
- Changes that remove required spec sections from templates
- New commands that silently bypass existing gates
- Dependencies that require a paid service without a free alternative
- Anything that weakens prompt-injection defenses

## Development setup

1. Fork and clone:
   ```bash
   gh repo fork TEKIMAX/speckit-security --clone
   cd speckit-security
   ```

2. Install [Spec Kit](https://github.com/github/spec-kit):
   ```bash
   uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
   ```

3. Create a throwaway test project:
   ```bash
   specify init /tmp/dev-test --ai claude --no-git
   cd /tmp/dev-test
   specify extension add --dev /path/to/your/speckit-security
   ```

4. Make changes, then **reinstall the extension** to pick them up:
   ```bash
   specify extension remove tekimax-security
   specify extension add --dev /path/to/your/speckit-security
   ```

## Testing your changes

Before opening a PR, run through the smoke test:

```bash
cd /tmp/dev-test

# Should all work without errors
specify extension list
specify extension info tekimax-security

# Gate-check script against a fake spec (fails if your changes broke it)
bash .specify/extensions/tekimax-security/scripts/bash/gate-check.sh \
  .specify/specs/<some-spec>.md

# Audit script
bash .specify/extensions/tekimax-security/scripts/bash/audit.sh
```

For bash script changes, test on **both macOS and Linux** where
possible — POSIX portability matters. Known gotchas:

- Use `[[:space:]]` not `\s` in `grep -E`
- Functions ending with a `[` test under `set -e` will terminate the
  script silently — use `case` or explicit `return 0`
- Empty arrays under `set -u` fail `${#arr[@]}` on macOS bash 3.2 —
  use counters instead

## Commit and PR hygiene

- Keep commits focused — one logical change per commit
- Write the commit message like a mini PR description: what, why, how-verified
- Reference the issue: `Fixes #123` or `Relates to #123`
- Run through the smoke test before pushing
- Update `CHANGELOG.md` under `## [Unreleased]` with a one-line entry
- Update docs if behavior changed

## Release process (maintainers only)

1. Move `## [Unreleased]` entries to a new `## [x.y.z] — YYYY-MM-DD`
   section in `CHANGELOG.md`
2. Bump `version` in `extension.yml`
3. Commit: `Release x.y.z`
4. Tag: `git tag vx.y.z && git push origin vx.y.z`
5. Create a GitHub release with auto-generated notes

## Questions

General questions: [open a discussion](https://github.com/TEKIMAX/speckit-security/discussions)
Bugs and features: [open an issue](https://github.com/TEKIMAX/speckit-security/issues)
Security reports: **security@tekimax.com** (see [SECURITY.md](SECURITY.md))
Anything else: **support@tekimax.com**

---

Thank you for helping make `tekimax-security` better.

— Christian Kaman · TEKIMAX · https://tekimax.com
