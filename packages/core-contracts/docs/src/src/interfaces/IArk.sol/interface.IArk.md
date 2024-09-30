# IArk
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/02b633fc64591288020c32f3fcb6421ab62209d5/src/interfaces/IArk.sol)

**Inherits:**
[IArkAccessManaged](/src/interfaces/IArkAccessManaged.sol/interface.IArkAccessManaged.md), [IArkEvents](/src/events/IArkEvents.sol/interface.IArkEvents.md), [IArkErrors](/src/errors/IArkErrors.sol/interface.IArkErrors.md), [IArkConfigProvider](/src/interfaces/IArkConfigProvider.sol/interface.IArkConfigProvider.md)

Interface for the Ark contract, which manages funds and interacts with Rafts

*Inherits from IArkAccessManaged for access control and IArkEvents for event definitions*


## Functions
### totalAssets

Returns the current underlying balance of the Ark


```solidity
function totalAssets() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total assets in the Ark, in token precision|


### harvest

Triggers a harvest operation to collect rewards


```solidity
function harvest(bytes calldata additionalData)
    external
    returns (address[] memory rewardTokens, uint256[] memory rewardAmounts);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`additionalData`|`bytes`|Optional bytes that might be required by a specific protocol to harvest|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`rewardTokens`|`address[]`|The reward token addresses|
|`rewardAmounts`|`uint256[]`|The reward amounts|


### sweep

Sweeps tokens from the Ark


```solidity
function sweep(address[] calldata tokens)
    external
    returns (address[] memory sweptTokens, uint256[] memory sweptAmounts);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokens`|`address[]`|The tokens to sweep|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`sweptTokens`|`address[]`|The swept tokens|
|`sweptAmounts`|`uint256[]`|The swept amounts|


### board

Deposits (boards) tokens into the Ark


```solidity
function board(uint256 amount, bytes calldata boardData) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of tokens to deposit|
|`boardData`|`bytes`|Additional data that might be required by a specific protocol to deposit funds|


### disembark

Withdraws (disembarks) tokens from the Ark


```solidity
function disembark(uint256 amount, bytes calldata disembarkData) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of tokens to withdraw|
|`disembarkData`|`bytes`|Additional data that might be required by a specific protocol to withdraw funds|


### move

Moves tokens from one ark to another


```solidity
function move(uint256 amount, address receiver, bytes calldata boardData, bytes calldata disembarkData) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`| The amount of tokens to move|
|`receiver`|`address`|The address of the Ark the funds will be boarded to|
|`boardData`|`bytes`|Additional data that might be required by a specific protocol to board funds|
|`disembarkData`|`bytes`|Additional data that might be required by a specific protocol to disembark funds|


