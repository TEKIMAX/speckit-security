// speckit-security docs chat Worker
//
// POST /api/chat
//   { "messages": [{ "role": "user" | "assistant", "content": "..." }, ...] }
//
// Streams back the model's reply using Cloudflare Workers AI
// (Llama 3.3 70B Instruct FP8 Fast). The entire docs corpus is
// embedded as the system prompt so the model answers from grounded
// context only.
//
// Defenses, in order:
//   1. CORS origin allowlist (ALLOWED_ORIGIN + localhost:3xxx)
//   2. Input validation (message count, per-message size, total size)
//   3. Upstash Ratelimit sliding window by client IP (20 req / 60s)
//   4. Workers AI free tier + Cloudflare spend cap as final backstop

import { Ratelimit } from '@upstash/ratelimit';
import { Redis } from '@upstash/redis/cloudflare';
import { DOCS_CONTEXT, DOCS_CONTEXT_BYTES } from './context.generated';

type ChatRole = 'user' | 'assistant' | 'system';
interface ChatMessage {
  role: ChatRole;
  content: string;
}
interface ChatRequest {
  messages: ChatMessage[];
}

interface Env {
  AI: Ai;
  ALLOWED_ORIGIN: string;
  // Set via `wrangler secret put UPSTASH_REDIS_REST_URL` and
  // `wrangler secret put UPSTASH_REDIS_REST_TOKEN`. If either is
  // missing the rate limiter fails open with a console warning so
  // a fresh deploy still works while you configure secrets.
  UPSTASH_REDIS_REST_URL?: string;
  UPSTASH_REDIS_REST_TOKEN?: string;
}

// Rate limiter is created once per isolate, not per request.
// @upstash/ratelimit is stateless across requests; the state lives
// in Upstash Redis.
let ratelimit: Ratelimit | null = null;
function getRatelimit(env: Env): Ratelimit | null {
  if (ratelimit) return ratelimit;
  if (!env.UPSTASH_REDIS_REST_URL || !env.UPSTASH_REDIS_REST_TOKEN) {
    console.warn(
      'upstash rate limiter disabled: UPSTASH_REDIS_REST_URL or UPSTASH_REDIS_REST_TOKEN not set',
    );
    return null;
  }
  const redis = new Redis({
    url: env.UPSTASH_REDIS_REST_URL,
    token: env.UPSTASH_REDIS_REST_TOKEN,
  });
  ratelimit = new Ratelimit({
    redis,
    limiter: Ratelimit.slidingWindow(20, '60 s'),
    analytics: true,
    prefix: 'speckit-chat',
  });
  return ratelimit;
}

function clientIdentifier(request: Request): string {
  // Cloudflare injects the real client IP here; trusted because
  // this Worker only runs inside CF's own edge.
  return request.headers.get('CF-Connecting-IP') || 'anon';
}

const MODEL = '@cf/meta/llama-3.3-70b-instruct-fp8-fast';
const MAX_MESSAGES = 20;
const MAX_USER_CHARS = 4000;
const MAX_TOTAL_CHARS = 20000;

const SYSTEM_PROMPT = `You are the speckit-security documentation assistant.

You help users learn spec-driven development and the speckit-security
Spec Kit extension inside out. Your only source of truth is the
grounding corpus below. Follow these rules strictly:

1. Answer from the corpus. If the corpus doesn't cover the question,
   say so plainly. Do not invent features, commands, config keys,
   file paths, or hook names that aren't in the corpus.
2. Cite the page URL when you reference specific content
   (e.g., "See /docs/how-it-works for the full gate list").
3. Prefer short, direct answers. Use bullet lists for enumerations
   (commands, gates, hooks, config keys). Use fenced code blocks
   for shell commands, YAML snippets, and file paths.
4. When the user asks "how do I...", give concrete steps grounded
   in the corpus. When they ask "why...", explain the design
   rationale from the docs.
5. speckit-security is ONE LAYER of a broader security program, not
   a complete solution. Reinforce this when relevant — users should
   combine it with SAST, dependency scanning, runtime monitoring,
   and their existing compliance tooling.
6. You do not have access to the user's project, their Spec Kit
   installation, or any runtime state. You can only reason about
   the docs.

--- GROUNDING CORPUS (${DOCS_CONTEXT_BYTES} bytes) ---

${DOCS_CONTEXT}

--- END CORPUS ---`;

function corsHeaders(origin: string): HeadersInit {
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Max-Age': '86400',
    Vary: 'Origin',
  };
}

