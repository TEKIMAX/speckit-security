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

## Rate limiting with Upstash

Cloudflare's native WAF rate limiting moved to enterprise-only
tiers, so this Worker runs its own rate limiter via
[`@upstash/ratelimit`](https://github.com/upstash/ratelimit) +
Upstash Redis REST. Sliding window: **20 requests per 60 seconds
per client IP** (`CF-Connecting-IP`).

**First time setup:**

1. Create a free Upstash Redis database at
   [console.upstash.com](https://console.upstash.com/) (free tier:
   10,000 commands/day, enough for hundreds of thousands of chat
   turns at 1 command per limit check).
2. In the Upstash console, copy the **REST URL** and **REST token**
   for your database.
3. Set them as Worker secrets (never commit these):

   ```bash
   cd workers/chat
   npx wrangler secret put UPSTASH_REDIS_REST_URL
   # paste the URL when prompted
   npx wrangler secret put UPSTASH_REDIS_REST_TOKEN
   # paste the token when prompted
   ```
4. Redeploy so the new secrets take effect:

   ```bash
   npx wrangler deploy
   ```

**Fail-open on missing config.** If either secret is absent the
limiter logs a `console.warn` and passes every request through.
This means a fresh `wrangler deploy` works even before secrets are
set; rate limiting activates automatically once you've configured
both.

**Adjusting the window.** Edit
`Ratelimit.slidingWindow(20, '60 s')` in `src/index.ts`. The
first number is request count, the second is window duration
(supports `s`, `m`, `h`, `d`).

**What a rate-limited client sees:**

```
HTTP/1.1 429 Too Many Requests
Retry-After: 23
X-RateLimit-Limit: 20
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1712000000000

{"error":"rate limit exceeded","retry_after_seconds":23}
```

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
