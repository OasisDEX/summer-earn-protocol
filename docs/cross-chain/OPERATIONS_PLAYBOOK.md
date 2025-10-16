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

- Source chain: router execution events, adapter send events, Ark transfer events.
- Destination chain: adapter delivery events, router delivery, FleetProxy deposit events.
- Alert on: delivery failures, registry validation failures, pause state changes, abnormal fee quotes.
- **MEV Protection Monitoring**:
  - Track `WithdrawalFeeCollected` events to monitor fee collection patterns
  - Monitor withdrawal patterns for unusual activity or potential MEV attempts
  - Alert on high frequency of withdrawals from same addresses (potential MEV bots)
  - Track withdrawal fee effectiveness and user experience metrics
  - Monitor fee collection amounts to ensure proper MEV protection
- Reconciliation (updated):
  - Ark: `inflightAssets` is set on execution and cleared when a corresponding remote balance update is processed for the latest outgoing operation. Track `InflightSet(amount, operationId)` and `InflightCleared(operationId, amount)` alongside `RemoteAssetBalanceUpdated`.
  - FleetProxy: `latestIncomingTransferId` advances on deposits. For withdrawals, track `InflightSet(amount, operationId)` on initiation and clear inflight via `acknowledgeHubReceipt(operationId)` (SuperKeeper) once receipt is verified on the hub, emitting `InflightCleared(operationId, amount)`. Governance can `forceUpdateInflightAssets(amount)` for emergency correction.

#### Failure and Recovery

- Bridge delivery failure: 
  - Use `retryFailedDelivery(operationId, overrideData)` to retry failed operations
  - For cross-chain asset transfers, may need to override asset address if adapter mapping was incorrect
  - Example: `RetryOverrideParams({recipient: address(0), asset: actualReceivedAsset})`
  - Follow the adapter's documented recovery path for other failure types (e.g., retrieval by governance)
- Registry mismatch: verify registry entries on both chains; correct and re-execute only after confirmation.
- Contract paused: identify root cause, coordinate governance/guardian to safely unpause.
