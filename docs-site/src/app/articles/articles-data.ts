import { articlesSource } from '@/lib/source';

export type ArticleCardData = {
  url: string;
  slug: string[];
  title: string;
  description: string;
  excerpt?: string;
  date: string;
  author?: string;
};

type Bucket = {
  blog: ArticleCardData[];
  news: ArticleCardData[];
};

// Build-time collection of every article in content/articles, split
// into two buckets by the first slug segment (blog/ or news/). Sorted
// newest first within each bucket so the landing page always shows
// the latest at the top without runtime sorting.
export const articles: Bucket = (() => {
  const pages = articlesSource.getPages();
  const all: ArticleCardData[] = pages
    .map((p) => ({
      url: p.url,
      slug: p.slugs,
      title: p.data.title,
      description: p.data.description ?? '',
      excerpt: p.data.excerpt,
      date: p.data.date,
      author: p.data.author,
    }))
    .sort((a, b) => (b.date ?? '').localeCompare(a.date ?? ''));

  return {
    blog: all.filter((a) => a.slug[0] === 'blog'),
    news: all.filter((a) => a.slug[0] === 'news'),
  };
})();

export function getArticleHref(a: ArticleCardData): string {
  return a.url;
}
