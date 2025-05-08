/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  swcMinify: true,
  webpack: (config) => {
    // This allows importing JSON files directly
    config.module.rules.push({
      test: /\.json$/,
      type: 'json',
    })

    return config
  },
}

module.exports = nextConfig
