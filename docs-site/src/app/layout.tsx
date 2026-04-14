import { RootProvider } from 'fumadocs-ui/provider/next';
import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import { siteUrl, appName } from '@/lib/shared';
import './global.css';

const inter = Inter({
  subsets: ['latin'],
});

const description =
  'Security gates for spec-driven development with AI agents. A GitHub Spec Kit extension by TEKIMAX: threat modeling, red teaming, AI guardrails, data contracts, and model governance.';

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: {
    default: 'speckit-security · Security gates for spec-driven development',
    template: '%s · speckit-security',
  },
  description,
  applicationName: appName,
  keywords: [
    'spec-driven development',
    'spec kit',
    'AI security',
    'LLM guardrails',
    'threat modeling',
    'STRIDE',
    'red teaming',
    'prompt injection',
    'secret scanning',
    'model governance',
    'TEKIMAX',
  ],
  authors: [{ name: 'TEKIMAX', url: 'https://tekimax.com' }],
  creator: 'TEKIMAX',
  publisher: 'TEKIMAX',
  alternates: {
    canonical: '/',
  },
  openGraph: {
    type: 'website',
    url: siteUrl,
    siteName: appName,
    title: 'speckit-security · Security gates for spec-driven development',
    description,
    images: [
      {
        url: '/favicon.png',
        width: 1563,
        height: 1563,
        alt: 'speckit-security',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'speckit-security · Security gates for spec-driven development',
    description,
    images: ['/favicon.png'],
    creator: '@tekimax',
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-snippet': -1,
      'max-image-preview': 'large',
      'max-video-preview': -1,
    },
  },
  icons: {
    icon: [{ url: '/favicon.png', type: 'image/png' }],
    shortcut: ['/favicon.png'],
    apple: ['/favicon.png'],
  },
};

export default function Layout({ children }: LayoutProps<'/'>) {
  return (
    <html lang="en" className={inter.className} suppressHydrationWarning>
      <body className="flex flex-col min-h-screen">
        <RootProvider
          search={{
            // Static search works without a server runtime — the
            // index is generated at build time and fetched by the
            // client. Required for output: 'export'.
            options: {
              type: 'static',
            },
          }}
        >
          {children}
        </RootProvider>
      </body>
    </html>
  );
}
