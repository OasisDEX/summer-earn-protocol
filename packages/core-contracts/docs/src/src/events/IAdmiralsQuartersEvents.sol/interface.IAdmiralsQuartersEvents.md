# IAdmiralsQuartersEvents
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/events/IAdmiralsQuartersEvents.sol)

This interface defines the events that can be emitted during various operations
in the AdmiralsQuarters contract, such as token deposits, withdrawals, fleet interactions,
token swaps, and rescue operations.

*Interface for the events emitted by the AdmiralsQuarters contract.*


## Events
### TokensDeposited
*Emitted when tokens are deposited into the AdmiralsQuarters.*


```solidity
event TokensDeposited(address indexed user, address indexed token, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the user who deposited the tokens.|
|`token`|`address`|The address of the token that was deposited.|
|`amount`|`uint256`|The amount of tokens that were deposited.|

### TokensWithdrawn
*Emitted when tokens are withdrawn from the AdmiralsQuarters.*


```solidity
event TokensWithdrawn(address indexed user, address indexed token, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the user who withdrew the tokens.|
|`token`|`address`|The address of the token that was withdrawn.|
|`amount`|`uint256`|The amount of tokens that were withdrawn.|

### FleetEntered
*Emitted when a user enters a fleet with their tokens.*


```solidity
event FleetEntered(address indexed user, address indexed fleetCommander, uint256 inputAmount, uint256 sharesReceived);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the user who entered the fleet.|
|`fleetCommander`|`address`|The address of the FleetCommander contract.|
|`inputAmount`|`uint256`|The amount of tokens the user input into the fleet.|
|`sharesReceived`|`uint256`|The amount of shares the user received in return.|

### FleetExited
*Emitted when a user exits a fleet, withdrawing their tokens.*


```solidity
event FleetExited(address indexed user, address indexed fleetCommander, uint256 withdrawnAmount, uint256 outputAmount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the user who exited the fleet.|
|`fleetCommander`|`address`|The address of the FleetCommander contract.|
|`withdrawnAmount`|`uint256`|The amount of shares withdrawn from the fleet.|
|`outputAmount`|`uint256`|The amount of tokens received in return.|

### Swapped
*Emitted when a token swap occurs.*


```solidity
event Swapped(
    address indexed user, address indexed fromToken, address indexed toToken, uint256 fromAmount, uint256 toAmount
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the user who performed the swap.|
|`fromToken`|`address`|The address of the token being swapped from.|
|`toToken`|`address`|The address of the token being swapped to.|
|`fromAmount`|`uint256`|The amount of tokens swapped from.|
|`toAmount`|`uint256`|The amount of tokens received in the swap.|

### TokensRescued
*Emitted when tokens are rescued from the contract by the owner.*


```solidity
event TokensRescued(address indexed token, address indexed to, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|The address of the token that was rescued.|
|`to`|`address`|The address that received the rescued tokens.|
|`amount`|`uint256`|The amount of tokens that were rescued.|

