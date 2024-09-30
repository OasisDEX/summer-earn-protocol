# CooldownEnforcer
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/utils/CooldownEnforcer/CooldownEnforcer.sol)

**Inherits:**
[ICooldownEnforcer](/src/utils/CooldownEnforcer/ICooldownEnforcer.sol/interface.ICooldownEnforcer.md)


## State Variables
### _cooldown
STATE VARIABLES
Cooldown between actions in seconds


```solidity
uint256 private _cooldown;
```


### _lastActionTimestamp
Timestamp of the last action in Epoch time (block timestamp)


```solidity
uint256 private _lastActionTimestamp;
```


## Functions
### constructor

CONSTRUCTOR

Initializes the cooldown period and sets the last action timestamp to the current block timestamp
if required

*The last action timestamp is set to the current block timestamp if enforceFromNow is true,
otherwise it is set to 0 signaling that the cooldown period has not started yet.*


```solidity
constructor(uint256 cooldown_, bool enforceFromNow);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`cooldown_`|`uint256`|The cooldown period in seconds.|
|`enforceFromNow`|`bool`|If true, the last action timestamp is set to the current block timestamp.|


### enforceCooldown

MODIFIERS

Modifier to enforce the cooldown period between actions.

*If the cooldown period has not elapsed, the function call will revert.
Otherwise, the last action timestamp is updated to the current block timestamp.*


```solidity
modifier enforceCooldown();
```

### getCooldown

VIEW FUNCTIONS


```solidity
function getCooldown() public view returns (uint256);
```

### getLastActionTimestamp

Returns the timestamp of the last action in Epoch time (block timestamp).


```solidity
function getLastActionTimestamp() public view returns (uint256);
```

### _updateCooldown

INTERNAL STATE CHANGE FUNCTIONS

Updates the cooldown period.

*The function is internal so it can be wrapped with access modifiers if needed*


```solidity
function _updateCooldown(uint256 newCooldown) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newCooldown`|`uint256`|The new cooldown period in seconds.|


### _setLastActionTimestamp

Updates the last action timestamp

*Allows for cooldown period to be skipped (IE after force withdrawal)*


```solidity
function _setLastActionTimestamp(uint256 lastActionTimestamp) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`lastActionTimestamp`|`uint256`|The new last action timestamp|


