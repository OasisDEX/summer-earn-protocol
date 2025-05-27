# Summer Earn Governance Validator

A Next.js application for validating governance proposals for the Summer Earn Protocol with integrated wallet connectivity and cross-chain execution capabilities.

## Features

- **Wallet Integration**: Connect your wallet using RainbowKit with support for multiple chains (Mainnet, Base, Arbitrum, Sonic)
- **Proposal Validation**: Validate governance proposals with calldata decoding
- **Cross-Chain Proposals**: View and execute cross-chain governance proposals
- **Real Execution**: Execute pending cross-chain proposals using timelock controller contracts
- **Modern UI**: Beautiful and responsive interface with Tailwind CSS

## Getting Started

1. Install dependencies:
```bash
pnpm install
```

2. Set up environment variables (optional):
```bash
# Create .env.local file with:
NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=your_project_id_here
```

3. Start the development server:
```bash
pnpm dev
```

4. Open [http://localhost:3000](http://localhost:3000) in your browser

## Pages

- **/** - Main governance proposal validator
- **/cross-chain** - Cross-chain governance proposals with execution capabilities

## Wallet Connection

The app uses RainbowKit for wallet connectivity. Users can connect their wallets to:
- View their account information
- Execute pending cross-chain proposals
- Interact with governance contracts across multiple chains

## Cross-Chain Execution

For pending cross-chain proposals, an "Execute" button is available that:
- Automatically switches to the correct chain
- Calls the timelock controller's `executeBatch` method
- Uses the proposal's targets, values, calldatas, and salt from the subgraph
- Shows loading states and handles errors gracefully

### Supported Chains

- **Mainnet** (Chain ID: 1)
- **Base** (Chain ID: 8453) 
- **Arbitrum** (Chain ID: 42161)
- **Sonic** (Chain ID: 146)

## Configuration

- Update `NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID` in your environment variables with your WalletConnect Cloud project ID
- Timelock controller addresses are automatically loaded from `src/config/index.json`
- Chain configurations include LayerZero endpoints and other protocol-specific settings

## Build

```bash
pnpm build
```

## Technologies Used

- Next.js 14
- RainbowKit
- Wagmi
- Viem
- TanStack Query
- Tailwind CSS
- TypeScript

## Architecture

The application consists of:
- **Frontend**: React components with wallet integration
- **Config**: Chain-specific contract addresses and settings
- **Services**: Subgraph integration for proposal data
- **Execution**: Direct timelock controller interaction for proposal execution

## Form Fields

The form accepts the following inputs:

- **Targets**: Array of Ethereum addresses
- **Values**: Array of integer values (in wei)
- **Calldatas**: Array of bytes data
- **Description**: String description of the proposal

## Development

- Built with Next.js 14
- Uses TypeScript for type safety
- Styled with SCSS modules
- Form validation and state management with React hooks 