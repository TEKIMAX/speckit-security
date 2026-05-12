## 1. Commit message rules

**MUST** describe the change, not the process of making it.

A commit message is a permanent public artifact. Its only job is to
explain **what changed and why**, in the vocabulary of the project.

### What a good commit message looks like

```
Short, imperative summary under 72 characters

Optional longer body wrapped at ~72 characters. Explains the *why*
behind the change — what problem it solves, what it replaces, what
it enables.

- Bullet the concrete changes when there's more than one
- Reference file paths so a reviewer knows where to look
- Link to related issues by number when relevant
```

### What to NEVER include

- ❌ AI tool attribution unless the project explicitly adopts it
- ❌ References to the prompt, conversation, or thought process
- ❌ Internal review history ("strip X references", "hide Y")
- ❌ Informal language ("fixed it", "done", "oops")
- ❌ WIP / placeholder messages in shipped commits — squash first
- ❌ Proprietary information, pricing, unreleased feature names

### What to include

- ✅ Imperative verbs: `add`, `fix`, `document`, `rename`, `extract`, `refactor`
- ✅ The affected area: `auth:`, `docs:`, `scripts:`, `tests:`
- ✅ The rationale when non-obvious
- ✅ A `BREAKING:` prefix or trailer when the change breaks consumers

### Example — good

```
auth: reject expired JWT without hitting the database

Previously every request re-queried the session table even after
the token's `exp` claim had passed. Exit early in the middleware
when `exp < now` to save ~4ms per unauthenticated request.
```

### Example — bad (do not write these)

```
# Reveals internal scrub history
Strip vendor X references

# Reveals AI involvement
Fix bug (per AI suggestion)

# Reveals internal conversation
Address feedback from review call
```

---
