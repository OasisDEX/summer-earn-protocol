# Tipper
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/contracts/Tipper.sol)

**Inherits:**
[ITipper](/src/interfaces/ITipper.sol/interface.ITipper.md)

Contract implementing tip accrual functionality


## State Variables
### tipRate
The current tip rate (as Percentage)

*Percentages have 18 decimals of precision*


```solidity
Percentage public tipRate;
```


### lastTipTimestamp
The timestamp of the last tip accrual


```solidity
uint256 public lastTipTimestamp;
```


### tipJar
The address where accrued tips are sent


```solidity
address public tipJar;
```


### manager
The protocol configuration manager


```solidity
IConfigurationManager public manager;
```


## Functions
### constructor

Initializes the TipAccruer contract


```solidity
constructor(address configurationManager, Percentage initialTipRate);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`configurationManager`|`address`|The address of the ConfigurationManager contract|
|`initialTipRate`|`Percentage`|The initialTipRate for the Fleet|


### _mintTip


```solidity
function _mintTip(address account, uint256 amount) internal virtual;
```

### _setTipRate

Sets a new tip rate

*Only callable by the FleetCommander. Accrues tips before changing the rate.*


```solidity
function _setTipRate(Percentage newTipRate) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newTipRate`|`Percentage`|The new tip rate to set (in basis points)|


### _setTipJar

Sets a new tip jar address

*Only callable by the FleetCommander*


```solidity
function _setTipJar() internal;
```

### _accrueTip

Accrues tips based on the current tip rate and time elapsed

*Only callable by the FleetCommander*


```solidity
function _accrueTip() internal returns (uint256 tippedShares);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`tippedShares`|`uint256`|The amount of tips accrued in shares|


### _calculateTip


```solidity
function _calculateTip(uint256 totalShares, uint256 timeElapsed) internal view returns (uint256);
```

### estimateAccruedTip

Estimates the amount of tips accrued since the last tip accrual


```solidity
function estimateAccruedTip() public view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The estimated amount of accrued tips|


