import { articlesSource } from '@/lib/source';
import { notFound } from 'next/navigation';
import Link from 'next/link';
import type { Metadata } from 'next';

// Article reader — matches any path under /articles/<type>/<slug>.
// The top-level /articles route is served by ../page.tsx; this
// catch-all only fires for deeper paths (blog/... or news/...).

type Params = { slug: string[] };

export default async function ArticlePage(props: { params: Promise<Params> }) {
  const { slug } = await props.params;

  const page = articlesSource.getPage(slug);
  if (!page) notFound();

  const type = slug[0] === 'news' ? 'news' : 'blog';
  const MDX = page.data.body;

  return (
    <main className="flex flex-col flex-1 px-6 py-16 max-w-3xl mx-auto w-full">
      <Link
        href="/articles"
        className="inline-flex items-center gap-1 text-sm text-fd-muted-foreground hover:text-fd-foreground mb-10 transition"
      >
        ← All articles
      </Link>

      <header className="mb-10 pb-10 border-b border-fd-border">
        <div className="flex items-center gap-3 text-xs font-medium text-fd-muted-foreground mb-4">
          <span className="uppercase tracking-wide text-fd-primary">
            {type}
          </span>
          <span>·</span>
          <time>{page.data.date}</time>
          {page.data.author ? (
            <>
              <span>·</span>
              <span>{page.data.author}</span>
            </>
          ) : null}
        </div>
        <h1 className="text-4xl sm:text-5xl font-bold tracking-tight leading-[1.1] mb-4">
          {page.data.title}
        </h1>
        {page.data.description ? (
          <p className="text-lg text-fd-muted-foreground leading-relaxed">
            {page.data.description}
          </p>
        ) : null}
      </header>

      <article className="prose prose-invert max-w-none">
        <MDX />
      </article>

      <footer className="mt-16 pt-10 border-t border-fd-border text-sm text-fd-muted-foreground">
        <div className="flex flex-col sm:flex-row items-start sm:items-center gap-4 justify-between">
          <div>
            Questions or feedback?{' '}
            <a
              href="mailto:support@tekimax.com"
              className="text-fd-primary hover:underline"
            >
              support@tekimax.com
            </a>
          </div>
          <Link
            href="/articles"
            className="inline-flex items-center gap-1 text-fd-primary hover:underline"
          >
            ← Back to all articles
          </Link>
        </div>
      </footer>
    </main>
  );
}

export async function generateStaticParams() {
  return articlesSource.getPages().map((page) => ({
    slug: page.slugs,
  }));
}

export async function generateMetadata(props: {
  params: Promise<Params>;
}): Promise<Metadata> {
  const { slug } = await props.params;
  const page = articlesSource.getPage(slug);
  if (!page) return {};

  return {
    title: page.data.title,
    description: page.data.description,
  };
}
