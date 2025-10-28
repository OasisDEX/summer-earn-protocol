# FleetCommander Subgraph

## Introduction

This subgraph indexes and tracks events from the FleetCommander smart contract, providing easily queryable data for FleetCommander activities on the Ethereum blockchain.

## FleetCommander Functionality

FleetCommander is a smart contract that manages a fleet of "Arks" (yield-generating vaults). Its main functionalities include:

1. **Deposit**: Users can deposit assets into the FleetCommander, which then allocates these assets among various Arks.
2. **Withdraw**: Users can withdraw their assets from the FleetCommander.
3. **Rebalance**: The contract can rebalance assets between different Arks to optimize yield.
4. **Buffer Management**: Maintains a buffer of funds for quick withdrawals.

## Subgraph Purpose

This subgraph tracks two main events:

1. **Deposit**: When users deposit assets into the FleetCommander.
2. **Withdraw**: When users withdraw assets from the FleetCommander.

It creates and updates entities for Vaults, Accounts, and Positions, providing a comprehensive view of the FleetCommander's state and user interactions.

## File Structure

```
src/
├── mappings/
│   ├── fleetCommander.ts         # Main event handlers
│   └── entities/
│       ├── deposit.ts            # Deposit entity creation
│       ├── withdraw.ts           # Withdraw entity creation
│       ├── position.ts           # Position entity updates
│       └── vault.ts              # Vault entity updates
├── utils/
│   ├── position.ts               # Position-related utility functions
│   └── vault.ts                  # Vault-related utility functions
├── types/
│   └── index.ts                  # Custom type definitions
└── common/
    ├── initializers.ts           # Entity initialization functions
    ├── utils.ts                  # General utility functions
    ├── constants.ts              # Subgraph constants
    ├── addressProvider.ts        # Address provider for contract addresses
    └── priceHelpers.ts           # Price-related utility functions
```

## Main Functionality

The subgraph primarily handles two events:

### Deposit

When a Deposit event is emitted:
1. The vault and account entities are created or retrieved.
2. Vault and position details are fetched and updated.
3. The deposit amount is normalized and converted to USD.
4. A new Deposit entity is created with the event details.

### Withdraw

When a Withdraw event is emitted:
1. The vault and account entities are created or retrieved.
2. Vault and position details are fetched and updated.
3. The withdrawal amount is normalized and converted to USD.
4. A new Withdraw entity is created with the event details.

## Usage

To use this subgraph (e.g. on `base` network):

1. Install dependencies: `pnpm i`
2. Generate types: `pnpm run codegen`
3. Build the subgraph: `pnpm run build:base`
4. Deploy the subgraph: `npm run deploy:base`

Query the deployed subgraph using the GraphQL endpoint provided after deployment.

## Example Query

```graphql
{
    deposits(first: 5) {
        id
        amount
        amountUSD
        from
        to
        timestamp
    }
    withdraws(first: 5) {
        id
        amount
        amountUSD
        from
        to
        timestamp
    }
    accounts {
        id
        positions {
            id
            inputTokenBalance
            outputTokenBalance
            outputTokenBalanceNormalized
            outputTokenBalanceNormalizedInUSD
        }
    }
}
```

This query fetches the latest 5 deposits and withdrawals, including their amounts in original tokens and USD.
It also fetches the accounts and their positions, including token balances and normalized balances in USD.

## Contributing

1. Fork the repository
2. Create a new branch (`git checkout -b feat/some-feature`)
3. Make changes and commit them (`git commit -am 'Add some feature'`)
4. Push the branch (`git push origin feat/some-feature`)
5. Create a new Pull Request
6. After your PR is reviewed and merged, your changes will be deployed to the subgraph.

## License

TBD