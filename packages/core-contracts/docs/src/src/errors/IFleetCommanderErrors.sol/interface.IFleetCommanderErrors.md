# IFleetCommanderErrors
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/errors/IFleetCommanderErrors.sol)

These custom errors provide more gas-efficient and informative error handling
compared to traditional require statements with string messages.

*This file contains custom error definitions for the FleetCommander contract.*


## Errors
### FleetCommanderTransfersDisabled
Thrown when transfers are disabled.


```solidity
error FleetCommanderTransfersDisabled();
```

### FleetCommanderArkNotActive
Thrown when an operation is attempted on an inactive Ark.


```solidity
error FleetCommanderArkNotActive(address ark);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ark`|`address`|The address of the inactive Ark.|

### FleetCommanderCantRebalanceToArk
Thrown when attempting to rebalance to an invalid Ark.


```solidity
error FleetCommanderCantRebalanceToArk(address ark);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ark`|`address`|The address of the invalid Ark.|

### FleetCommanderInvalidBufferAdjustment
Thrown when an invalid buffer adjustment is attempted.


```solidity
error FleetCommanderInvalidBufferAdjustment();
```

### FleetCommanderInsufficientBuffer
Thrown when there is insufficient buffer for an operation.


```solidity
error FleetCommanderInsufficientBuffer();
```

### FleetCommanderRebalanceNoOperations
Thrown when a rebalance operation is attempted with no actual operations.


```solidity
error FleetCommanderRebalanceNoOperations();
```

### FleetCommanderRebalanceTooManyOperations
Thrown when a rebalance operation exceeds the maximum allowed number of operations.


```solidity
error FleetCommanderRebalanceTooManyOperations(uint256 operationsCount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`operationsCount`|`uint256`|The number of operations attempted.|

### FleetCommanderRebalanceAmountZero
Thrown when a rebalance amount for an Ark is zero.


```solidity
error FleetCommanderRebalanceAmountZero(address ark);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ark`|`address`|The address of the Ark with zero rebalance amount.|

### WithdrawalAmountExceedsMaxBufferLimit
Thrown when a withdrawal amount exceeds the maximum buffer limit.


```solidity
error WithdrawalAmountExceedsMaxBufferLimit();
```

### FleetCommanderArkDepositCapZero
Thrown when an Ark's deposit cap is zero.


```solidity
error FleetCommanderArkDepositCapZero(address ark);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ark`|`address`|The address of the Ark with zero deposit cap.|

### FleetCommanderNoFundsMoved
Thrown when no funds were moved in an operation that expected fund movement.


```solidity
error FleetCommanderNoFundsMoved();
```

### FleetCommanderNoExcessFunds
Thrown when there are no excess funds to perform an operation.


```solidity
error FleetCommanderNoExcessFunds();
```

### FleetCommanderInvalidSourceArk
Thrown when an invalid source Ark is specified for an operation.


```solidity
error FleetCommanderInvalidSourceArk(address ark);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ark`|`address`|The address of the invalid source Ark.|

### FleetCommanderMovedMoreThanAvailable
Thrown when an operation attempts to move more funds than available.


```solidity
error FleetCommanderMovedMoreThanAvailable();
```

### FleetCommanderUnauthorizedWithdrawal
Thrown when an unauthorized withdrawal is attempted.


```solidity
error FleetCommanderUnauthorizedWithdrawal(address caller, address owner);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`caller`|`address`|The address attempting the withdrawal.|
|`owner`|`address`|The address of the authorized owner.|

### FleetCommanderUnauthorizedRedemption
Thrown when an unauthorized redemption is attempted.


```solidity
error FleetCommanderUnauthorizedRedemption(address caller, address owner);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`caller`|`address`|The address attempting the redemption.|
|`owner`|`address`|The address of the authorized owner.|

### FleetCommanderCantUseRebalanceOnBufferArk
Thrown when attempting to use rebalance on a buffer Ark.


```solidity
error FleetCommanderCantUseRebalanceOnBufferArk();
```

### FleetCommanderCantUseMaxUintForBufferAdjustement
Thrown when attempting to use the maximum uint value for buffer adjustment.


```solidity
error FleetCommanderCantUseMaxUintForBufferAdjustement();
```

### FleetCommanderExceedsMaxOutflow
Thrown when a rebalance operation exceeds the maximum outflow for an Ark.


```solidity
error FleetCommanderExceedsMaxOutflow(address fromArk, uint256 amount, uint256 maxRebalanceOutflow);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fromArk`|`address`|The address of the Ark from which funds are being moved.|
|`amount`|`uint256`|The amount being moved.|
|`maxRebalanceOutflow`|`uint256`|The maximum allowed outflow.|

### FleetCommanderExceedsMaxInflow
Thrown when a rebalance operation exceeds the maximum inflow for an Ark.


```solidity
error FleetCommanderExceedsMaxInflow(address fromArk, uint256 amount, uint256 maxRebalanceInflow);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`fromArk`|`address`|The address of the Ark to which funds are being moved.|
|`amount`|`uint256`|The amount being moved.|
|`maxRebalanceInflow`|`uint256`|The maximum allowed inflow.|

