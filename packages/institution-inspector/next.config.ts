import type { NextConfig } from 'next'

// Hosted deploys (AWS Amplify, platform WEB — see infrastructure/main.tf) set
// NEXT_PUBLIC_STATIC_EXPORT=1 to emit a fully static site (output: 'export'). The viewer
// only renders the committed data/*.json snapshots, so it needs no server runtime — a
// static export produces zero serverless functions. Local dev/build leave this unset and
// keep the full SSR server + the on-chain /api/refresh route.
const staticExport = process.env.NEXT_PUBLIC_STATIC_EXPORT === '1'

const nextConfig: NextConfig = {
  ...(staticExport ? { output: 'export' } : {}),
  // Keep the dev-only indicator out of the bottom-left, where the graph's zoom controls live.
  devIndicators: {
    position: 'bottom-right',
  },
}

export default nextConfig
