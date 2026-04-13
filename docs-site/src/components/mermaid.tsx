'use client';

import { useEffect, useRef, useState } from 'react';

type MermaidProps = {
  /** The mermaid source (flowchart/sequenceDiagram/etc.) */
  chart: string;
  /** Optional explicit id; auto-generated per instance if not passed */
  id?: string;
};

// Singleton import — mermaid is large (~500 kB) so load it once and
// reuse the instance across every <Mermaid> on the page.
let mermaidPromise: Promise<typeof import('mermaid').default> | null = null;

function loadMermaid() {
  if (!mermaidPromise) {
    mermaidPromise = import('mermaid').then((m) => {
      const mermaid = m.default;
      mermaid.initialize({
        startOnLoad: false,
        theme: 'dark',
        securityLevel: 'loose',
        fontFamily: 'var(--font-inter, ui-sans-serif, system-ui, sans-serif)',
        themeVariables: {
          // Map mermaid's theme tokens to the Fumadocs dark palette so
          // the SVG blends with the rest of the docs card styling.
          background: '#0a0a0a',
          primaryColor: '#171717',
          primaryTextColor: '#f4f4f5',
          primaryBorderColor: '#7c3aed',
          secondaryColor: '#1a1a1a',
          secondaryTextColor: '#e4e4e7',
          secondaryBorderColor: '#525252',
          tertiaryColor: '#0f0f0f',
          tertiaryTextColor: '#a3a3a3',
          tertiaryBorderColor: '#404040',
          lineColor: '#71717a',
          textColor: '#e4e4e7',
          mainBkg: '#171717',
          nodeBorder: '#7c3aed',
          nodeTextColor: '#f4f4f5',
          clusterBkg: '#0a0a0a',
          clusterBorder: '#404040',
          edgeLabelBackground: '#0a0a0a',
        },
      });
      return mermaid;
    });
  }
  return mermaidPromise;
}

export function Mermaid({ chart, id }: MermaidProps) {
  const [svg, setSvg] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const idRef = useRef<string>(
    id ?? `mermaid-${Math.random().toString(36).slice(2, 10)}`,
  );

  useEffect(() => {
    let cancelled = false;

    loadMermaid()
      .then(async (mermaid) => {
        try {
          const { svg: rendered } = await mermaid.render(idRef.current, chart);
          if (!cancelled) {
            setSvg(rendered);
            setError(null);
          }
        } catch (e) {
          if (!cancelled) {
            setError((e as Error).message ?? String(e));
          }
        }
      })
      .catch((e) => {
        if (!cancelled) {
          setError((e as Error).message ?? String(e));
        }
      });

    return () => {
      cancelled = true;
    };
  }, [chart]);

  if (error) {
    return (
      <div className="my-6 rounded-xl border border-red-500/40 bg-red-950/20 p-5 text-sm text-red-300">
        <div className="font-semibold mb-2">Diagram failed to render</div>
        <pre className="text-xs opacity-80 whitespace-pre-wrap break-all">
          {error}
        </pre>
      </div>
    );
  }

  if (!svg) {
    // Placeholder while mermaid's async import + render completes.
    // The chart source is shown as a dim monospace preview so the
    // fold doesn't collapse and content below doesn't jump.
    return (
      <div className="my-6 rounded-xl border border-fd-border bg-fd-card/50 p-6 text-center">
        <div className="text-xs uppercase tracking-wider text-fd-muted-foreground animate-pulse">
          Rendering diagram…
        </div>
      </div>
    );
  }

  return (
    <div
      className="my-6 rounded-xl border border-fd-border bg-fd-card/50 p-6 overflow-x-auto [&>svg]:mx-auto [&>svg]:max-w-full [&>svg]:h-auto"
      dangerouslySetInnerHTML={{ __html: svg }}
    />
  );
}
