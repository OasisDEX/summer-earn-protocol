# Summer Earn Oracle Dashboard

A Next.js monitoring interface for the Summer Earn RWA Oracle system.

## Features

- **Real-time Monitoring**: Automatically refreshes oracle data every 60 seconds.
- **On-Chain vs Off-Chain Comparison**: Compares live contract data with source APIs (WisdomTree).
- **Health Indicators**: Visually flags stale or mismatched oracles.
- **Cross-Chain Discovery**: Automatically switches registry context based on the detected network.

## Getting Started

1. **Install Dependencies**:
   ```bash
   pnpm install
   ```

2. **Configure Network**:
   The dashboard uses `lib/deployments.json` to find the `OracleRegistry` for each network. Ensure this file is synced with the latest deployments from the CLI package.

3. **Run Locally**:
   ```bash
   pnpm dev
   ```

4. **Build for Production**:
   ```bash
   pnpm build
   ```

## Technical Architecture

- **Framework**: Next.js 16 (App Router)
- **Styling**: Tailwind CSS
- **Blockchain Interaction**: `viem`
- **Icons**: Lucide React

## Data Fetching Logic

The dashboard performs the following for each tracked ticker:
1. Resolves the `RwaOracle` address via the network-specific `OracleRegistry`.
2. Fetches `latestRoundData()` from the contract.
3. Fetches the latest NAV from the WisdomTree public API.
4. Calculates deviation and freshness to determine the "Health" status.