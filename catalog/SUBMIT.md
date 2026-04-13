# Submitting to the spec-kit Community Catalog

This folder contains the draft entry and submission instructions for
adding `tekimax-security` to the public spec-kit community catalog.

**Status:** draft — not yet submitted. Requires repo to be **public**
before submission (see "Prerequisites" below).

---

## Prerequisites

1. **Make `TEKIMAX/speckit-security` public.** The catalog requires a
   discoverable, cloneable repo.

   ```bash
   gh repo edit TEKIMAX/speckit-security --visibility public --accept-visibility-change-consequences
   ```

2. **Tag a release.**

   ```bash
   cd ~/tekimax/speckit-security
   git tag v0.2.0
   git push origin v0.2.0
   gh release create v0.2.0 --generate-notes
   ```

3. **Smoke-test one more time** from a clean clone of the public repo:

   ```bash
   rm -rf /tmp/smoke-public && mkdir -p /tmp/smoke-public && cd /tmp/smoke-public
   git clone https://github.com/TEKIMAX/speckit-security.git
   specify init public-smoke --ai claude --no-git
   cd public-smoke
   specify extension add --dev ../speckit-security
   specify extension list
   ```

---

## Submission steps

```bash
# 1. Fork spec-kit
gh repo fork github/spec-kit --clone --remote

cd spec-kit

# 2. Create a branch
git checkout -b add-tekimax-security

# 3. Add the entry to the community catalog
#    File: extensions/catalog.community.json
#    Append the object from catalog/entry.json to the "extensions" array.

# 4. Update the Community Extensions table in README.md.
#    Add a row:
#    | tekimax-security | TEKIMAX | Security-first SDD: threat modeling, red team, guardrails, data contracts, model governance | https://github.com/TEKIMAX/speckit-security |

# 5. Commit and push
git add extensions/catalog.community.json README.md
git commit -m "Add tekimax-security to community catalog"
git push origin add-tekimax-security

# 6. Open the PR
gh pr create --repo github/spec-kit \
  --title "Add tekimax-security to community catalog" \
  --body-file catalog/PR-BODY.md
```

---

## PR body template

See `PR-BODY.md`.

---

## Why this is gated on user confirmation

Submitting a PR to an external org (`github/spec-kit`) is a visible,
hard-to-reverse action. Anyone can see the PR, and the content reveals
TEKIMAX's framework opinions publicly. **Do not submit without explicit
approval from the TEKIMAX lead.**
