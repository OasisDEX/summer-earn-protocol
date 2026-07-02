---
description: External dependencies of the Summer.fi Earn Protocol and the trust and failure assumptions each one imposes — messaging, rewards, oracles, and the underlying Ark venues.
---

# Trust Assumptions

The protocol composes with several external systems. Each adds capability and a corresponding trust assumption and failure mode. The integrations below are confirmed by source references under `packages/*/src`; the operational risk characterisation of each third party is the reviewer's to weigh.

## LayerZero (cross-chain governance messaging)

Used by the cross-chain governance path (`SummerGovernorV2`, `ISummerGovernorV2`, `ISummerToken`) for relaying finalized proposals from the hub chain to satellite chains, and as the OFT transport for the SUMR token.

- **Trust assumption.** LayerZero's endpoints, configured DVNs/libraries and executors deliver messages faithfully and exactly once.
- **Failure mode.** A compromised or buggy DVN/executor set could deliver forged or replayed messages, or censor delivery. Censorship of governance relays would stall satellite-chain execution but not corrupt hub-chain voting; only configured peers are honoured.

## Stargate (StargateV2PoolArk)

Used by `StargateV2PoolArk` plus the Stargate interfaces under `core-contracts/src/interfaces/stargate/`, which deposits the underlying asset into a Stargate V2 pool as a yield venue.

- **Trust assumption.** Stargate pools/routers hold and release assets correctly and remain solvent.
- **Failure mode.** A Stargate pool exploit, depeg, or liquidity shortfall could strand or lose the Ark's deposited assets, like any other Ark venue dependency.

## Merkl and other reward distributors

Arks and bundlers claim third-party incentives through reward distributors: `merkl/IDistributor`, `morpho/IUniversalRewardsDistributor`, `fluid/IFluidMerkleDistributor`, surfaced via `Ark` and `AdmiralsQuarters`(`Whitelist`).

- **Trust assumption.** The distributor's Merkle roots reflect entitlements correctly and the distributor remains solvent in the reward token.
- **Failure mode.** A wrong/malicious root or insolvent distributor affects only claimable rewards, not principal held in the Ark. Claiming is a keeper/operator action and rewards flow into the protocol's accounting via the Raft/harvest path.

## Chainlink and RWA oracles

Price feeds are consumed via `AggregatorV3Interface` (`core-contracts/src/interfaces/external/Chainlink/`), `ChainlinkOracleUtils`, and the bespoke `RwaOracle` (`packages/rwa-oracles/src/`). Consumers include `WisdomTreeArk`, `BaseSuperstateArk`, `DCAStrategyManager`, and the Pendle oracle Arks.

- **Trust assumption.** Feeds report timely, accurate prices and the RWA oracle's off-chain inputs are honest.
- **Failure mode.** Stale or manipulated prices could misvalue Ark holdings, affecting share pricing, rebalancing decisions, and slippage checks. RWA oracles additionally depend on a trusted off-chain price source. Reviewers should check staleness/round validation in `ChainlinkOracleUtils` and the freshness controls on `RwaOracle` for each consuming Ark.

## Underlying Ark venues (~40 integrations)

There are 41 Ark implementations under `packages/core-contracts/src/contracts/arks/`, each integrating a distinct yield venue — among them Aave V3, Compound V3, Morpho (vault / V2), Spark, Sky/USDS, Silo, Fluid, Moonwell, Pendle (PT/LP/oracle), Origin (ETH/USD/SuperOETH), Maple/Syrup, Superstate, WisdomTree (BENJI), Aera, Arm, Stargate V2, Upshift, generic ERC-4626, and others.

- **Trust assumption.** Each underlying protocol behaves per its documented interface, stays solvent, and honours redemptions. Custodial/RWA Arks (e.g. WisdomTree, Superstate, Maple) additionally trust an off-chain custodian to honour subscription/redemption requests.
- **Failure mode.** A venue exploit, bad-debt event, depeg, withdrawal gate, or custodian default can impair or freeze the funds that Ark holds. Blast radius is bounded per Ark by curator-set per-Ark caps (max deposit % of TVL, rebalance inflow/outflow) and by the Fleet's minimum buffer — so a single venue failure is contained to the assets allocated to that Ark.
- **Async/custodial pattern.** Many Arks settle withdrawals asynchronously (request → claim) under keeper control, and venue references are `immutable` (see [Upgradeability](upgradeability.md)). Onboarding or replacing a venue requires deploying a new Ark and a governor-gated `addArk`.

## Standard library and tooling assumptions

- **OpenZeppelin contracts** — `AccessControl`, `TimelockController`, `Pausable`, `ReentrancyGuard`, `SafeERC20` are used directly. Trust is the standard assumption that the pinned OZ version is unmodified and audited.
- **ERC-20 token behaviour** — Arks and Fleets assume the underlying assets behave as standard ERC-20s; non-standard tokens (fee-on-transfer, rebasing) would need to be validated per integration before onboarding.

> TODO (human input): Provide the canonical per-chain list of which external protocol versions and oracle feed addresses each live Ark depends on, and the custodian counterparties for the off-chain/RWA Arks. These resolve against the deployment manifests in `packages/deployment/deployments/` and operational agreements, not source.
