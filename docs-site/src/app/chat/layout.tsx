import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Ask AI · speckit-security',
  description:
    'Ask an AI grounded in the speckit-security docs how the six gates, five hooks, and eight commands work. Perfect for learning spec-driven development end-to-end.',
  alternates: { canonical: '/chat' },
  openGraph: {
    type: 'website',
    title: 'Ask AI · speckit-security',
    description:
      'Grounded docs chat for speckit-security, powered by Llama 3.3 70B on Cloudflare Workers AI.',
    url: '/chat',
  },
};

export default function ChatLayout({ children }: { children: React.ReactNode }) {
  return children;
}
