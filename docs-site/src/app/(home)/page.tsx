import Link from 'next/link';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'speckit-security · Security gates for spec-driven development',
  description:
    'A GitHub Spec Kit extension that catches prompt injection, committed secrets, unpinned models, and undeclared PII before code ships. Eight commands, five hooks, six gates. Stack-agnostic and agent-neutral.',
  alternates: { canonical: '/' },
  openGraph: {
    type: 'website',
    title: 'speckit-security · Security gates for spec-driven development',
    description:
      'A GitHub Spec Kit extension that catches prompt injection, committed secrets, unpinned models, and undeclared PII before code ships.',
    url: '/',
  },
};

export default function HomePage() {
  return (
    <main className="flex flex-col flex-1 px-6 py-16 max-w-7xl mx-auto w-full">
      {/* Hero: two-column split with copy on the left and install on the right */}
      <section className="grid grid-cols-1 lg:grid-cols-[1.15fr_1fr] gap-12 lg:gap-16 items-center mb-24">
        {/* Left: headline, description, CTAs */}
        <div className="text-left">
          <div className="inline-flex items-center gap-2 rounded-full border border-fd-border bg-fd-card px-4 py-1.5 text-xs font-medium text-fd-muted-foreground mb-6">
            <span className="text-fd-primary">v0.2.6</span>
            <span>·</span>
            <span>alpha</span>
            <span>·</span>
            <span>Apache-2.0</span>
          </div>

          <h1 className="text-5xl sm:text-6xl lg:text-7xl font-bold tracking-tight leading-[1.05] mb-6">
            Security gates for
            <br />
            <span className="bg-gradient-to-r from-orange-400 via-amber-300 to-blue-400 bg-clip-text text-transparent">
              spec-driven development.
            </span>
          </h1>

          <p className="max-w-xl text-lg sm:text-xl text-fd-muted-foreground leading-relaxed mb-8">
            A{' '}
            <a
              href="https://github.com/github/spec-kit"
              className="text-fd-foreground underline underline-offset-4 hover:text-fd-primary"
            >
              GitHub Spec Kit
            </a>{' '}
            extension that catches prompt injection, committed secrets,
            unpinned models, and undeclared PII{' '}
            <strong>before code ships</strong>. Eight slash commands,
            five phase hooks, six gates. All stack-agnostic.
          </p>

          <div className="flex flex-col sm:flex-row items-start sm:items-center gap-3 mb-6">
            <Link
              href="/docs"
              className="inline-flex items-center gap-2 rounded-lg bg-fd-primary px-6 py-3 text-sm font-semibold text-fd-primary-foreground hover:opacity-90 transition"
            >
              Read the docs →
            </Link>
            <a
              href="https://github.com/TEKIMAX/speckit-security"
              className="inline-flex items-center gap-2 rounded-lg border border-fd-border bg-fd-card px-6 py-3 text-sm font-semibold text-fd-foreground hover:bg-fd-accent transition"
            >
              View on GitHub
            </a>
          </div>

          <p className="max-w-xl text-xs text-fd-muted-foreground/80 italic mb-6 border-l-2 border-fd-border pl-3">
            Not a complete security solution. One layer of the
            spec-driven development lifecycle, designed to run alongside
            SAST, dependency scanning, runtime monitoring, and your
            existing compliance tooling.
          </p>

          <div>
            <div className="text-xs font-semibold uppercase tracking-wider text-fd-muted-foreground mb-3">
              Works with
            </div>
            <div className="flex flex-wrap items-center gap-2">
              {AGENTS.map((a) => (
                <AgentPill key={a.name} {...a} />
              ))}
              <span className="inline-flex items-center rounded-full border border-fd-border bg-fd-card px-3 py-1.5 text-xs font-medium text-fd-muted-foreground">
                + 15 more
              </span>
            </div>
          </div>
        </div>

        {/* Right: install snippet card */}
        <div className="w-full">
          <div className="rounded-2xl border border-fd-border bg-fd-card/60 p-1 shadow-lg shadow-black/20 backdrop-blur">
            {/* Fake macOS title bar for a terminal feel */}
            <div className="flex items-center gap-1.5 px-4 py-3 border-b border-fd-border/60">
              <span className="h-3 w-3 rounded-full bg-red-400/70"></span>
              <span className="h-3 w-3 rounded-full bg-amber-300/70"></span>
              <span className="h-3 w-3 rounded-full bg-emerald-400/70"></span>
              <span className="ml-3 text-xs font-medium text-fd-muted-foreground select-none">
                install.sh
              </span>
            </div>
            <div className="rounded-b-xl bg-fd-muted/20 px-5 py-5 text-left font-mono text-[13px] leading-relaxed text-fd-foreground overflow-x-auto">
              <div className="text-fd-muted-foreground"># 1. Install Spec Kit</div>
              <div className="whitespace-nowrap">
                uv tool install specify-cli \
              </div>
              <div className="whitespace-nowrap pl-4">
                --from git+https://github.com/github/spec-kit.git
              </div>

              <div className="mt-3 text-fd-muted-foreground">
                # 2. Clone this extension
              </div>
              <div className="whitespace-nowrap">
                git clone https://github.com/TEKIMAX/speckit-security
              </div>

              <div className="mt-3 text-fd-muted-foreground">
                # 3. Install into any Spec Kit project
              </div>
              <div className="whitespace-nowrap">
                cd your-project && specify extension add --dev \
              </div>
              <div className="whitespace-nowrap pl-4">
                ../speckit-security
              </div>

              <div className="mt-4 flex items-center gap-2 text-fd-muted-foreground">
                <span className="inline-block h-1.5 w-1.5 rounded-full bg-emerald-400 animate-pulse"></span>
                <span>Ready in under a minute · No npm or pip install</span>
              </div>
            </div>
          </div>

          {/* Secondary mini-cards under the terminal */}
          <div className="grid grid-cols-3 gap-2 mt-4">
            <div className="rounded-lg border border-fd-border bg-fd-card/40 px-3 py-2.5 text-center">
              <div className="text-lg font-bold text-orange-400">8</div>
              <div className="text-[10px] uppercase tracking-wide text-fd-muted-foreground">
                commands
              </div>
            </div>
            <div className="rounded-lg border border-fd-border bg-fd-card/40 px-3 py-2.5 text-center">
              <div className="text-lg font-bold text-amber-300">5</div>
              <div className="text-[10px] uppercase tracking-wide text-fd-muted-foreground">
                hooks
              </div>
            </div>
            <div className="rounded-lg border border-fd-border bg-fd-card/40 px-3 py-2.5 text-center">
              <div className="text-lg font-bold text-blue-400">6</div>
              <div className="text-[10px] uppercase tracking-wide text-fd-muted-foreground">
                gates
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Features grid: full width below the hero */}
      <section className="mb-16">
        <h2 className="text-2xl font-bold text-fd-foreground mb-6 text-left">
          The six gates
        </h2>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 text-left">
          {FEATURES.map((f) => (
            <div
              key={f.title}
              className="rounded-xl border border-fd-border bg-fd-card p-5 hover:border-fd-primary/50 transition"
            >
              <div className="text-fd-primary text-xs font-semibold mb-2">
                {f.tag}
              </div>
              <h3 className="font-semibold text-fd-foreground mb-1">
                {f.title}
              </h3>
              <p className="text-sm text-fd-muted-foreground leading-relaxed">
                {f.body}
              </p>
            </div>
          ))}
        </div>
      </section>
    </main>
  );
}

