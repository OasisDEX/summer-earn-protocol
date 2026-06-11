---
description: Networks the Summer.fi Earn Protocol is deployed and configured on.
---

# Supported Networks

The protocol is multi-chain. Fleets and supporting contracts are configured and
deployed across the following EVM networks:

| Network | Role |
|---|---|
| Ethereum mainnet | Governance hub and Fleets |
| Base | Fleets |
| Arbitrum | Fleets |
| Sonic | Fleets |
| HyperEVM (HyperLiquid) | Fleets |
| Optimism | Configured RPC target |

Governance is anchored on a **hub chain** (Ethereum mainnet): SUMR delegation
and proposal voting resolve on the hub, while the SUMR token moves across chains
as a LayerZero OFT and governance messages propagate via the cross-chain layer.

Cross-chain asset movement between Fleets is handled by the `chain-bridge`
package (BridgeRouter + LayerZero/Stargate adapters), not by per-chain vault
proxies.

> **Canonical addresses.** Deployed contract addresses per network live in
> `packages/deployment/deployments/` (e.g. `deployments/fleets/`). Treat that
> directory — not this page — as the source of truth for addresses, and see the
> Security ▸ Deployed Addresses page once published.
