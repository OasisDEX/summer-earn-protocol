# IConfigurationManager
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/interfaces/IConfigurationManager.sol)

**Inherits:**
[IConfigurationManagerEvents](/src/events/IConfigurationManagerEvents.sol/interface.IConfigurationManagerEvents.md), [IConfigurationManagerErrors](/src/errors/IConfigurationManagerErrors.sol/interface.IConfigurationManagerErrors.md)

Interface for the ConfigurationManager contract, which manages system-wide parameters

*This interface defines the getters and setters for system-wide parameters*


## Functions
### initialize

Initialize the ConfigurationManager contract

*Can only be called by the governor*


```solidity
function initialize(ConfigurationManagerParams memory params) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params`|`ConfigurationManagerParams`|The parameters to initialize the contract with|


### raft

Get the address of the Raft contract


```solidity
function raft() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the Raft contract|


### tipJar

Get the current tip jar address


```solidity
function tipJar() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The current tip jar address|


### treasury

Get the current treasury address


```solidity
function treasury() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The current treasury address|


### setRaft

Set a new address for the Raft contract

*Can only be called by the governor*


```solidity
function setRaft(address newRaft) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newRaft`|`address`|The new address for the Raft contract|


### setTipJar

Set a new tip ar address

*Can only be called by the governor*


```solidity
function setTipJar(address newTipJar) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newTipJar`|`address`|The address of the new tip jar|


### setTreasury

Set a new treasury address

*Can only be called by the governor*


```solidity
function setTreasury(address newTreasury) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newTreasury`|`address`|The address of the new treasury|


