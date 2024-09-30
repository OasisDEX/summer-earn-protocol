# ITipper
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/02b633fc64591288020c32f3fcb6421ab62209d5/src/interfaces/ITipper.sol)

**Inherits:**
[ITipperEvents](/src/events/ITipperEvents.sol/interface.ITipperEvents.md), [ITipperErrors](/src/errors/ITipperErrors.sol/interface.ITipperErrors.md)

Interface for the tip accrual functionality in the FleetCommander contract

*This interface defines the events and functions related to tip accrual and management*


## Functions
### tipRate

Get the current tip rate

*A tip rate of 100 * 1e18 represents 100%*


```solidity
function tipRate() external view returns (Percentage);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Percentage`|The current tip rate|


### lastTipTimestamp

Get the timestamp of the last tip accrual


```solidity
function lastTipTimestamp() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The Unix timestamp of when tips were last accrued|


### tipJar

Get the current tip jar address


```solidity
function tipJar() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address where accrued tips are sent|


### estimateAccruedTip

Estimate the amount of tips accrued since the last tip accrual

*This function performs a calculation without changing the contract's state*


```solidity
function estimateAccruedTip() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The estimated amount of accrued tips in the underlying asset's smallest unit|


