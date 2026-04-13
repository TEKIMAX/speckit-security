# Agent Compatibility

`speckit-security` is **agent-neutral** — the extension ships
generic Markdown command files and Spec Kit handles the translation
into each AI agent's native format at install time.

This document lists which agents have been **hands-on verified** to
work with `speckit-security`, which are supported by Spec Kit (and
therefore expected to work), and how each agent stores its commands.

---

## Verified end-to-end

These agents have been smoke-tested with a full install cycle:

| Agent | Version tested | Install location | Format | Status |
|---|---|---|---|---|
| **Claude Code** | spec-kit 0.6.2 | `.claude/skills/speckit-tekimax-security-*/SKILL.md` | Markdown skill with frontmatter | ✅ Verified |
| **OpenCode** | spec-kit 0.6.2 | `.opencode/command/speckit.tekimax-security.*.md` | Markdown command | ✅ Verified |
| **GitHub Copilot** | spec-kit 0.6.2 | `.github/agents/*.agent.md` + `.github/prompts/*.prompt.md` | Agent + prompt files | ✅ Verified |
| **Gemini CLI** | spec-kit 0.6.2 | `.gemini/commands/speckit.tekimax-security.*.toml` | TOML command | ✅ Verified |
| **Cursor** | spec-kit 0.6.2 | `.cursor/skills/speckit-tekimax-security-*/SKILL.md` | Markdown skill | ✅ Verified |

All seven `speckit-security` commands registered cleanly on each
agent, and the `gate-check.sh` script ran end-to-end after install.

## Supported by Spec Kit (inferred)

These agents are listed in `specify init --ai <name>` but haven't
been hands-on tested with `speckit-security`. They should work
because Spec Kit handles the translation layer and our extension
provides the same agent-neutral Markdown that it translates for the
verified agents above.

- `auggie`
- `bob`
- `codebuddy`
- `codex`
- `forge`
- `iflow`
- `junie`
- `kilocode`
- `kimi`
- `kiro-cli`
- `pi`
- `qodercli`
- `qwen`
- `roo`
- `shai`
- `tabnine`
- `trae`
- `vibe` (Mistral Vibe)
- `windsurf`
- `generic` (fallback for unsupported agents)

If you try one of these and it works, please open a PR to move it
into the "Verified" table. If it doesn't work, please open an issue
with the exact `specify init` and `specify extension add` output.

## Requirements regardless of agent

- **Spec Kit** `>= 0.1.0` installed via `uv tool install specify-cli`
- **Bash** (for the gate-check, audit, and red-team-run scripts) —
  macOS and Linux are supported; Windows requires WSL or Git Bash

## Testing on your agent of choice

```bash
# 1. Init a project with your target agent
specify init test-app --ai <agent-name> --no-git

# 2. Install speckit-security
cd test-app
specify extension add --dev /path/to/speckit-security

# 3. Verify registration
specify extension list
# Should show: TEKIMAX Secure SDD (v0.2.0) — Commands: 8 | Hooks: 5 | Status: Enabled

# 4. Verify commands were translated into the agent's format
specify extension info tekimax-security

# 5. Run the gate-check script directly to confirm the scripts work
bash .specify/extensions/tekimax-security/scripts/bash/gate-check.sh --help 2>&1 || true
```

If all five steps succeed, the agent is functionally supported.

## Adding an agent to the verified list

If you successfully run the full smoke test above:

1. Note the exact install location of the commands on your agent
2. Note the file format (Markdown, TOML, JSON, etc.)
3. Open a PR updating the "Verified end-to-end" table in this file

## Reporting incompatibilities

If `specify extension add` fails, or commands register but don't
actually execute:

- **Open an issue** at https://github.com/TEKIMAX/speckit-security/issues
- **Include** the agent name, spec-kit version, OS, and the exact
  output of `specify extension add --dev` and `specify extension list`
- **Do not** include prompts or conversation snippets — just the
  commands you ran and the output they produced
