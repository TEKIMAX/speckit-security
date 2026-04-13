import { createMDX } from 'fumadocs-mdx/next';

const withMDX = createMDX();

/** @type {import('next').NextConfig} */
const config = {
  reactStrictMode: true,
  // Static export for deployment to Cloudflare Pages, Netlify, S3, etc.
  output: 'export',
  images: {
    unoptimized: true,
  },
  // Trailing slashes keep static hosts happy — every page becomes a
  // directory with an index.html so clean URLs work without rewrites.
  trailingSlash: true,
};

export default withMDX(config);
