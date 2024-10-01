# AaveV3Ark
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/0276900cbe9b1188d82d1b9bcbb8c174e79a15a1/src/contracts/arks/AaveV3Ark.sol)

**Inherits:**
[Ark](/src/contracts/Ark.sol/abstract.Ark.md)

This contract manages a Aave V3 token strategy within the Ark system


## State Variables
### aToken
The Aave V3 aToken address


```solidity
address public aToken;
```


### aaveV3Pool
The Aave V3 pool address


```solidity
IPoolV3 public aaveV3Pool;
```


### aaveV3DataProvider
The Aave V3 data provider address


```solidity
IPoolDataProvider public aaveV3DataProvider;
```


### rewardsController
The Aave V3 rewards controller address


```solidity
IRewardsController public rewardsController;
```


## Functions
### constructor

Constructor for AaveV3Ark


```solidity
constructor(address _aaveV3Pool, address _rewardsController, ArkParams memory _params) Ark(_params);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_aaveV3Pool`|`address`|Address of the Aave V3 pool|
|`_rewardsController`|`address`|Address of the Aave V3 rewards controller|
|`_params`|`ArkParams`|ArkParams struct containing initialization parameters|


### totalAssets

Returns the current underlying balance of the Ark


```solidity
function totalAssets() public view override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total assets in the Ark, in token precision|


### _harvest

Harvests rewards from the Aave V3 pool


```solidity
function _harvest(bytes calldata data)
    internal
    override
    returns (address[] memory rewardTokens, uint256[] memory rewardAmounts);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`bytes`|Additional data for the harvest operation|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`rewardTokens`|`address[]`|Array of reward tokens|
|`rewardAmounts`|`uint256[]`|Array of reward amounts|


### _board

Boards the Ark by supplying the specified amount of tokens to the Aave V3 pool


```solidity
function _board(uint256 amount, bytes calldata) internal override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of tokens to supply|
|`<none>`|`bytes`||


### _disembark

Disembarks the Ark by withdrawing the specified amount of tokens from the Aave V3 pool


```solidity
function _disembark(uint256 amount, bytes calldata) internal override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of tokens to withdraw|
|`<none>`|`bytes`||


### _validateBoardData

Validates the board data

*Aave V3 Ark does not require any validation for board data*


```solidity
function _validateBoardData(bytes calldata ta) internal override;
```

### _validateDisembarkData

Validates the disembark data

*Aave V3 Ark does not require any validation for board or disembark data*


```solidity
function _validateDisembarkData(bytes calldata) internal override;
```

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

