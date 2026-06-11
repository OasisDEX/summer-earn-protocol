---
description: A map of the Summer.fi Earn Protocol contracts, off-chain services, and how they fit together.
---

# Ecosystem Map

The Summer.fi Earn Protocol spans on-chain contracts, off-chain services, and a
client SDK. At a high level:

```mermaid
flowchart TB
  user([User / Integrator])
  subgraph offchain[Off-chain]
    sdk[SDK<br/>sdk-client]
    keeper[Keepers / Bots]
    subgraphs[(Subgraphs)]
    apis[[HTTP APIs]]
  end
  subgraph onchain[On-chain]
    aq[AdmiralsQuarters<br/>router]
    fc[FleetCommander<br/>ERC-4626 Fleet]
    buffer[BufferArk]
    arks[Arks<br/>Aave / Morpho / Pendle / Sky / ...]
    tip[Tipper / TipJar]
    raft[Raft -> BuyAndBurn]
    gov[SummerGovernor + SUMR]
    bridge[chain-bridge<br/>BridgeRouter + adapters]
  end

  user --> sdk --> aq --> fc
  keeper --> fc
  fc --> buffer
  fc --> arks
  arks --> raft
  fc --> tip --> raft
  gov -. parameters / caps .-> fc
  bridge <-. cross-chain transfers .-> fc
  subgraphs -. index events .- fc
  sdk --> apis
```

### On-chain
- **Fleets & Arks** — `FleetCommander` vaults allocate deposits across `Ark` adapters; `BufferArk` holds instant liquidity. See [Protocol Concepts](../concepts/fleets-and-arks.md).
- **Fees & buy-and-burn** — `Tipper`/`TipJar` accrue protocol tips; `Raft` collects Ark rewards; `BuyAndBurn` converts and burns SUMR.
- **Governance** — `SummerGovernor` + the `SUMR` token govern the protocol cross-chain. See [Governance](../governance/overview.md).
- **Cross-chain** — the `chain-bridge` package moves assets and messages between chains. See [Cross-Chain](../cross-chain/overview.md).

### Off-chain
- **SDK** (`@summer_fi/sdk-client`) — the supported way to read protocol state and build transactions. Documented in the **SDK** section of this docs site.
- **Keepers/bots** — trigger rebalances, harvests, and bridge execution.
- **Subgraphs & HTTP APIs** — index protocol events and expose rates/portfolio/APY data.

### Two repositories
- **summer-earn-protocol** — Solidity contracts, deployment, subgraphs, keeper tooling. (This space's contract reference is generated from its NatSpec.)
- **summerfi-monorepo** — the TypeScript SDK, apps, and backend services. (The SDK API reference is generated from its TSDoc.)
