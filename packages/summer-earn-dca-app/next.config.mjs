import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

/** @type {import('next').NextConfig} */
const nextConfig = {
  outputFileTracingRoot: path.join(__dirname, '../../'),
  experimental: {
    // Enables the `'use cache'` directive + cacheLife/cacheTag from
    // next/cache. Migrating to top-level cacheComponents (Next 16 stable)
    // needs Suspense boundaries around every dynamic client subtree —
    // separate refactor.
    useCache: true,
  },
}

export default nextConfig
