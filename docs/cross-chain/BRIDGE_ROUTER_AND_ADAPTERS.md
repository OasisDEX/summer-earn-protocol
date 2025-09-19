### Bridge Router and Adapters

This document describes the responsibilities of the BridgeRouter and the contract expectations for bridge adapters.

#### BridgeRouter Responsibilities

- Coordinate cross-chain operations (asset transfer, message, and read-state).
- Validate that a specified adapter is registered and supports the requested operation type.
- Chain-specific constraints are enforced by adapters; the router additionally verifies adapter peer relationships via the registry during delivery.
- Apply a modest fee buffer to quoted fees; pass the collected fee to the adapter; rely on adapters to handle refunds of any excess.
- Authenticate callbacks from adapters and route deliveries to recipients (e.g., FleetProxy).
- Provide governance controls for adapter registry and pause/unpause.
- For asset transfers, pull tokens from the caller (originator contract) and approve the adapter. The originator must approve the router beforehand.

#### Adapter Selection

- Callers specify the adapter explicitly through router options.
- The router rejects calls that reference unregistered adapters or incompatible operations.

#### BridgeOptions (Required Parameters)

- Callers must provide explicit options for every operation. The router no longer uses a default gas limit.
- Required fields when calling `quote(...)`, `executeTransferAssets(...)`, `executeSendMessage(...)`, or `executeReadState(...)`:
  - `specifiedAdapter` (address): The adapter to use. Must be registered and support the operation type.
  - `gasLimit` (uint64): Destination-side gas limit. Must be non-zero; otherwise the router reverts with `ZeroGasLimit()`.
  - `calldataSize` (uint32): Estimated size of destination calldata (adapters may use this for fee calc).
  - `msgValue` (uint128): Any adapter-specific msg.value requirement to forward (adapters handle refunds).
  - `options` (bytes): Adapter-specific opaque options blob.

Notes:
- `quote(...)` also requires a non-zero `gasLimit` and reverts if missing.
- Excess native fees are refunded by adapters per protocol behavior; the router applies a 1% buffer to base quotes.

Example (pseudocode):

```solidity
BridgeTypes.BridgeOptions memory opts = BridgeTypes.BridgeOptions({
    specifiedAdapter: myAdapter,
    gasLimit: 400_000,
    calldataSize: 0,
    msgValue: 0,
    options: bytes("")
});

(uint256 nativeFee,,) = router.quote(dstChainId, asset, amount, opts, BridgeTypes.OperationType.TRANSFER_ASSET);

router.executeTransferAssets{ value: nativeFee }(params, opts);
```

#### Fee Handling (Current Policy)

- The router adds a 1% buffer to the adapter’s base quote to accommodate fee volatility.
- Callers should pass at least the quoted fee (including the 1% buffer). If insufficient, the adapter may revert per its protocol’s behavior. Excess is refunded by the adapter as applicable.

#### Required Adapter Capabilities

- Implement a fee estimation method that the router (or callers) can use.
- Implement operation-specific methods to execute the transfer/message/read-state on the source chain.
- Implement destination-side delivery that authenticates and calls back into the local BridgeRouter.
- Only registered adapters are allowed to invoke the router’s delivery entry points.

#### Delivery to Recipients

- The destination adapter calls the local BridgeRouter with the bridged tokens and operation
  message.
- The BridgeRouter authenticates the adapter, then calls the intended recipient with the operation
  payload.
- Before forwarding, the router verifies that a peer mapping exists for `(sourceChainId, adapter)`
  via the registry’s PEER_RELATIONSHIP.
- For fleet rebalancing, the recipient is the destination chain’s FleetProxy.

#### Retry Mechanism for Failed Deliveries

- Failed deliveries are recorded with operation payload and can be retried by governance
- Use `retryFailedDelivery(operationId, overrideData)` to retry failed operations
- `RetryOverrideParams` allows overriding recipient and asset addresses for edge cases
- Asset overrides are typically not needed as adapters handle cross-chain asset mapping correctly
- Retry validates ark-fleet relationships and ensures sufficient asset balance before attempting delivery

#### Security Considerations

- Adapter registry is governance-controlled; only registered adapters can deliver.
- Reentrancy protection around critical router entry points.
- Pause/unpause by guardian/governance.

#### Testing Guidance

- Unit test adapter fee quotes and router validation paths.
- Integration test end-to-end deliveries into FleetProxy, including failure and recovery scenarios.
- Monitor and assert events across source and destination chains.
