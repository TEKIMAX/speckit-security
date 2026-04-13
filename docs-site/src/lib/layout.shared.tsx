import type { BaseLayoutProps } from 'fumadocs-ui/layouts/shared';
import { gitConfig } from './shared';

export function baseOptions(): BaseLayoutProps {
  return {
    nav: {
      title: (
        <span className="font-bold tracking-tight">
          <span className="text-fd-primary">speckit</span>
          <span className="text-fd-muted-foreground">-security</span>
        </span>
      ),
    },
    githubUrl: `https://github.com/${gitConfig.user}/${gitConfig.repo}`,
    links: [
      {
        text: 'Docs',
        url: '/docs',
      },
      {
        text: 'Articles',
        url: '/articles',
      },
      {
        text: 'Changelog',
        url: `https://github.com/${gitConfig.user}/${gitConfig.repo}/blob/main/CHANGELOG.md`,
        external: true,
      },
      {
        text: 'Releases',
        url: `https://github.com/${gitConfig.user}/${gitConfig.repo}/releases`,
        external: true,
      },
    ],
  };
}
