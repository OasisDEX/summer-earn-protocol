# IArkConfigProvider
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/interfaces/IArkConfigProvider.sol)

**Inherits:**
[IArkAccessManaged](/src/interfaces/IArkAccessManaged.sol/interface.IArkAccessManaged.md), [IArkConfigProviderErrors](/src/errors/IArkConfigProviderErrors.sol/interface.IArkConfigProviderErrors.md), [IArkConfigProviderEvents](/src/events/IArkConfigProviderEvents.sol/interface.IArkConfigProviderEvents.md)

Interface for configuration of Ark contracts

*Inherits from IArkAccessManaged for access control and IArkConfigProviderEvents for event definitions*


## Functions
### name

*Returns the name of the Ark.*


```solidity
function name() external view returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The name of the Ark as a string.|


### raft

Returns the address of the associated Raft contract


```solidity
function raft() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the Raft contract|


### depositCap

Returns the deposit cap for this Ark


```solidity
function depositCap() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The maximum amount of tokens that can be deposited into the Ark|


### maxRebalanceInflow

Returns the maximum amount that can be moved to this Ark in one rebalance


```solidity
function maxRebalanceInflow() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|maximum amount that can be moved to this Ark in one rebalance|


### maxRebalanceOutflow

Returns the maximum amount that can be moved from this Ark in one rebalance


```solidity
function maxRebalanceOutflow() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|maximum amount that can be moved from this Ark in one rebalance|


### requiresKeeperData

Returns whether the Ark requires keeper data to board/disembark


```solidity
function requiresKeeperData() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|true if the Ark requires keeper data, false otherwise|


### token

Returns the ERC20 token managed by this Ark


```solidity
function token() external view returns (IERC20);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IERC20`|The IERC20 interface of the managed token|


### commander

Returns the address of the Fleet commander managing the ark


```solidity
function commander() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|address Address of Fleet commander managing the ark if a Commander is assigned, address(0) otherwise|


### setDepositCap

Sets a new maximum allocation for the Ark


```solidity
function setDepositCap(uint256 newDepositCap) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newDepositCap`|`uint256`|The new maximum allocation amount|


### setMaxRebalanceOutflow

Sets a new maximum amount that can be moved from the Ark in one rebalance


```solidity
function setMaxRebalanceOutflow(uint256 newMaxRebalanceOutflow) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newMaxRebalanceOutflow`|`uint256`|The new maximum amount that can be moved from the Ark|


### setMaxRebalanceInflow

Sets a new maximum amount that can be moved to the Ark in one rebalance


```solidity
function setMaxRebalanceInflow(uint256 newMaxRebalanceInflow) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newMaxRebalanceInflow`|`uint256`|The new maximum amount that can be moved to the Ark|


