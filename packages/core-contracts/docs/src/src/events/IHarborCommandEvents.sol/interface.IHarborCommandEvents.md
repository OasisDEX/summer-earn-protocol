# IHarborCommandEvents
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/0276900cbe9b1188d82d1b9bcbb8c174e79a15a1/src/events/IHarborCommandEvents.sol)


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

