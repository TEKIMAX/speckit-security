'use client';

import Link from 'next/link';
import { useState } from 'react';
import { ArticleCardData, articles, getArticleHref } from './articles-data';

type Tab = 'blog' | 'news';

export default function ArticlesPage() {
  const [tab, setTab] = useState<Tab>('blog');
  const current = articles[tab];

  return (
    <main className="flex flex-col flex-1 px-6 py-16 max-w-5xl mx-auto w-full">
      <header className="mb-12 text-center">
        <div className="inline-flex items-center gap-2 rounded-full border border-fd-border bg-fd-card px-4 py-1.5 text-xs font-medium text-fd-muted-foreground mb-6">
          <span className="text-fd-primary">Articles</span>
          <span>·</span>
          <span>Updated {new Date().toISOString().slice(0, 10)}</span>
        </div>
        <h1 className="text-4xl sm:text-5xl font-bold tracking-tight mb-4">
          Writing from TEKIMAX on{' '}
          <span className="bg-gradient-to-r from-violet-400 via-fuchsia-400 to-amber-300 bg-clip-text text-transparent">
            speckit-security
          </span>
        </h1>
        <p className="max-w-2xl mx-auto text-lg text-fd-muted-foreground leading-relaxed">
          Essays on why we built the extension, how we use it on real
          client work, and short-form release notes. One page, two
          tabs — pick the flavor you want.
        </p>
      </header>

      {/* Tab toggle */}
      <div className="flex items-center justify-center mb-10">
        <div className="inline-flex items-center gap-1 rounded-full border border-fd-border bg-fd-card p-1">
          <TabButton
            active={tab === 'blog'}
            onClick={() => setTab('blog')}
            count={articles.blog.length}
          >
            Blog
          </TabButton>
          <TabButton
            active={tab === 'news'}
            onClick={() => setTab('news')}
            count={articles.news.length}
          >
            News
          </TabButton>
        </div>
      </div>

      {/* Cards */}
      {current.length === 0 ? (
        <div className="rounded-xl border border-fd-border bg-fd-card p-10 text-center text-fd-muted-foreground">
          Nothing here yet. Check back soon.
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
          {current.map((a) => (
            <ArticleCard key={a.url} article={a} tab={tab} />
          ))}
        </div>
      )}
    </main>
  );
}

function TabButton({
  children,
  active,
  onClick,
  count,
}: {
  children: React.ReactNode;
  active: boolean;
  onClick: () => void;
  count: number;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={[
        'inline-flex items-center gap-2 rounded-full px-5 py-2 text-sm font-semibold transition',
        active
          ? 'bg-fd-primary text-fd-primary-foreground shadow-sm'
          : 'text-fd-muted-foreground hover:text-fd-foreground',
      ].join(' ')}
      aria-pressed={active}
    >
      {children}
      <span
        className={[
          'inline-flex items-center justify-center rounded-full px-2 text-xs font-medium tabular-nums',
          active
            ? 'bg-fd-primary-foreground/20 text-fd-primary-foreground'
            : 'bg-fd-muted/40 text-fd-muted-foreground',
        ].join(' ')}
      >
        {count}
      </span>
    </button>
  );
}

function ArticleCard({ article, tab }: { article: ArticleCardData; tab: Tab }) {
  return (
    <Link
      href={getArticleHref(article)}
      className="group flex flex-col rounded-xl border border-fd-border bg-fd-card p-6 hover:border-fd-primary/60 hover:bg-fd-accent/40 transition"
    >
      <div className="flex items-center gap-3 text-xs font-medium text-fd-muted-foreground mb-3">
        <span className="uppercase tracking-wide text-fd-primary">
          {tab}
        </span>
        <span>·</span>
        <time>{article.date}</time>
        {article.author ? (
          <>
            <span>·</span>
            <span>{article.author}</span>
          </>
        ) : null}
      </div>
      <h2 className="font-bold text-xl text-fd-foreground leading-snug mb-2 group-hover:text-fd-primary transition">
        {article.title}
      </h2>
      <p className="text-sm text-fd-muted-foreground leading-relaxed line-clamp-4 mb-4">
        {article.excerpt || article.description}
      </p>
      <span className="mt-auto inline-flex items-center gap-1 text-sm font-semibold text-fd-primary">
        Read {tab === 'blog' ? 'post' : 'update'} →
      </span>
    </Link>
  );
}
