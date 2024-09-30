# IFleetCommanderConfigProvider
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/interfaces/IFleetCommanderConfigProvider.sol)

**Inherits:**
[IFleetCommanderConfigProviderErrors](/src/errors/IFleetCommanderConfigProviderErrors.sol/interface.IFleetCommanderConfigProviderErrors.md), [IFleetCommanderConfigProviderEvents](/src/events/IFleetCommanderConfigProviderEvents.sol/interface.IFleetCommanderConfigProviderEvents.md)

Interface for the FleetCommander contract, which manages asset allocation across multiple Arks


## Functions
### arks

Retrieves the ark address at the specified index


```solidity
function arks(uint256 index) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|The index of the ark in the arks array|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the ark at the specified index|


### getArks

Retrieves the arks currently linked to fleet


```solidity
function getArks() external view returns (address[] memory);
```

### getConfig

Retrieves the current fleet config


```solidity
function getConfig() external view returns (FleetConfig memory);
```

### isArkActive

Checks if the ark is part of the fleet


```solidity
function isArkActive(address ark) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ark`|`address`|The address of the Ark|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool Returns true if the ark is active, false otherwise.|


### addArk

Adds a new Ark


```solidity
function addArk(address ark) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ark`|`address`|The address of the new Ark|


### addArks

Adds multiple Arks in a batch


```solidity
function addArks(address[] calldata arks) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`arks`|`address[]`|Array of ark addresses|


### removeArk

Removes an existing Ark


```solidity
function removeArk(address ark) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ark`|`address`|The address of the Ark to remove|


### setFleetDepositCap

Sets a new deposit cap for Fleet


```solidity
function setFleetDepositCap(uint256 newDepositCap) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newDepositCap`|`uint256`|The new deposit cap|


### setArkDepositCap

Sets a new deposit cap for an Ark


```solidity
function setArkDepositCap(address ark, uint256 newDepositCap) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ark`|`address`|The address of the Ark|
|`newDepositCap`|`uint256`|The new deposit cap|


### setMinimumBufferBalance

*Sets the minimum buffer balance for the fleet commander.*


```solidity
function setMinimumBufferBalance(uint256 newMinimumBalance) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newMinimumBalance`|`uint256`|The new minimum buffer balance to be set.|


### setMaxRebalanceOperations

*Sets the minimum number of allowe rebalance operations.*


```solidity
function setMaxRebalanceOperations(uint256 newMaxRebalanceOperations) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newMaxRebalanceOperations`|`uint256`|The new maximum allowed rebalance operations.|


### setArkMaxRebalanceOutflow

Sets the maxRebalanceOutflow for an Ark

*Only callable by the governor*


```solidity
function setArkMaxRebalanceOutflow(address ark, uint256 newMaxRebalanceOutflow) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ark`|`address`|The address of the Ark|
|`newMaxRebalanceOutflow`|`uint256`|The new maxRebalanceOutflow value|


### setArkMaxRebalanceInflow

Sets the maxRebalanceInflow for an Ark

*Only callable by the governor*


```solidity
function setArkMaxRebalanceInflow(address ark, uint256 newMaxRebalanceInflow) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ark`|`address`|The address of the Ark|
|`newMaxRebalanceInflow`|`uint256`|The new maxRebalanceInflow value|


