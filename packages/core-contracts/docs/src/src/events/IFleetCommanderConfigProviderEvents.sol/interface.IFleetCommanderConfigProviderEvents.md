# IFleetCommanderConfigProviderEvents
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/events/IFleetCommanderConfigProviderEvents.sol)


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

