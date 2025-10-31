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

#### Deployment Runbook

For deploying new cross-chain fleets, follow the satellite-first approach:

1. **Prerequisites**: Deploy bridge, governance, and core contracts on all chains
2. **Satellite Phase**: Deploy satellite fleet and FleetProxy (`deploy-xchain-fleetproxy.ts`)
3. **Hub Phase**: Deploy hub fleet and CrossChainArk (`deploy-xchain-ark.ts`)
4. **Registration**: Register adapter peers and executors (`x-chain/post-deployment/register-ark-fleet.ts`)
5. **Verification**: Verify setup (`x-chain/post-deployment/verify-setup.ts`)

See `docs/cross-chain/DEPLOYMENT_GUIDE.md` for detailed instructions.

#### Monitoring and Alerts

- Hub chain: router execution events, adapter send events, Ark transfer events.
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
  - Failed deliveries are automatically recorded by the router with operation payload
  - Use `retryFailedDelivery(operationId, newRecipient)` to retry failed operations
  - Pass `address(0)` as `newRecipient` to use the original recipient, or specify a new recipient address
  - Use `getFailedDeliveryIds()` to enumerate failed operations that can be retried
  - Follow the adapter's documented recovery path for other failure types (e.g., retrieval by governance)
- Registry mismatch: verify registry entries on both chains; correct and re-execute only after confirmation.
- Contract paused: identify root cause, coordinate governance/guardian to safely unpause.
