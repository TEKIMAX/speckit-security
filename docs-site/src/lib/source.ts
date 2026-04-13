import { articles, docs } from 'collections/server';
import { type InferPageType, loader } from 'fumadocs-core/source';
import { lucideIconsPlugin } from 'fumadocs-core/source/lucide-icons';
import { docsContentRoute, docsImageRoute, docsRoute } from './shared';

// See https://fumadocs.dev/docs/headless/source-api for more info
export const source = loader({
  baseUrl: docsRoute,
  source: docs.toFumadocsSource(),
  plugins: [lucideIconsPlugin()],
});

// Articles source loads blog posts and news items from content/articles.
// File path (blog/<slug>.mdx or news/<slug>.mdx) determines the article
// type — the UI reads page.slugs[0] to group articles into tabs.
export const articlesSource = loader({
  baseUrl: '/articles',
  source: articles.toFumadocsSource(),
});

export type ArticleType = 'blog' | 'news';
export type Article = InferPageType<typeof articlesSource>;

export function getArticleType(article: Article): ArticleType {
  const first = article.slugs[0];
  return first === 'news' ? 'news' : 'blog';
}

export function getPageImage(page: InferPageType<typeof source>) {
  const segments = [...page.slugs, 'image.png'];

  return {
    segments,
    url: `${docsImageRoute}/${segments.join('/')}`,
  };
}

export function getPageMarkdownUrl(page: InferPageType<typeof source>) {
  const segments = [...page.slugs, 'content.md'];

  return {
    segments,
    url: `${docsContentRoute}/${segments.join('/')}`,
  };
}

export async function getLLMText(page: InferPageType<typeof source>) {
  const processed = await page.data.getText('processed');

  return `# ${page.data.title} (${page.url})

${processed}`;
}
