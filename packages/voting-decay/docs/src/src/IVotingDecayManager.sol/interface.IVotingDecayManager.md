# IVotingDecayManager
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/c6aec955808af03c05b24342f892f71facee60db/src/IVotingDecayManager.sol)

Interface for managing voting power decay in a governance system

*This interface defines the core functionality for a voting decay management system*


## Functions
### decayFreeWindow

Returns the current decay-free window duration


```solidity
function decayFreeWindow() external view returns (uint40);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint40`|The decay-free window duration in seconds|


### decayRatePerSecond

Returns the current decay rate per second


```solidity
function decayRatePerSecond() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The decay rate per second|


### decayFunction

Returns the current decay function type


```solidity
function decayFunction() external view returns (VotingDecayLibrary.DecayFunction);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`VotingDecayLibrary.DecayFunction`|The current decay function (Linear or Exponential)|


### getVotingPower

Calculates the current voting power for an account

*This function applies the decay factor to the original voting power*


```solidity
function getVotingPower(address accountAddress, uint256 originalValue) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`accountAddress`|`address`|The address of the account to calculate voting power for|
|`originalValue`|`uint256`|The original voting power value before decay|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current voting power after applying decay|


## Events
### DecayUpdated
Emitted when an account's decay factor is updated


```solidity
event DecayUpdated(address indexed account, uint256 newRetentionFactor);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The address of the account whose decay factor was updated|
|`newRetentionFactor`|`uint256`|The new retention factor after the update|

### DecayRateSet
Emitted when the global decay rate is changed


```solidity
event DecayRateSet(uint256 newRate);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newRate`|`uint256`|The new decay rate|

### DecayReset
Emitted when an account's decay is reset to its initial state


```solidity
event DecayReset(address indexed account);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The address of the account whose decay was reset|

### DecayFreeWindowSet
Emitted when the decay-free window duration is changed


```solidity
event DecayFreeWindowSet(uint256 window);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`window`|`uint256`|The new duration of the decay-free window|

### DecayFunctionSet
Emitted when the decay function type is changed


```solidity
event DecayFunctionSet(uint8 newFunction);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newFunction`|`uint8`|The new decay function type (0 for Linear, 1 for Exponential)|

## Errors
### InvalidDecayRate
Thrown when an invalid decay rate is set


```solidity
error InvalidDecayRate();
```

### AlreadyDelegated
Thrown when trying to delegate voting power that's already delegated


```solidity
error AlreadyDelegated();
```

### CannotDelegateToSelf
Thrown when attempting to delegate voting power to oneself


```solidity
error CannotDelegateToSelf();
```

### NotDelegated
Thrown when trying to undelegate voting power that isn't delegated


```solidity
error NotDelegated();
```

### NotAuthorizedToReset
Thrown when an unauthorized address attempts to reset decay


```solidity
error NotAuthorizedToReset();
```

### AccountNotInitialized
Thrown when trying to perform an operation on an uninitialized account


```solidity
error AccountNotInitialized();
```

