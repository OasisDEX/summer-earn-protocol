# CompoundV3Ark
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/contracts/arks/CompoundV3Ark.sol)

**Inherits:**
[Ark](/src/contracts/Ark.sol/abstract.Ark.md)

Implementation of Ark for Compound V3 protocol

*This contract manages deposits, withdrawals, and reward harvesting for Compound V3*


## State Variables
### comet
The Compound V3 Comet contract


```solidity
IComet public comet;
```


### cometRewards
The Compound V3 CometRewards contract


```solidity
ICometRewards public cometRewards;
```


## Functions
### constructor

Constructor for CompoundV3Ark


```solidity
constructor(address _comet, address _cometRewards, ArkParams memory _params) Ark(_params);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_comet`|`address`|Address of the Compound V3 Comet contract|
|`_cometRewards`|`address`|Address of the Compound V3 CometRewards contract|
|`_params`|`ArkParams`|ArkParams struct containing initialization parameters|


### totalAssets

Returns the current underlying balance of the Ark


```solidity
function totalAssets() public view override returns (uint256 suppliedAssets);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`suppliedAssets`|`uint256`|The total assets in the Ark, in token precision|


### _board

Deposits assets into Compound V3


```solidity
function _board(uint256 amount, bytes calldata) internal override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of assets to deposit|
|`<none>`|`bytes`||


### _disembark

Withdraws assets from Compound V3


```solidity
function _disembark(uint256 amount, bytes calldata) internal override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of assets to withdraw|
|`<none>`|`bytes`||


### _harvest

Harvests rewards from Compound V3


```solidity
function _harvest(bytes calldata data)
    internal
    override
    returns (address[] memory rewardTokens, uint256[] memory rewardAmounts);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`bytes`|Encoded RewardsData struct containing reward token information|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`rewardTokens`|`address[]`|Array of reward token addresses|
|`rewardAmounts`|`uint256[]`|Array of reward token amounts|


### _validateBoardData

Validates the boarding data (unused in this implementation)


```solidity
function _validateBoardData(bytes calldata data) internal override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`bytes`|The boarding data to validate|


### _validateDisembarkData

Validates the disembarking data (unused in this implementation)


```solidity
function _validateDisembarkData(bytes calldata data) internal override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`bytes`|The disembarking data to validate|


## Structs
### RewardsData
Struct to hold reward token information


```solidity
struct RewardsData {
    address rewardToken;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`rewardToken`|`address`|The address of the reward token|

