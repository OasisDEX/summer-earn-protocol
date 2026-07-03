---
description: >-
  Documentation for the Summer.fi Earn Protocol — smart contracts, SDK,
  subgraphs and APIs.
---

# What is the Summer.fi Earn Protocol

The Summer.fi Earn Protocol is an automated yield-optimization protocol. User
deposits are managed by **Fleets** — ERC-4626 vaults orchestrated by a
`FleetCommander` contract — which allocate capital across **Arks**, isolated
adapters integrating external yield protocols (Aave, Morpho, Pendle, Sky and
many others). Keepers rebalance allocations within governance-set caps, and the
**SUMR** token governs the protocol cross-chain.

> This space is under construction: it is being assembled from the protocol
> repositories. Generated reference sections are produced directly from the
> Solidity NatSpec and SDK TSDoc and must not be edited by hand.
