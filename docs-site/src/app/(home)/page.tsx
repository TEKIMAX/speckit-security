import Link from 'next/link';

export default function HomePage() {
  return (
    <main className="flex flex-col items-center justify-center flex-1 px-6 py-16 max-w-5xl mx-auto text-center">
      <div className="inline-flex items-center gap-2 rounded-full border border-fd-border bg-fd-card px-4 py-1.5 text-xs font-medium text-fd-muted-foreground mb-8">
        <span className="text-fd-primary">v0.2.2</span>
        <span>·</span>
        <span>alpha</span>
        <span>·</span>
        <span>Apache-2.0</span>
      </div>

      <h1 className="text-5xl sm:text-6xl lg:text-7xl font-bold tracking-tight leading-[1.05] mb-6">
        Security gates for
        <br />
        <span className="bg-gradient-to-r from-violet-400 via-fuchsia-400 to-amber-300 bg-clip-text text-transparent">
          spec-driven development.
        </span>
      </h1>

      <p className="max-w-2xl text-lg sm:text-xl text-fd-muted-foreground leading-relaxed mb-10">
        A{' '}
        <a
          href="https://github.com/github/spec-kit"
          className="text-fd-foreground underline underline-offset-4 hover:text-fd-primary"
        >
          GitHub Spec Kit
        </a>{' '}
        extension that catches prompt injection, committed secrets, unpinned
        models, and undeclared PII <strong>before code ships</strong>. Eight
        slash commands, five phase hooks, six gates — all stack-agnostic.
      </p>

      <div className="flex flex-col sm:flex-row items-center gap-3 mb-16">
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

      <div className="w-full max-w-2xl rounded-xl border border-fd-border bg-fd-card/50 p-1 mb-20">
        <div className="rounded-lg bg-fd-muted/30 px-5 py-4 text-left font-mono text-sm text-fd-foreground overflow-x-auto">
          <div className="text-fd-muted-foreground"># Install Spec Kit</div>
          <div>uv tool install specify-cli --from git+https://github.com/github/spec-kit.git</div>
          <div className="mt-2 text-fd-muted-foreground"># Install this extension</div>
          <div>git clone https://github.com/TEKIMAX/speckit-security</div>
          <div>specify extension add --dev ./speckit-security</div>
        </div>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 w-full text-left">
        {FEATURES.map((f) => (
          <div
            key={f.title}
            className="rounded-xl border border-fd-border bg-fd-card p-5 hover:border-fd-primary/50 transition"
          >
            <div className="text-fd-primary text-xs font-semibold mb-2">{f.tag}</div>
            <h3 className="font-semibold text-fd-foreground mb-1">{f.title}</h3>
            <p className="text-sm text-fd-muted-foreground leading-relaxed">{f.body}</p>
          </div>
        ))}
      </div>

      <div className="mt-16 text-sm text-fd-muted-foreground">
        Works with{' '}
        <span className="text-fd-foreground font-medium">Claude Code</span>,{' '}
        <span className="text-fd-foreground font-medium">Copilot</span>,{' '}
        <span className="text-fd-foreground font-medium">Cursor</span>,{' '}
        <span className="text-fd-foreground font-medium">Gemini CLI</span>,{' '}
        <span className="text-fd-foreground font-medium">OpenCode</span>, and
        15+ other Spec Kit–supported agents.
      </div>
    </main>
  );
}

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
    body: 'Checks a red-team report file exists. An optional runner hits staging with safety guards — refuses prod URLs, rate-limited.',
  },
  {
    tag: 'GATE F',
    title: 'Inline Content Scan',
    body: 'Blocks inline system prompts in src/, committed secrets anywhere in the repo, and .env files tracked by git.',
  },
];
