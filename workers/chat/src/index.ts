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
// CORS: only the configured ALLOWED_ORIGIN may call /api/chat.
// Rate: rough per-request guardrails on input size and message count.

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
