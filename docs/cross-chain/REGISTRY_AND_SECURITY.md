### Cross-Chain Registry and Security

This document outlines the `CrossChainRegistry` model and how validation is performed on source and
destination chains.

#### Registry Model

- Governance-controlled registry that records valid relationships between a source Ark and a
  destination FleetProxy for a specific source/target chain pair and relationship type.
- Registry state must be identical across all participating chains.

#### Source-Side Validation (Ark)

- Before initiating a cross-chain transfer, the CrossChain Ark queries the registry for the target
  relationship.
- If no active relationship exists, the Ark reverts immediately.
- Execution is gated by `onlyAuthorizedExecutor` (from registry). Keepers must be registered
  executors to invoke the router via the Ark.

Example pattern:

```solidity
// Pseudocode for clarity; refer to the codebase for exact interfaces
address proxy = crossChainRegistry.getRelationshipByTarget(
    address(this),
    ARK_FLEET_RELATIONSHIP,
    destinationChainId
).targetContract;
require(proxy != address(0), "No relationship");
```

#### Destination-Side Validation (FleetProxy)

- Upon delivery, the FleetProxy validates:
  - Caller is the local BridgeRouter (FleetProxy trusts only the router; the router authenticates
    adapters and peer relationships).
  - The source chain and Ark match an active registry relationship for this FleetProxy.
- If either check fails, the call reverts and funds are not deposited into the local fleet.

Example pattern:

```solidity
// Recipient-side: only trust the local BridgeRouter
require(msg.sender == bridgeRouter, "Only router");

// Router-side (already enforced on deliver()):
// - onlyRegisteredAdapter(adapter)
// - peer relationship exists for (sourceChainId, adapter)

// Recipient validates source Ark + chain via registry
bool ok = crossChainRegistry.isValidCrossChainPair(
    sourceArk,
    address(this),
    sourceChainId,
    uint16(block.chainid),
    ARK_FLEET_RELATIONSHIP
);
require(ok, "Invalid source relationship");
```

#### Security Properties

- Authoritative mappings; only governance can register/unregister.
- Immediate failure at the first validation point (source or destination).
- Strong adapter authentication; no arbitrary callers.
- Emergency controls: pause/unpause; unregister compromised relationships.
- Consistent configuration across chains for both `PEER_RELATIONSHIP` (adapter peers) and
  `ARK_FLEET_RELATIONSHIP` (Ark ↔ Proxy pairs).

#### Deployment Checklist

- Deploy `CrossChainRegistry` on all participating chains.
- Register all Ark ↔ Proxy relationships with consistent parameters across chains.
- Verify that invalid operations revert with clear registry errors.
- Configure emergency pause mechanisms and monitoring for validation failures.
