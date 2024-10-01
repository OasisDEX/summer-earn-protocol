# VotingDecayManager
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/c6aec955808af03c05b24342f892f71facee60db/src/VotingDecayManager.sol)

**Inherits:**
[IVotingDecayManager](/src/IVotingDecayManager.sol/interface.IVotingDecayManager.md), Ownable

Manages voting power decay for accounts in a governance system

*Implements decay calculations, delegation, and administrative functions*


## State Variables
### decayInfoByAccount

```solidity
mapping(address account => VotingDecayLibrary.DecayInfo info) internal decayInfoByAccount;
```


### decayFreeWindow

```solidity
uint40 public decayFreeWindow;
```


### decayRatePerSecond

```solidity
uint256 public decayRatePerSecond;
```


### decayFunction

```solidity
VotingDecayLibrary.DecayFunction public decayFunction;
```


## Functions
### constructor

Constructor to initialize the VotingDecayManager


```solidity
constructor(
    uint40 decayFreeWindow_,
    uint256 decayRatePerSecond_,
    VotingDecayLibrary.DecayFunction decayFunction_
)
    Ownable(msg.sender);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`decayFreeWindow_`|`uint40`|Initial decay-free window duration|
|`decayRatePerSecond_`|`uint256`|Initial decay rate per second|
|`decayFunction_`|`VotingDecayLibrary.DecayFunction`|Initial decay function type|


### setDecayRatePerSecond

Sets a new decay rate per second


```solidity
function setDecayRatePerSecond(uint256 newRatePerSecond) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newRatePerSecond`|`uint256`|New decay rate (in WAD format)|


### setDecayFreeWindow

Sets a new decay-free window duration


```solidity
function setDecayFreeWindow(uint40 newWindow) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newWindow`|`uint40`|New decay-free window duration in seconds|


### setDecayFunction

Sets a new decay function type


```solidity
function setDecayFunction(VotingDecayLibrary.DecayFunction newFunction) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newFunction`|`VotingDecayLibrary.DecayFunction`|New decay function (Linear or Exponential)|


### getVotingPower

Calculates the current voting power for an account


```solidity
function getVotingPower(address accountAddress, uint256 originalValue) public view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`accountAddress`|`address`|Address to calculate voting power for|
|`originalValue`|`uint256`|Original voting power value|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Current voting power after applying decay|


### getDecayFactor

Calculates the decay factor for an account


```solidity
function getDecayFactor(address accountAddress) public view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`accountAddress`|`address`|Address to calculate retention factor for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Current retention factor|


### getDecayInfo

Gets the decay information for an account


```solidity
function getDecayInfo(address accountAddress) public view returns (VotingDecayLibrary.DecayInfo memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`accountAddress`|`address`|Address to get decay info for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`VotingDecayLibrary.DecayInfo`|DecayInfo struct containing decay information|


### _initializeAccountIfNew

Internal function to initialize an account if it's new


```solidity
function _initializeAccountIfNew(address accountAddress) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`accountAddress`|`address`|Address of the account to initialize|


### _hasDecayInfo

Internal function to check if an account has decay info


```solidity
function _hasDecayInfo(address accountAddress) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`accountAddress`|`address`|Address of the account to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool indicating whether the account has decay info|


### _updateDecayFactor

Internal function to update the decay factor for an account


```solidity
function _updateDecayFactor(address accountAddress) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`accountAddress`|`address`|Address of the account to update|


### _resetDecay

Internal function to reset the decay for an account


```solidity
function _resetDecay(address accountAddress) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`accountAddress`|`address`|Address of the account to reset|


### _getDelegateTo

Internal function to get the delegate address for an account


```solidity
function _getDelegateTo(address accountAddress) internal view virtual returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`accountAddress`|`address`|Address of the account to get the delegate for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Address of the delegate|


