# speckit-security-docs

Documentation site for [`speckit-security`](https://github.com/TEKIMAX/speckit-security),
built with [Next.js](https://nextjs.org) + [Fumadocs](https://fumadocs.dev),
configured for static export so it deploys cleanly to Cloudflare Pages,
Netlify, S3, or any static host.

## Local development

```bash
pnpm install
pnpm dev
```

Open http://localhost:3000.

## Build

```bash
pnpm build
```

Produces a fully static site under `out/` — no Node runtime required
to serve it. 34 pages, including the landing page, every docs page,
the llms.txt artifacts, and a pre-built search index at
`/api/search`.

## Project layout

| Path | Purpose |
|---|---|
| `content/docs/*.mdx` | The actual documentation content |
| `content/docs/meta.json` | Sidebar order |
| `src/app/(home)/page.tsx` | Custom landing page with hero, install snippet, feature cards |
| `src/app/docs/[[...slug]]/page.tsx` | Fumadocs-generated docs router |
| `src/app/api/search/route.ts` | Static search index (flexsearch, built at compile time) |
| `src/lib/shared.ts` | Branding config (app name, GitHub org) |
| `src/lib/layout.shared.tsx` | Header nav (Docs / Changelog / Releases / GitHub) |
| `next.config.mjs` | `output: 'export'` + trailing slashes for static hosting |

## Search

Search is **entirely client-side** via flexsearch. The index is
generated at build time and stored as a JSON file at
`/api/search`. The client-side search dialog (provided by
`fumadocs-ui/provider/next`) loads that file and filters locally
in the browser. No server runtime, no server-side index, no
Cloudflare Workers required.

## Deployment

### One-time setup — create the Cloudflare Pages project

From any machine with `wrangler` authenticated:

```bash
wrangler pages project create speckit-security-docs \
  --production-branch main
```

### Required GitHub repo secrets

Add these to `Settings → Secrets and variables → Actions → New
repository secret`:

| Secret | Where to get it |
|---|---|
| `CLOUDFLARE_API_TOKEN` | Cloudflare dashboard → My Profile → API Tokens → Create Token → "Edit Cloudflare Pages" template |
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare dashboard → any domain → right sidebar "Account ID" |

The API token needs at minimum:
- Account · Cloudflare Pages · Edit
- User · User Details · Read

### How the deploy works

The `.github/workflows/docs-deploy.yml` workflow runs on every push
and pull request that touches `docs-site/**`. It:

1. Installs pnpm + Node 20
2. Runs `pnpm install --frozen-lockfile`
3. Runs `pnpm build` (static export to `docs-site/out/`)
4. Runs `wrangler pages deploy out --project-name speckit-security-docs`
5. On pull requests, comments on the PR with the preview URL

Pushes to `main` deploy to production. Pull requests get a unique
preview URL on the format
`https://<commit-sha>.speckit-security-docs.pages.dev`.

The workflow uses `concurrency:` so only one deploy is in flight per
branch at a time — newer pushes cancel older in-progress runs.

### Custom domain

Once the first deploy lands, add a custom domain in the Cloudflare
Pages dashboard:

1. Go to the `speckit-security-docs` project
2. Custom domains → Set up a custom domain
3. Enter e.g. `docs.tekimax.com`
4. Cloudflare will create the DNS record automatically if you're
   already on Cloudflare DNS

## Dev notes

- **No AI chat.** The default Fumadocs scaffold ships an `ai/search`
  component and `/api/chat` route that stream responses from
  OpenRouter. Both were removed so the site can be statically
  exported and because the extension is positioned as docs, not a
  chat product. Search still works — just client-side static search
  instead of LLM-augmented.
- **Search index file.** Fumadocs generates the index at
  `/api/search` using `createFromSource` with the `staticGET`
  handler. Static hosts serve it as a plain JSON file.
- **`trailingSlash: true`** — required for clean URLs on static
  hosts. Every page becomes a directory with `index.html` inside.
- **`images.unoptimized: true`** — Next.js image optimization
  requires a server runtime, so it's disabled for static export.
  Use plain `<img>` tags or `next/image` with `unoptimized` for
  future images.

## Updating content

All content lives in `content/docs/*.mdx`. Changes there
automatically appear on the next `pnpm dev` hot reload or the next
`pnpm build`.

To add a new page:

1. Create a new `.mdx` file under `content/docs/`
2. Add the slug to `content/docs/meta.json` under `pages`
3. The sidebar and routing update automatically

To override content ordering, edit `content/docs/meta.json`.

## Links

- [speckit-security repo](https://github.com/TEKIMAX/speckit-security)
- [Fumadocs](https://fumadocs.dev)
- [Next.js static export](https://nextjs.org/docs/app/building-your-application/deploying/static-exports)
- [Cloudflare Pages docs](https://developers.cloudflare.com/pages/)
