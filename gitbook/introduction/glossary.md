---
description: Definitions of the core terms used across the Summer.fi Earn Protocol.
---

# Glossary

### Fleet
An ERC-4626 vault that accepts a single underlying asset and allocates it across yield sources. A Fleet is operated by a `FleetCommander`.

### FleetCommander
The contract that orchestrates a Fleet: it accepts deposits/withdrawals, maintains the buffer, and rebalances capital across the Fleet's Arks within governance-set per-Ark deposit caps.

### Ark
An isolated adapter contract that integrates one external yield venue (Aave, Morpho, Pendle, Sky, etc.). Arks expose a uniform interface (board / disembark / harvest). Only the owning FleetCommander can move an Ark's funds.

### BufferArk
A special Ark that holds idle, instantly-withdrawable liquidity for its Fleet. Keepers move funds between the buffer and yield-bearing Arks.

### Board / Disembark
"Board" moves assets into an Ark (deposit into the external venue); "disembark" moves assets out (withdraw from the venue back toward the Fleet).

### Withdrawable (withdrawableTotalAssets)
The portion of an Ark's assets that can currently be withdrawn. This is often **capped by external conditions** (venue liquidity, pause state, withdrawal queues) — an Ark is not necessarily fully liquid on demand.

### Keeper
An authorized off-chain actor that triggers rebalances, harvests, and (for some systems) bridge/queue execution. Keeper permissions are managed by the protocol access layer.

### Rebalance
A keeper-initiated reallocation of a Fleet's assets between its Arks and buffer, constrained by per-Ark deposit caps.

### Tip / Tipper / TipJar
Protocol fees ("tips") accrued from Fleet yield. `Tipper`/`FlexibleTipper` accrue tips; the `TipJar` holds and distributes them via configured tip streams.

### Raft
The contract that collects reward tokens harvested from Arks and routes them toward conversion (auctions / buy-and-burn).

### BuyAndBurn
The mechanism that converts collected rewards/tips (via Dutch auctions) and burns SUMR.

### AdmiralsQuarters
A user-facing bundler/router for deposits and withdrawals across Fleets, with integrated swapping.

### HarborCommand
A registry/coordination contract that tracks FleetCommanders.

### DCA (Dollar-Cost Averaging)
A stateless strategy system (`DCAStrategyManager`) that periodically moves value between two Fleets on a schedule. Strategies are authorized by the hash of their configuration.

### Intent / Solver Bond
An intent expresses a desired yield outcome; bonded solvers compete to fulfill it. Solver bonds (deployed by keepers) are slashable collateral backing solver commitments.

### SUMR
The protocol governance token: an ERC-20 with on-chain voting power (with decay) and LayerZero OFT cross-chain transfer support.

### Voting-power decay
SUMR voting power decays over time toward zero after a decay-free window unless refreshed, discouraging passive accumulation of governance weight.

### SIP (Summer Improvement Proposal)
The governance proposal process by which SUMR holders change protocol parameters and contracts.

### BridgeRouter
The live cross-chain entry point in the `chain-bridge` package: it coordinates inbound/outbound transfers and messages through registered bridge adapters (LayerZero, Stargate), validated by the CrossChainRegistry.

### CrossChainRegistry
The contract that records trusted cross-chain endpoints/executors and validates cross-chain operations.

> **Deprecated:** `CrossChainArk` and `FleetProxy` were earlier cross-chain components and are no longer part of the live system (retained only as `legacy/*.sol.old`). The current cross-chain path is the `chain-bridge` package.
