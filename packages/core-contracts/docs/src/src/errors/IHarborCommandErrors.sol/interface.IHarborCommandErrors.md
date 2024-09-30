# IHarborCommandErrors
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/02b633fc64591288020c32f3fcb6421ab62209d5/src/errors/IHarborCommandErrors.sol)

These custom errors provide more gas-efficient and informative error handling
compared to traditional require statements with string messages.

*This file contains custom error definitions for the HarborCommand contract.*


## Errors
### FleetCommanderAlreadyEnlisted
Thrown when attempting to enlist a FleetCommander that is already enlisted


```solidity
error FleetCommanderAlreadyEnlisted(address fleetCommander);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fleetCommander`|`address`|The address of the FleetCommander that was attempted to be enlisted|

### FleetCommanderNotEnlisted
Thrown when attempting to decommission a FleetCommander that is not currently enlisted


```solidity
error FleetCommanderNotEnlisted(address fleetCommander);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fleetCommander`|`address`|The address of the FleetCommander that was attempted to be decommissioned|

