# IHarborCommandEvents
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/02b633fc64591288020c32f3fcb6421ab62209d5/src/events/IHarborCommandEvents.sol)


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

