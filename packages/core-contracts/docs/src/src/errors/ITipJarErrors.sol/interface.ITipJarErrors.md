# ITipJarErrors
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/errors/ITipJarErrors.sol)

These custom errors provide more gas-efficient and informative error handling
compared to traditional require statements with string messages.

*This file contains custom error definitions for the TipJar contract.*


## Errors
### InvalidRecipientAddress
Thrown when an invalid recipient address is provided.


```solidity
error InvalidRecipientAddress();
```

### TipStreamAlreadyExists
Thrown when attempting to create a tip stream for a recipient that already has one.


```solidity
error TipStreamAlreadyExists(address recipient);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|The address of the recipient with an existing tip stream.|

### InvalidTipStreamAllocation
Thrown when an invalid allocation percentage is provided for a tip stream.


```solidity
error InvalidTipStreamAllocation(Percentage invalidAllocation);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`invalidAllocation`|`Percentage`|The invalid allocation percentage.|

### TotalAllocationExceedsOneHundredPercent
Thrown when the total allocation of tip streams exceeds 100%.


```solidity
error TotalAllocationExceedsOneHundredPercent();
```

### TipStreamDoesNotExist
Thrown when attempting to interact with a non-existent tip stream.


```solidity
error TipStreamDoesNotExist(address recipient);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|The address of the recipient for which the tip stream does not exist.|

### TipStreamLocked
Thrown when attempting to modify a locked tip stream.


```solidity
error TipStreamLocked(address recipient);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`recipient`|`address`|The address of the recipient with the locked tip stream.|

### NoSharesToRedeem
Thrown when attempting to redeem shares when there are none available.


```solidity
error NoSharesToRedeem();
```

### NoAssetsToDistribute
Thrown when attempting to distribute assets when there are none available.


```solidity
error NoAssetsToDistribute();
```

### InvalidTreasuryAddress
Thrown when an invalid treasury address is provided.


```solidity
error InvalidTreasuryAddress();
```

### InvalidFleetCommanderAddress
Thrown when an invalid FleetCommander address is provided.


```solidity
error InvalidFleetCommanderAddress();
```

