# IHarborCommandEvents
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/events/IHarborCommandEvents.sol)


## Events
### FleetCommanderEnlisted
Emitted when a new FleetCommander is enlisted


```solidity
event FleetCommanderEnlisted(address indexed fleetCommander);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fleetCommander`|`address`|The address of the enlisted FleetCommander|

### FleetCommanderDecommissioned
Emitted when a FleetCommander is decommissioned


```solidity
event FleetCommanderDecommissioned(address indexed fleetCommander);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fleetCommander`|`address`|The address of the decommissioned FleetCommander|

