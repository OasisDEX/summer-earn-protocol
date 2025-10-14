### Operations Playbook (Rebalancing, Monitoring, Recovery)

This document provides a practical runbook for keepers and operators.

#### Rebalancing Runbook

- Monitor Buffer Ark balances and target allocations from the CrossChain Fleet strategy.
- Queue transfers from Buffer Ark to the relevant CrossChain Ark(s) per target chain.
- Execute queued transfers when thresholds are met (size, time, or market conditions).
- Record executed amounts and destination receipts.
- Preconditions:
  - Keeper addresses are registered as authorized executors in the CrossChainRegistry on the source chain.
  - Adapter peer relationships and Ark ↔ Proxy relationships are configured consistently across chains.
  - Rebalance calls include `BridgeOptions` with a non-zero `gasLimit`. There is no default gas limit.

#### Monitoring and Alerts

- Hub chain: router execution events, adapter send events, Ark transfer events.
- Destination chain: adapter delivery events, router delivery, FleetProxy deposit events.
- Alert on: delivery failures, registry validation failures, pause state changes, abnormal fee quotes.
- Reconciliation (updated):
  - Ark: `inflightAssets` is set on execution and cleared when a corresponding remote balance update is processed for the latest outgoing operation. Track `InflightSet(amount, operationId)` and `InflightCleared(operationId, amount)` alongside `RemoteAssetBalanceUpdated`.
  - FleetProxy: `latestIncomingTransferId` advances on deposits. For withdrawals, track `InflightSet(amount, operationId)` on initiation and clear inflight via `acknowledgeHubReceipt(operationId)` (SuperKeeper) once receipt is verified on the hub, emitting `InflightCleared(operationId, amount)`. Governance can `forceUpdateInflightAssets(amount)` for emergency correction.

#### ERC7802 Adapter Operations

For ERC7802 adapters (ERC7802OFTAdapter, SuperchainAdapter), additional monitoring and finalization steps are required:

- Monitor for tokens minted to ERC7802 adapters on destination chains
- Call `finalize(operationId, params)` to complete delivery after tokens are minted
- Alert on pending finalizations that exceed time thresholds (e.g., >30 minutes)
- Track finalization success/failure events and adapter balance changes
- Ensure authorized executors are configured for finalization calls

#### Failure and Recovery

- Bridge delivery failure: 
  - Failed deliveries are automatically recorded by the router with operation payload
  - Use `retryFailedDelivery(operationId, newRecipient)` to retry failed operations
  - Pass `address(0)` as `newRecipient` to use the original recipient, or specify a new recipient address
  - Use `getFailedDeliveryIds()` to enumerate failed operations that can be retried
  - Follow the adapter's documented recovery path for other failure types (e.g., retrieval by governance)
- Registry mismatch: verify registry entries on both chains; correct and re-execute only after confirmation.
- Contract paused: identify root cause, coordinate governance/guardian to safely unpause.

#### Governance and Safety Controls

- Pause/unpause on BridgeRouter and FleetProxy.
- Register/unregister Ark ↔ Proxy relationships in CrossChainRegistry.
- Asset recovery functions (where applicable) for stuck native or ERC20 balances.
