import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

/** @type {import('next').NextConfig} */
const nextConfig = {
  outputFileTracingRoot: path.join(__dirname, '../../'),
  experimental: {
    // Opt in to the `'use cache'` directive + `cacheLife`/`cacheTag` from
    // `next/cache`. Used by `src/app/api/prices/[chainId]/[token]/route.ts`
    // to front the price-data layer with a shared server cache.
    useCache: true,
  },
}

export default nextConfig
