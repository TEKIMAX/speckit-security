import { source } from '@/lib/source';
import { createFromSource } from 'fumadocs-core/search/server';

// Use the static GET handler so the index is generated at build time
// and served as a plain JSON file. Required for `output: 'export'`.
// The client-side search dialog loads this URL at runtime.
export const { staticGET: GET } = createFromSource(source, {
  language: 'english',
});

export const dynamic = 'force-static';
export const revalidate = false;
