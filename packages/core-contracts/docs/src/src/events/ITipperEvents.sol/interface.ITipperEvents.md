# ITipperEvents
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/events/ITipperEvents.sol)


## Events
### TipRateUpdated
Emitted when the tip rate is updated


```solidity
event TipRateUpdated(Percentage newTipRate);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newTipRate`|`Percentage`|The new tip rate value|

### TipAccrued
Emitted when tips are accrued


```solidity
event TipAccrued(uint256 tipAmount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tipAmount`|`uint256`|The amount of tips accrued in the underlying asset's smallest unit|

### TipJarUpdated
Emitted when the tip jar address is updated


```solidity
event TipJarUpdated(address newTipJar);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newTipJar`|`address`|The new address of the tip jar|

