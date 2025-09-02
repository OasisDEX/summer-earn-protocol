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

#### Monitoring and Alerts

- Source chain: router execution events, adapter send events, Ark transfer events.
- Destination chain: adapter delivery events, router delivery, FleetProxy deposit events.
- Alert on: delivery failures, registry validation failures, pause state changes, abnormal fee quotes.
- Reconciliation:
  - Ark: `inflightAssets` updates when transfers are initiated; `lastRemoteAssetBalance` updates on message/read responses tied to the latest outgoing transfer.
  - FleetProxy: `latestIncomingTransferId` advances on deposits; `notifySourceChain(...)` can update the source with current fleet balance.

#### Failure and Recovery

- Bridge delivery failure: follow the adapter’s documented recovery path (e.g., retrieval by governance or retry mechanisms).
- Registry mismatch: verify registry entries on both chains; correct and re-execute only after confirmation.
- Contract paused: identify root cause, coordinate governance/guardian to safely unpause.

#### Governance and Safety Controls

- Pause/unpause on BridgeRouter and FleetProxy.
- Register/unregister Ark ↔ Proxy relationships in CrossChainRegistry.
- Asset recovery functions (where applicable) for stuck native or ERC20 balances.
