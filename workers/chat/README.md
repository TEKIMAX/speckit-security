# speckit-security docs chat Worker

Cloudflare Worker that powers the **Ask AI** chat on
[speckit.tekimax.com](https://speckit.tekimax.com). Runs
Llama 3.3 70B (FP8 fast) on Workers AI with the full docs corpus
as a system prompt — no RAG, no embeddings, just stuff-the-context
because the corpus is small (~14k tokens).

## Endpoints

- `GET /health` — `{ ok, model, corpus_bytes }`
- `POST /api/chat` — streams a reply

Request body:

```json
{
  "messages": [
    { "role": "user", "content": "What are the six gates?" }
  ]
}
```

Response: server-sent events stream of model tokens.

## CORS

`ALLOWED_ORIGIN` in `wrangler.toml` gates production traffic.
Local dev origins (`localhost:3000-3999`, `127.0.0.1:3000-3999`)
are always allowed so `pnpm dev` in `docs-site/` works against
the deployed worker.

## Regenerating the corpus

The docs corpus is embedded at build time via
`src/context.generated.ts`. Whenever docs content changes, run:

```bash
pnpm build:context
```

from `workers/chat/`. This re-runs
`docs-site/scripts/build-chat-context.mjs` and overwrites the
generated file. Commit the regenerated file alongside the docs
changes.

## Deploy

```bash
cd workers/chat
pnpm install
pnpm build:context
pnpm publish              # runs: wrangler deploy
# or equivalently:
npx wrangler deploy
```

> `pnpm` has a built-in `deploy` command for workspace packaging,
> which is why this script is named `publish` instead of `deploy`.
> `pnpm deploy` would error with `ERR_PNPM_CANNOT_DEPLOY`.

First-time deploy: you'll need `wrangler login` (or a
`CLOUDFLARE_API_TOKEN` env var in CI) and a Workers AI quota on
your Cloudflare account.

## Why Workers AI and not Claude

Workers AI runs native on Cloudflare with zero external API keys,
generous free tier, and sub-200ms cold starts. Llama 3.3 70B is
strong enough for grounded docs Q&A at a corpus this small. The
`MODEL` constant in `src/index.ts` can be swapped if you want to
move to Claude via Cloudflare AI Gateway or Stripe AI Gateway
later.