// --- agent pill row ----------------------------------------------

type AgentPillProps = {
  name: string;
  /** simpleicons.org slug (icon is fetched from their CDN) */
  slug?: string;
  /** local public/ image path (wins over slug when both are set) */
  src?: string;
  /** brand accent colour, hex without the hash */
  accent?: string;
  /** fallback letter if neither slug nor src is provided */
  letter?: string;
};

function AgentPill({ name, slug, src, letter, accent }: AgentPillProps) {
  // Icon source priority:
  //   1. `src` (local asset under /public)
  //   2. `slug` (simpleicons.org CDN recoloured SVG)
  //   3. `letter` (first-letter pill as a last-resort fallback)
  return (
    <span className="inline-flex items-center gap-2 rounded-full border border-fd-border bg-fd-card px-3.5 py-2 text-sm font-medium text-fd-foreground hover:border-fd-primary/50 transition">
      {src ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img
          src={src}
          alt=""
          width={20}
          height={20}
          className="h-5 w-5 object-contain"
        />
      ) : slug ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img
          src={`https://cdn.simpleicons.org/${slug}/${accent ?? 'f4f4f5'}`}
          alt=""
          width={20}
          height={20}
          className="h-5 w-5"
        />
      ) : (
        <span
          className="h-5 w-5 inline-flex items-center justify-center rounded-full text-[10px] font-bold text-white"
          style={{ background: accent ?? '#71717a' }}
        >
          {letter ?? name.charAt(0)}
        </span>
      )}
      {name}
    </span>
  );
}

const AGENTS: AgentPillProps[] = [
  { name: 'Claude Code', slug: 'anthropic', accent: 'D97757' },
  { name: 'Copilot', slug: 'githubcopilot', accent: 'f4f4f5' },
  { name: 'Cursor', slug: 'cursor', accent: 'f4f4f5' },
  { name: 'Gemini CLI', slug: 'googlegemini', accent: '8E75B2' },
  { name: 'OpenCode', src: '/agents/opencode.png' },
];

const FEATURES = [
  {
    tag: 'GATE A',
    title: 'Data Contract',
    body: 'Blocks if the spec has no Data Contract section, the Zod schema file is missing, or the schema uses z.any().',
  },
  {
    tag: 'GATE B',
    title: 'Threat Model',
    body: 'Blocks if the spec has no threat model section, or if any High/Critical threat is marked [UNMITIGATED].',
  },
  {
    tag: 'GATE C',
    title: 'Model Governance',
    body: 'For AI features: blocks on unpinned versions like "latest" or "stable", or when no rollback plan is mentioned.',
  },
  {
    tag: 'GATE D',
    title: 'Guardrails',
    body: 'For AI features: requires a versioned guardrail YAML with both blocked_patterns and redact_patterns defined.',
  },
  {
    tag: 'GATE E',
    title: 'Red Team',
    body: 'Checks a red-team report file exists. An optional runner hits staging with safety guards that refuse prod URLs and rate-limit requests.',
  },
  {
    tag: 'GATE F',
    title: 'Inline Content Scan',
    body: 'Blocks inline system prompts in src/, committed secrets anywhere in the repo, and .env files tracked by git.',
  },
];
