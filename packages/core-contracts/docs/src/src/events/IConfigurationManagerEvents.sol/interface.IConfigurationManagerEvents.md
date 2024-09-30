# IConfigurationManagerEvents
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/events/IConfigurationManagerEvents.sol)

Interface for events emitted by the Configuration Manager


## Events
### RaftUpdated
Emitted when the Raft address is updated


```solidity
event RaftUpdated(address newRaft);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newRaft`|`address`|The address of the new Raft|

### TipJarUpdated
Emitted when the tip jar address is updated


```solidity
event TipJarUpdated(address newTipJar);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newTipJar`|`address`|The address of the new tip jar|

### TipRateUpdated
Emitted when the tip rate is updated


```solidity
event TipRateUpdated(uint8 newTipRate);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newTipRate`|`uint8`|The new tip rate value|

### TreasuryUpdated
Emitted when the Treasury address is updated


```solidity
event TreasuryUpdated(address newTreasury);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newTreasury`|`address`|The address of the new Treasury|

