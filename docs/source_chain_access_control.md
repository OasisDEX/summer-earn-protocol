## Plan: Make BridgeRouter the single choke-point for every cross-chain call  

> Goal: Contracts on one chain (Ark, FleetProxy, …) accept or invoke calls **only when those calls pass through their own BridgeRouter**, which in turn verifies the remote origin via the registry ↔ adapter pair.

---

### 1. Registry: keep only the essentials  
Registry still knows about  
• `ADAPTER_PEER` – adapter ↔ adapter symmetry  
• `ARK_FLEET`   – Ark ↔ Fleet mapping  

No `ARK_ROUTER` or `FLEET_ROUTER` relationship types are necessary because runtime contracts read the router address from `CrossChainConfigManaged.bridgeRouter()`.

---

### 2. Executors via a **source-chain relationship**

Authorised executors live on the **same** chain as the `BridgeRouter`.  
Instead of keeping a bespoke whitelist we store them in `CrossChainRegistry`
as a *local* relationship:

Key points  
• new relationship-type constant `EXECUTOR = keccak256("EXECUTOR")`  
• generic helper `registerSourceChainRelationship()` that skips the
  “different-chains” check and stores a pairing where both
  `sourceChainId` and `targetChainId` equal `currentChainId`  
• thin convenience wrappers for executor management

```solidity
// CrossChainRegistry.sol
bytes32 public constant EXECUTOR = keccak256("EXECUTOR");

function registerSourceChainRelationship(
    address sourceContract,
    address targetContract,
    bytes32 relationshipType
) public onlyGovernor {
    // both contracts live on this chain
    _register(
        sourceContract,
        targetContract,
        currentChainId,
        currentChainId,
        relationshipType
    );
}

function registerExecutor(address executor) external onlyGovernor {
    registerSourceChainRelationship(executor, bridgeRouter, EXECUTOR);
}

function removeExecutor(address executor) external onlyGovernor {
    unregisterCrossChainRelationship(
        executor,
        EXECUTOR,
        currentChainId   // targetChainId == currentChainId
    );
}

function isAuthorizedExecutor(address executor) external view returns (bool) {
    return isValidCrossChainPair(
        executor,
        bridgeRouter,
        currentChainId,
        currentChainId,
        EXECUTOR
    );
}
```

`BridgeRouter` keeps the same runtime guard but now queries
through the generic API:

```solidity
modifier onlyAuthorizedExecutor() {
    if (
        !registry.isValidCrossChainPair(
            msg.sender,
            address(this),             // BridgeRouter
            registry.currentChainId(),
            registry.currentChainId(),
            registry.EXECUTOR()
        )
    ) revert OnlyAuthorizedExecutor();
    _;
}
```

This deletes the custom `EnumerableSet` and re-uses the registry’s existing
storage, events and governance flow.  Any future *local* pairings
(e.g. treasuries, keepers, fee collectors, …) can be added the very same way
without extra code.

---

### 3. Router helper for inbound deliveries  
Add a **single** entry-point (covers assets & pure messages):

```solidity
function deliver(
    bytes32 operationId,
    uint16  sourceChainId,
    address asset,      // address(0) for "just a message"
    uint256 amount,     // 0 for "just a message"
    address recipient,  // Ark, FleetProxy, …
    bytes   payload
) external onlyRegisteredAdapter nonReentrant
```

1. If `asset != address(0)` move tokens to `recipient`.  
2. Try callback (`receiveMessageWithAssets` if asset, else `receiveMessage`).  
3. Emit `TransferReceived` or `MessageDelivered`.  

No new storage slots; runtime byte-code cost ≈ 300 bytes.

---

### 4. Adapter responsibilities  

Outbound (unchanged)
```