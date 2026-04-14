import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Articles · speckit-security',
  description:
    'Writing from TEKIMAX on speckit-security: launch notes, deep dives on spec-driven security, and release news for the GitHub Spec Kit extension.',
  alternates: { canonical: '/articles' },
  openGraph: {
    type: 'website',
    title: 'Articles · speckit-security',
    description:
      'Writing from TEKIMAX on speckit-security: launch notes, deep dives, and release news.',
    url: '/articles',
  },
};

export default function ArticlesLayout({ children }: { children: React.ReactNode }) {
  return children;
}
