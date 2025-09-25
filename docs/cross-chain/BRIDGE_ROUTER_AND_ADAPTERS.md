### Bridge Router and Adapters

This document describes the responsibilities of the BridgeRouter and the contract expectations for bridge adapters.

#### BridgeRouter Responsibilities

- Coordinate cross-chain operations (asset transfer, message, and read-state).
- Validate that a specified adapter is registered and supports the requested operation type.
- Chain-specific constraints are enforced by adapters; the router additionally verifies adapter peer relationships via the registry during delivery.
- Apply a modest fee buffer to quoted fees; pass the collected fee to the adapter; rely on adapters to handle refunds of any excess.
- Authenticate callbacks from adapters and route deliveries to recipients (e.g., FleetProxy).
- Provide governance controls for adapter registry and pause/unpause.
- For asset transfers, pull tokens from the caller (originator contract) and approve the adapter.
  The originator must approve the router beforehand.
- Best-effort notify originators that support IInflightAssetTracking to update inflight accounting.

#### Adapter Selection

- Callers specify the adapter explicitly through router options.
- The router rejects calls that reference unregistered adapters or incompatible operations.

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

#### Security Considerations

- Adapter registry is governance-controlled; only registered adapters can deliver.
- Reentrancy protection around critical router entry points.
- Pause/unpause by guardian/governance.

#### Testing Guidance

- Unit test adapter fee quotes and router validation paths.
- Integration test end-to-end deliveries into FleetProxy, including failure and recovery scenarios.
- Monitor and assert events across source and destination chains.
