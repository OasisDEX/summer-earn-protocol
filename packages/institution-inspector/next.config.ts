import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  // Keep the dev-only indicator out of the bottom-left, where the graph's zoom controls live.
  devIndicators: {
    position: 'bottom-right',
  },
}

export default nextConfig
