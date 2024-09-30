# IFleetCommanderConfigProviderEvents
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/02b633fc64591288020c32f3fcb6421ab62209d5/src/events/IFleetCommanderConfigProviderEvents.sol)


## Events
### FleetCommanderDepositCapUpdated
Emitted when the deposit cap is updated


```solidity
event FleetCommanderDepositCapUpdated(uint256 newCap);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newCap`|`uint256`|The new deposit cap value|

### ArkAdded
Emitted when a new Ark is added


```solidity
event ArkAdded(address indexed ark);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ark`|`address`|The address of the newly added Ark|

### ArkRemoved
Emitted when an Ark is removed


```solidity
event ArkRemoved(address indexed ark);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ark`|`address`|The address of the removed Ark|

### FleetCommanderminimumBufferBalanceUpdated
Emitted when new minimum funds buffer balance is set


```solidity
event FleetCommanderminimumBufferBalanceUpdated(uint256 newBalance);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newBalance`|`uint256`|New minimum funds buffer balance|

### FleetCommanderMaxRebalanceOperationsUpdated
Emitted when new max allowed rebalance operations is set


```solidity
event FleetCommanderMaxRebalanceOperationsUpdated(uint256 newMaxRebalanceOperations);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newMaxRebalanceOperations`|`uint256`|Max allowed rebalance operations|

