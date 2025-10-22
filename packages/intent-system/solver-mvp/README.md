# Summer Earn Protocol Interface

A simple interface for interacting with the Summer Earn Protocol.

## Features

- Connect wallet using RainbowKit
- View all available fleets (ERC4626 vaults) from Harbor Command
- View fleet details including total assets and withdrawable assets
- Deposit and withdraw from fleets
- View all arks for each fleet
- Rebalance assets between arks (for keepers)

## Getting Started

### Prerequisites

- Node.js 16+
- npm or yarn

### Installation

```bash
# Install dependencies
npm install
```

### Development

```bash
# Run the development server
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) with your browser to see the result.

### Build

```bash
# Build the app for production
npm run build
```

## Architecture

- Built with Next.js, React, TypeScript, and Tailwind CSS
- Uses RainbowKit and wagmi for wallet connection
- Uses viem for blockchain interactions
- Implements multicall for efficient data fetching

## Supported Chains

- Ethereum (Mainnet)
- Arbitrum
- Base
- Sonic

This project uses [`next/font`](https://nextjs.org/docs/app/building-your-application/optimizing/fonts) to automatically optimize and load [Geist](https://vercel.com/font), a new font family for Vercel.

## Learn More

To learn more about Next.js, take a look at the following resources:

- [Next.js Documentation](https://nextjs.org/docs) - learn about Next.js features and API.
- [Learn Next.js](https://nextjs.org/learn) - an interactive Next.js tutorial.

You can check out [the Next.js GitHub repository](https://github.com/vercel/next.js) - your feedback and contributions are welcome!

## Deploy on Vercel

The easiest way to deploy your Next.js app is to use the [Vercel Platform](https://vercel.com/new?utm_medium=default-template&filter=next.js&utm_source=create-next-app&utm_campaign=create-next-app-readme) from the creators of Next.js.

Check out our [Next.js deployment documentation](https://nextjs.org/docs/app/building-your-application/deploying) for more details.
