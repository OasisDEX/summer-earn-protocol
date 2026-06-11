---
description: The BridgeRouter's responsibilities, adapter registration and selection, the LayerZero and Stargate adapters, operation types, and the fee/quote model.
---

# Bridge Router and Adapters

The [`BridgeRouter`](reference/router/bridge-router.md) is the central coordinator for all cross-chain operations. Adapters are protocol-specific shims that translate the router's generic operations into LayerZero or Stargate calls and back.

## BridgeRouter responsibilities

The router exposes three outbound entry points, all `payable`, `onlyAuthorizedExecutor`, `whenNotPaused`, `nonReentrant`, and guarded by `validAdapter`:

- `executeTransferAssets(params, options)` — validates parameters and `originator == msg.sender`, pulls `params.amount` of `params.asset` from the executor, `forceApprove`s the chosen adapter, best-effort notifies the originator via `IInflightAssetTracking.updateInflightAssets`, generates a router-owned `operationId`, then calls the adapter's `transferAsset` forwarding the full `msg.value`.
- `executeSendMessage(params, options)` — validates and dispatches a message via the adapter's `sendMessage`.
- `executeReadState(params, options)` — records `operationToAdapter` and `readRequestToOriginator` for response routing, then calls the adapter's `readState`.

Each operation gets a unique `operationId` from `_generateOperationId`, which hashes chain IDs, asset/amount/target, additional data, a per-router nonce, and the operation type. The router is the single source of truth for this ID.

On the destination chain, the router's `deliver(operationType, operationPayload)` is the inbound sink. It is `onlyRegisteredAdapter` and `nonReentrant`:

- `TRANSFER_ASSET`: asserts a peer mapping exists for the source chain, `safeTransfer`s the asset to the recipient, then calls `recipient.receiveOperation`.
- `MESSAGE`: asserts the peer mapping, then calls `recipient.receiveOperation`.
- `READ_STATE`: skips the peer-mapping check (read responses return on the originating chain). Instead it requires `operationToAdapter[operationId] == msg.sender` and a recorded originator, then calls `originator.receiveOperation`.

## Adapter registration and selection

Adapters are registered into the router by governance via `registerAdapter(address)` and removed via `removeAdapter(address)`. The router keeps them in an `EnumerableSet`; `isValidAdapter` / `getAdapters` expose the set.

Adapter selection is **explicit, not automatic**. Every operation's `BridgeTypes.BridgeOptions.specifiedAdapter` must name the adapter to use. A zero adapter reverts with `NoSuitableAdapter`; an unregistered adapter reverts with `UnknownAdapter`; an adapter that does not support the requested `OperationType` reverts with `UnsupportedAdapterOperation`.

## LayerZero vs Stargate adapters

Both adapters extend [`BaseBridgeAdapter`](reference/base/base-bridge-adapter.md), which maintains chain-ID-to-bridge-external-ID mappings and enforces registry-backed peer trust via `onlyTrustedDestination` (outbound) and `onlyTrustedSource` / `_assertTrustedSource` (inbound).

- **[StargateAdapter](reference/adapters/stargate-adapter.md)** — implements `IAssetAdapter` for `TRANSFER_ASSET`. Built on Stargate V2 OFT contracts, it maps each supported asset to its Stargate contract on the local chain. It uses **taxi mode** by default because compose (the destination-side callback that drives delivery) requires it; bus mode does not support compose. It applies configurable slippage (default 50 bps, bounded 1–1000 bps) and refunds unused native value to `params.refundAddress`. Failed destination composes are recorded in `failedComposes` for governance `manualRecovery`.
- **[LayerZeroAdapter](reference/adapters/layer-zero-adapter.md)** — implements `IMessageAdapter` for `MESSAGE` and `READ_STATE`, built on LayerZero's `OAppRead`. It distinguishes `lzRead` responses by a configurable `readChannelThreshold` on the source EID and tracks `expectedReadChainByGuid` to enforce trust on read responses.

## Operation types

Operation types come from [`BridgeTypes.OperationType`](reference/libraries/bridge-types.md): `MESSAGE`, `READ_STATE`, `TRANSFER_ASSET`. An adapter advertises which it supports through `supportsOperation(OperationType)`; the router checks this in `validAdapter` before dispatch.

## Fee and quote model

`quote(destinationChainId, asset, amount, options, operationType)` returns `(nativeFee, tokenFee, specifiedAdapter)`. It requires a non-zero, registered `specifiedAdapter`, delegates the base estimate to the adapter's `estimateFee`, and then applies a **1% buffer** to both fees via `(baseFee * 101) / 100` to absorb fee volatility between quoting and execution. Callers forward the buffered native fee as `msg.value`; the adapter (e.g. Stargate) refunds any unused excess to the refund address.

## Asset recovery

`recoverAssets(token, recipient, amount)` is `onlyGovernor` and `nonReentrant`. It recovers stuck native ETH (`token == address(0)`) or ERC-20 tokens held by the router, emitting `RouterAssetsRecovered`.
