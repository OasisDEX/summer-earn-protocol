import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

/** @type {import('next').NextConfig} */
const nextConfig = {
  outputFileTracingRoot: path.join(__dirname, '../../'),
  experimental: {
    // Opt in to the `'use cache'` directive + `cacheLife`/`cacheTag` from
    // `next/cache`. Used by:
    //   - src/app/api/prices/[chainId]/[token]/route.ts (public price API)
    //   - src/lib/prices/cached.ts (shared cache entry)
    //   - src/lib/server/loadStrategyDetail.ts (RSC pre-resolver)
    //
    // TODO(next-16): migrate to top-level `cacheComponents: true` for PPR.
    // That mode requires <Suspense> boundaries around every dynamic client
    // subtree (Sidebar, Providers, RPC-driven hooks) — non-trivial layout
    // refactor. Sticking with the deprecated-but-still-working flag until
    // we do that pass.
    useCache: true,
  },
}

export default nextConfig
