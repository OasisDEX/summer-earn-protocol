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
  - Track `CrossChainFleetCommanderCooldownNotMet` errors for potential attack attempts
  - Monitor deposit/withdrawal patterns for unusual activity
  - Alert on high frequency of cooldown violations from same addresses
  - Track cooldown period effectiveness and user experience metrics
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

#### MEV Protection Troubleshooting

**Common Issues:**

1. **User Complaints About Cooldown**:
   - Check user's last deposit timestamp: `lastDepositTimestamp[user]`
   - Verify cooldown period: `getCooldownPeriod()`
   - Calculate remaining time: `getNextWithdrawTimestamp(user) - block.timestamp`
   - Explain cooldown mechanism and security benefits

2. **High Cooldown Violation Rate**:
   - Investigate potential MEV attack attempts
   - Check for coordinated violation attempts from multiple addresses
   - Consider adjusting cooldown period if too restrictive
   - Monitor for patterns indicating systematic exploitation attempts

3. **User Experience Issues**:
   - Track average cooldown wait times
   - Monitor user feedback and support tickets
   - Consider UI improvements to show cooldown status
   - Evaluate cooldown period effectiveness

**Monitoring Queries:**

```solidity
// Check user cooldown status
bool canWithdraw = fleetCommander.canWithdraw(user);
uint256 nextWithdrawTime = fleetCommander.getNextWithdrawTimestamp(user);
uint256 cooldownPeriod = fleetCommander.getCooldownPeriod();
```

**Alert Thresholds:**
- >10 cooldown violations per hour from same address
- >50 cooldown violations per hour across all users
- Average cooldown wait time >2x configured period
- User complaints about cooldown >5% of total users

#### Governance and Safety Controls

- Pause/unpause on BridgeRouter and FleetProxy.
- Register/unregister Ark ↔ Proxy relationships in CrossChainRegistry.
- Asset recovery functions (where applicable) for stuck native or ERC20 balances.
- **MEV Protection Controls**:
  - Cooldown period is immutable after deployment (by design)
  - No governance override for individual user cooldowns
  - Monitor cooldown effectiveness through metrics and user feedback
