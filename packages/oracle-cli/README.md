# Summer Earn Oracle CLI

A TypeScript-based CLI and suite of tools for managing and operating Summer Earn RWA Oracles.

## Features

- **Automated Deployment**: Deploy `OracleRegistry` and `RwaOracle` contracts using validated JSON input.
- **Oracle Node Daemon**: Run a long-lived process that monitors price deviation and heartbeats, automatically triggering on-chain updates when needed.
- **WisdomTree Integration**: Securely connect to WisdomTree Connect API and DataSpan Fund NAV API.
- **Trend Visualization**: Download historical NAV data and view trend charts directly in the terminal.
- **Management Tools**: Add/remove signers, update thresholds, and manage the Oracle Registry.
- **Multi-Network Support**: Pre-configured for Base, Arbitrum, and Ethereum.

## Setup

1. **Install Dependencies**:
   ```bash
   pnpm install
   ```

2. **Configure Environment**:
   Create a `.env` file in the repo root (or this package):
   ```env
   # RPC & Deployment
   BASE_RPC_URL=https://mainnet.base.org
   ARBITRUM_RPC_URL=https://arb1.arbitrum.io/rpc
   MAINNET_RPC_URL=https://eth.llamarpc.com
   DEPLOYER_PRIVATE_KEY=0x...
   PRIVATE_KEYS=0x_signer1,0x_signer2,... # Comma-separated for the node/updater

   # WisdomTree Connect API
   WT_CLIENT=your_client_id
   WT_SECRET=your_client_secret
   WT_LOGIN=your_login
   WT_PASSWORD=your_password
   ```
   The CLI loads `.env` from the repo root first, then from this package.

## Usage

### 1. Deploying Oracles

Edit `deploy-input.json` (supports single objects or arrays for batch deployment):
```json
[
  {
    "network": "base",
    "assetAddress": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
    "signers": ["0x..."],
    "threshold": 1
  }
]
```

Run deployment:
```bash
pnpm deploy
```
*Note: This automatically fetches the asset symbol as the ticker and updates `deployments.json`.*

### 2. WisdomTree Operations

Connect to WisdomTree Connect API:
```bash
# Get organization details & wallets
pnpm cli wt-me

# List all available tickers from deployments
pnpm cli wt-tickers

# Fetch On-Receipt wallets for all or a specific oracle
pnpm cli wt-wallets [ticker]

# Manage orders
pnpm cli wt-orders
pnpm cli wt-order <order_reference>

# View open accruals
pnpm cli wt-accruals [organisation_guid]
```

### 3. Fund NAV Data (DataSpan API)

Fetch latest or historical NAV data (uses Playwright to bypass Cloudflare and caches results):
```bash
# Fetch latest NAV
pnpm cli wt-data WTSYX

# Fetch historical NAV (caches to .wt-nav-cache/)
pnpm cli wt-data WTSYX 2025-05-06

# View trend chart of NAV over a range
pnpm cli wt-data-range CRDYX 2026-03-01 2026-03-09
```

### 4. Running an Oracle Node (Daemon)

To monitor a ticker and update prices based on a 0.5% deviation or 24h heartbeat:
```bash
pnpm cli start SPXUX --deviation 0.5 --heartbeat 86400
```

### 5. Manual Updates & Management

Update price once:
```bash
pnpm cli update SPXUX
```

Set a registry entry manually:
```bash
pnpm cli registry-set TICKER ASSET_ADDR ORACLE_ADDR
```

Manage signers:
```bash
pnpm cli add-signer <ORACLE_ADDR> <SIGNER_ADDR>
pnpm cli set-threshold <ORACLE_ADDR> <THRESHOLD>
```

## Internal Configuration

The CLI uses `src/deployments.json` to track the `OracleRegistry` address for each network. This file is shared with the Dashboard.
