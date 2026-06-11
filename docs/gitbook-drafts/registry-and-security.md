---
description: The CrossChainRegistry validation model, executor and adapter-peer registration, pause and guardian controls, and the trust assumptions placed on LayerZero and Stargate.
---

# Registry and Security

The [`CrossChainRegistry`](reference/contracts/cross-chain-registry.md) is the governance-managed source of truth that the BridgeRouter and adapters consult to decide who may initiate operations and which remote contracts are trusted. It is the security backbone of the cross-chain system.

## Relationship model

The registry stores typed relationships between a source contract and a target contract, scoped by source and target chain IDs (both `uint16`). It ships with three relationship-type constants, each the `keccak256` of its name:

- `PEER_RELATIONSHIP` — links a local bridge adapter to its trusted peer adapter on another chain.
- `EXECUTOR_RELATIONSHIP` — marks a contract as an authorized executor of the local BridgeRouter.
- `ARK_FLEET_RELATIONSHIP` — a relationship type retained for the (now deprecated) ark/fleet pairing.

Every relationship must touch the deployment chain: `_registerRelationship` reverts with `InvalidChainRelationship` unless either `sourceChainId` or `targetChainId` equals the registry's `CURRENT_CHAIN_ID`. Registration is unique per `(sourceContract, relationshipType, targetChainId)`, and inter-chain relationships also enforce reverse-lookup uniqueness.

Key reads used at runtime:

- `getSourceForTarget(sourceChainId, targetChainId, targetContract, relationshipType)` — reverse lookup; reverts if no pair exists.
- `isValidCrossChainPair(source, target, sourceChainId, targetChainId, relationshipType)` — boolean validity check.
- `getAdapterPeer(sourceAdapter, targetChainId)` / `isValidAdapterPeer(...)` — `PEER_RELATIONSHIP` convenience reads.
- `isAuthorizedExecutor(executor)` — checks an `EXECUTOR_RELATIONSHIP` from `executor` to `bridgeRouter` on the current chain.

## Executor registration

`registerExecutor(address executor)` (and `removeExecutor`) are `onlyGovernor`. `registerExecutor` records an `EXECUTOR_RELATIONSHIP` from the executor to the configured `bridgeRouter`, both on `CURRENT_CHAIN_ID`.

> **The authorized executor is the contract that calls the router, not a keeper EOA.** The router's `onlyAuthorizedExecutor` modifier (in [`CrossChainConfigManaged`](reference/contracts/cross-chain-config-managed.md)) checks `msg.sender` against `isAuthorizedExecutor`, and the entry points additionally enforce `params.originator == msg.sender`. So the address registered as an executor must be the originating contract itself. Keeper EOAs that drive that contract are authorized separately by the protocol access-manager keeper role, not by registry executor registration.

The registry's `bridgeRouter` and `defaultGasLimit` are set once via `initializeBridgeConfiguration` and can be updated by governance (`setBridgeRouter`, `setDefaultGasLimit`).

## Adapter-peer trust

Adapter peers are registered by governance via `registerAdapterPeer(sourceAdapter, targetAdapter, sourceChainId, targetChainId)`, which stores a `PEER_RELATIONSHIP`. This drives two enforcement points:

- **Outbound:** `BaseBridgeAdapter.onlyTrustedDestination` reverts unless `getAdapterPeer(this, dstChain)` is set — governance has authorized talking to that chain.
- **Inbound at the adapter:** `_assertTrustedSource` reverts via `isValidAdapterPeer` unless the delivering source adapter is the registered peer for its chain. Identity binding to the specific source adapter is enforced here using bridge-native metadata (e.g. LayerZero `Origin.sender`).
- **Inbound at the router:** `BridgeRouter.deliver` additionally asserts an `(sourceChainId, msg.sender)` peer mapping exists in the registry for `TRANSFER_ASSET` and `MESSAGE`. This is a defense-in-depth check that governance registered the calling adapter for that source chain; it does **not** by itself authenticate the originating source adapter. `READ_STATE` deliveries intentionally skip this check and rely on the recorded `operationToAdapter` / originator match instead.

## Pause and guardian controls

- `BridgeRouter.pause()` is `onlyGuardianOrGovernor` — either the guardian or governance can halt all outbound operations (`whenNotPaused` blocks `executeTransferAssets`, `executeSendMessage`, `executeReadState`).
- `BridgeRouter.unpause()` is `onlyGovernor` only.
- Adapter registration/removal and `recoverAssets` on the router are `onlyGovernor`.
- The Stargate adapter records failed destination composes and exposes `manualRecovery` (`onlyGovernor`, `nonReentrant`) for governance-driven recovery of stuck funds.

## Trust assumptions

- **Bridge providers:** The system trusts LayerZero (messaging and `lzRead`) and Stargate V2 (OFT asset transfers) for honest and timely delivery. A compromised or faulty bridge could affect liveness or, in the worst case, message/asset integrity within the bounds those protocols' own security (DVNs, verifiers) allow.
- **Governance:** Governance is fully trusted to register correct adapters, executors, and peer relationships, and to keep the registry consistent across participating chains. There is no on-chain mechanism that proves registry state is identical across chains; cross-chain consistency is an operational responsibility.
- **Adapter peering:** Security against forged inbound packets rests on the registry peer mapping plus the adapters' bridge-native sender checks. The router-level peer-mapping check is a coarse authorization filter, not full source authentication.