function originAllowed(req: Request, allowed: string): string | null {
  const origin = req.headers.get('Origin');
  if (!origin) return null;
  // Allow the configured production origin and common local dev
  // origins (localhost ports 3000–3999) so `pnpm dev` works against
  // the deployed worker.
  if (origin === allowed) return origin;
  if (/^https?:\/\/localhost:3\d{3}$/.test(origin)) return origin;
  if (/^https?:\/\/127\.0\.0\.1:3\d{3}$/.test(origin)) return origin;
  return null;
}

function validate(req: ChatRequest): string | null {
  if (!req || !Array.isArray(req.messages)) return 'missing messages';
  if (req.messages.length === 0) return 'messages is empty';
  if (req.messages.length > MAX_MESSAGES)
    return `too many messages (max ${MAX_MESSAGES})`;

  let total = 0;
  for (const m of req.messages) {
    if (typeof m.content !== 'string') return 'message content must be string';
    if (m.role !== 'user' && m.role !== 'assistant')
      return `invalid role: ${m.role}`;
    if (m.content.length > MAX_USER_CHARS)
      return `message too long (max ${MAX_USER_CHARS} chars)`;
    total += m.content.length;
  }
  if (total > MAX_TOTAL_CHARS)
    return `total message length too large (max ${MAX_TOTAL_CHARS} chars)`;

  // Last message must be from the user — otherwise there's nothing
  // to answer.
  if (req.messages[req.messages.length - 1].role !== 'user')
    return 'last message must be from user';
  return null;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    // Preflight
    if (request.method === 'OPTIONS') {
      const allowedOrigin = originAllowed(request, env.ALLOWED_ORIGIN);
      if (!allowedOrigin) return new Response(null, { status: 403 });
      return new Response(null, { status: 204, headers: corsHeaders(allowedOrigin) });
    }

    // Health check
    if (request.method === 'GET' && url.pathname === '/health') {
      return new Response(
        JSON.stringify({
          ok: true,
          model: MODEL,
          corpus_bytes: DOCS_CONTEXT_BYTES,
        }),
        { headers: { 'Content-Type': 'application/json' } },
      );
    }

    if (request.method !== 'POST' || url.pathname !== '/api/chat') {
      return new Response('Not found', { status: 404 });
    }

    const allowedOrigin = originAllowed(request, env.ALLOWED_ORIGIN);
    if (!allowedOrigin) {
      return new Response(JSON.stringify({ error: 'origin not allowed' }), {
        status: 403,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    let body: ChatRequest;
    try {
      body = (await request.json()) as ChatRequest;
    } catch {
      return new Response(JSON.stringify({ error: 'invalid JSON' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', ...corsHeaders(allowedOrigin) },
      });
    }

    const validationError = validate(body);
    if (validationError) {
      return new Response(JSON.stringify({ error: validationError }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', ...corsHeaders(allowedOrigin) },
      });
    }

    // Rate limit by client IP. Fails open if Upstash isn't
    // configured yet — the fresh-deploy path still works.
    const rl = getRatelimit(env);
    if (rl) {
      const identifier = clientIdentifier(request);
      const { success, limit, remaining, reset } = await rl.limit(identifier);
      if (!success) {
        const retryAfter = Math.max(1, Math.ceil((reset - Date.now()) / 1000));
        return new Response(
          JSON.stringify({
            error: 'rate limit exceeded',
            retry_after_seconds: retryAfter,
          }),
          {
            status: 429,
            headers: {
              'Content-Type': 'application/json',
              'Retry-After': String(retryAfter),
              'X-RateLimit-Limit': String(limit),
              'X-RateLimit-Remaining': String(remaining),
              'X-RateLimit-Reset': String(reset),
              ...corsHeaders(allowedOrigin),
            },
          },
        );
      }
    }

    // Prepend the system prompt with the grounding corpus.
    const messages: ChatMessage[] = [
      { role: 'system', content: SYSTEM_PROMPT },
      ...body.messages,
    ];

    // Stream the completion so the UI can render tokens as they arrive.
    const aiResponse = (await env.AI.run(MODEL, {
      messages,
      stream: true,
      max_tokens: 1024,
      temperature: 0.2,
    })) as ReadableStream;

    return new Response(aiResponse, {
      headers: {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        Connection: 'keep-alive',
        ...corsHeaders(allowedOrigin),
      },
    });
  },
};
