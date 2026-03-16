# Summer Earn RWA Oracle Contracts

Smart contracts for the Summer Earn RWA Oracle system, providing Chainlink-compatible price feeds for Real-World Assets.

## Overview

### `RwaOracle.sol`
A robust, multi-sig secured oracle implementation:
- **Chainlink Compatible**: Implements `AggregatorV3Interface`.
- **Multi-Sig Security**: Requires `M-of-N` signatures for every price update.
- **Replay Protection**: Uses a contract-level `nonce` and `chainId` in every signed message.
- **Freshness Enforced**: Enforces monotonic timestamp updates.

### `OracleRegistry.sol`
A central discovery layer for the protocol:
- **Two-Way Lookup**: Find oracles by `Ticker` (e.g., "SPXUX") or by `Asset Address`.
- **Reverse Discovery**: Map oracle addresses back to their metadata (Ticker and Asset).
- **Owner Controlled**: Only the registry owner can map new oracles.

## Development

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation)

### Build & Test
```bash
# Compile contracts
forge build

# Run tests
forge test
```

### Deployment
Deployment is primarily handled via the `@summerfi/oracle-cli` package using `viem` for automated registration. For manual deployments, a Forge script is available in `scripts/DeployRwaOracle.s.sol`.

## Interface Reference
The oracles are designed to be consumed by standard Chainlink tools. The `latestRoundData()` function returns:
- `roundId`: Incremental ID for the update.
- `answer`: Price in USD (8 decimals).
- `startedAt`: Timestamp of the update.
- `updatedAt`: Same as `startedAt`.
- `answeredInRound`: Same as `roundId`.