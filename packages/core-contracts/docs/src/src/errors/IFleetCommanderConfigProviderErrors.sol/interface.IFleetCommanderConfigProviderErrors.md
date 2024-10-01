# IFleetCommanderConfigProviderErrors
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/0276900cbe9b1188d82d1b9bcbb8c174e79a15a1/src/errors/IFleetCommanderConfigProviderErrors.sol)

These custom errors provide more gas-efficient and informative error handling
compared to traditional require statements with string messages.

*This file contains custom error definitions for the FleetCommanderConfigProvider contract.*


## Errors
### FleetCommanderArkNotFound
Thrown when an operation is attempted on a non-existent Ark


```solidity
error FleetCommanderArkNotFound(address ark);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ark`|`address`|The address of the Ark that was not found|

### FleetCommanderArkDepositCapGreaterThanZero
Thrown when trying to remove an Ark that still has a non-zero deposit cap


```solidity
error FleetCommanderArkDepositCapGreaterThanZero(address ark);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ark`|`address`|The address of the Ark with a non-zero deposit cap|

### FleetCommanderArkAssetsNotZero
Thrown when attempting to remove an Ark that still holds assets


```solidity
error FleetCommanderArkAssetsNotZero(address ark);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ark`|`address`|The address of the Ark with non-zero assets|

### FleetCommanderArkAlreadyExists
Thrown when trying to add an Ark that already exists in the system


```solidity
error FleetCommanderArkAlreadyExists(address ark);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ark`|`address`|The address of the Ark that already exists|

### FleetCommanderInvalidArkAddress
Thrown when an invalid Ark address is provided (e.g., zero address)


```solidity
error FleetCommanderInvalidArkAddress();
```

