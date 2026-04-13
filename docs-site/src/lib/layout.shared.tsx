import type { BaseLayoutProps } from 'fumadocs-ui/layouts/shared';
import { gitConfig } from './shared';

export function baseOptions(): BaseLayoutProps {
  return {
    nav: {
      title: (
        <span className="inline-flex items-center gap-2">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src="/favicon.png"
            alt=""
            width={24}
            height={24}
            className="rounded-sm"
          />
          <span className="font-bold tracking-tight">
            <span className="text-fd-primary">speckit</span>
            <span className="text-fd-muted-foreground">-security</span>
          </span>
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
