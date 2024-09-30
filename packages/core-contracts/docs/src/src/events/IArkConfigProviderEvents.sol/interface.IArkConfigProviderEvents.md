# IArkConfigProviderEvents
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/02b633fc64591288020c32f3fcb6421ab62209d5/src/events/IArkConfigProviderEvents.sol)

Interface for events emitted by ArkConfigProvider contracts


## Events
### DepositCapUpdated
Emitted when the deposit cap of the Ark is updated


```solidity
event DepositCapUpdated(uint256 newCap);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newCap`|`uint256`|The new deposit cap value|

### RaftUpdated
Emitted when the Raft address associated with the Ark is updated


```solidity
event RaftUpdated(address newRaft);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newRaft`|`address`|The address of the new Raft|

### MaxRebalanceOutflowUpdated
Emitted when the maximum outflow limit for the Ark during rebalancing is updated


```solidity
event MaxRebalanceOutflowUpdated(uint256 newMaxOutflow);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newMaxOutflow`|`uint256`|The new maximum amount that can be transferred out of the Ark during a rebalance|

### MaxRebalanceInflowUpdated
Emitted when the maximum inflow limit for the Ark during rebalancing is updated


```solidity
event MaxRebalanceInflowUpdated(uint256 newMaxInflow);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newMaxInflow`|`uint256`|The new maximum amount that can be transferred into the Ark during a rebalance|

