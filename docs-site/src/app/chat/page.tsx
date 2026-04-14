'use client';

import { useEffect, useRef, useState } from 'react';
import Link from 'next/link';

type Role = 'user' | 'assistant';
type Message = { role: Role; content: string };

const STARTER_QUESTIONS = [
  'What are the six gates and which ones block implementation?',
  'How do the five phase hooks wire into Spec Kit?',
  'What does Gate F actually scan for?',
  'How do I customize the secret patterns for my own stack?',
  'Why is the extension TypeScript-opinionated?',
  'What does speckit-security NOT do?',
];

// Default is a same-origin path. A Cloudflare Worker Route on
// speckit.tekimax.com/api/chat* routes this to the chat Worker.
// Override with NEXT_PUBLIC_CHAT_ENDPOINT for local dev against
// the workers.dev URL.
const CHAT_ENDPOINT =
  process.env.NEXT_PUBLIC_CHAT_ENDPOINT || '/api/chat';

export default function ChatPage() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    scrollRef.current?.scrollTo({
      top: scrollRef.current.scrollHeight,
      behavior: 'smooth',
    });
  }, [messages]);

  async function sendMessage(text: string) {
    if (!text.trim() || busy) return;
    setError(null);
    const userMsg: Message = { role: 'user', content: text.trim() };
    const nextMessages = [...messages, userMsg];
    setMessages([...nextMessages, { role: 'assistant', content: '' }]);
    setInput('');
    setBusy(true);

    try {
      const res = await fetch(CHAT_ENDPOINT, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ messages: nextMessages }),
      });

      if (!res.ok || !res.body) {
        const errText = await res.text().catch(() => '');
        throw new Error(`HTTP ${res.status}${errText ? `: ${errText}` : ''}`);
      }

      const reader = res.body.getReader();
      const decoder = new TextDecoder();
      let buffer = '';
      let acc = '';

      while (true) {
        const { value, done } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });

        // Workers AI streams SSE: `data: {...}\n\n` lines
        const lines = buffer.split('\n');
        buffer = lines.pop() || '';

        for (const line of lines) {
          const trimmed = line.trim();
          if (!trimmed.startsWith('data:')) continue;
          const payload = trimmed.slice(5).trim();
          if (payload === '[DONE]') continue;
          try {
            const parsed = JSON.parse(payload);
            const chunk =
              parsed.response ??
              parsed.output_text ??
              parsed.choices?.[0]?.delta?.content ??
              '';
            if (chunk) {
              acc += chunk;
              setMessages((prev) => {
                const copy = [...prev];
                copy[copy.length - 1] = { role: 'assistant', content: acc };
                return copy;
              });
            }
          } catch {
            // Non-JSON keepalive — ignore
          }
        }
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'chat request failed');
      setMessages((prev) => prev.slice(0, -1));
    } finally {
      setBusy(false);
    }
  }

  function reset() {
    setMessages([]);
    setError(null);
  }

  return (
    <main className="flex flex-col flex-1 min-h-[calc(100vh-4rem)] max-w-4xl mx-auto w-full px-6 py-12">
      <header className="mb-8">
        <div className="inline-flex items-center gap-2 rounded-full border border-fd-border bg-fd-card px-4 py-1.5 text-xs font-medium text-fd-muted-foreground mb-4">
          <span className="h-2 w-2 rounded-full bg-emerald-400" />
          <span>Ask AI</span>
          <span>·</span>
          <span>Llama 3.3 70B on Cloudflare Workers AI</span>
        </div>
        <h1 className="text-3xl sm:text-4xl font-bold tracking-tight mb-3">
          Ask the docs anything
        </h1>
        <p className="text-fd-muted-foreground leading-relaxed max-w-2xl">
          Grounded in every page of the speckit-security docs. Answers cite
          page URLs so you can jump to the source. Answers are bounded by
          what&rsquo;s actually in the docs — if it isn&rsquo;t there, the
          model will say so rather than guess.
        </p>
      </header>

      <div
        ref={scrollRef}
        className="flex-1 overflow-y-auto rounded-2xl border border-fd-border bg-fd-card/40 p-6 mb-4 min-h-[400px] max-h-[60vh]"
      >
        {messages.length === 0 ? (
          <div>
            <p className="text-sm font-semibold uppercase tracking-wider text-fd-muted-foreground mb-4">
              Try one of these
            </p>
            <div className="grid sm:grid-cols-2 gap-2">
              {STARTER_QUESTIONS.map((q) => (
                <button
                  key={q}
                  onClick={() => sendMessage(q)}
                  disabled={busy}
                  className="text-left rounded-lg border border-fd-border bg-fd-card hover:bg-fd-accent transition px-4 py-3 text-sm disabled:opacity-50"
                >
                  {q}
                </button>
              ))}
            </div>
          </div>
        ) : (
          <div className="space-y-6">
            {messages.map((m, i) => (
              <div
                key={i}
                className={
                  m.role === 'user'
                    ? 'flex justify-end'
                    : 'flex justify-start'
                }
              >
                <div
                  className={
                    m.role === 'user'
                      ? 'max-w-[80%] rounded-2xl bg-fd-primary px-4 py-3 text-sm text-fd-primary-foreground whitespace-pre-wrap'
                      : 'max-w-[85%] rounded-2xl border border-fd-border bg-fd-background px-4 py-3 text-sm whitespace-pre-wrap'
                  }
                >
                  {m.content || (
                    <span className="inline-flex gap-1 text-fd-muted-foreground">
                      <span className="animate-pulse">●</span>
                      <span className="animate-pulse [animation-delay:120ms]">●</span>
                      <span className="animate-pulse [animation-delay:240ms]">●</span>
                    </span>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {error ? (
        <div className="mb-3 rounded-lg border border-red-500/40 bg-red-500/10 px-4 py-2 text-sm text-red-300">
          {error}
        </div>
      ) : null}

      <form
        onSubmit={(e) => {
          e.preventDefault();
          sendMessage(input);
        }}
        className="flex items-center gap-2"
      >
        <input
          value={input}
          onChange={(e) => setInput(e.target.value)}
          placeholder="Ask about gates, hooks, commands, customization, SDD…"
          disabled={busy}
          className="flex-1 rounded-lg border border-fd-border bg-fd-card px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-fd-primary/40 disabled:opacity-50"
        />
        <button
          type="submit"
          disabled={busy || !input.trim()}
          className="rounded-lg bg-fd-primary px-5 py-3 text-sm font-semibold text-fd-primary-foreground hover:opacity-90 transition disabled:opacity-40"
        >
          {busy ? 'Thinking…' : 'Send'}
        </button>
        {messages.length > 0 ? (
          <button
            type="button"
            onClick={reset}
            disabled={busy}
            className="rounded-lg border border-fd-border bg-fd-card px-4 py-3 text-sm text-fd-muted-foreground hover:text-fd-foreground transition"
          >
            Reset
          </button>
        ) : null}
      </form>

      <footer className="mt-6 text-xs text-fd-muted-foreground">
        <p>
          Answers come from Llama 3.3 70B grounded in{' '}
          <Link href="/docs" className="underline hover:text-fd-foreground">
            the docs
          </Link>
          . The model is instructed to cite page URLs and to say when
          something isn&rsquo;t covered. Always double-check critical
          recommendations against the source docs before acting on them.
        </p>
      </footer>
    </main>
  );
}
