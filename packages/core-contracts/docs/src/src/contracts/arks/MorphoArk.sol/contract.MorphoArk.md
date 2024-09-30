# MorphoArk
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/0276900cbe9b1188d82d1b9bcbb8c174e79a15a1/src/contracts/arks/MorphoArk.sol)

**Inherits:**
[Ark](/src/contracts/Ark.sol/abstract.Ark.md)

This contract manages a Morpho token strategy within the Ark system


## State Variables
### MORPHO
The Morpho Vault address


```solidity
IMorpho public immutable MORPHO;
```


### marketId
The market ID


```solidity
Id public marketId;
```


### marketParams
The market parameters


```solidity
MarketParams public marketParams;
```


## Functions
### constructor

Constructor for MorphoArk


```solidity
constructor(address _morpho, Id _marketId, ArkParams memory _arkParams) Ark(_arkParams);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_morpho`|`address`|The Morpho Vault address|
|`_marketId`|`Id`|The market ID|
|`_arkParams`|`ArkParams`||


### totalAssets

Returns the current underlying balance of the Ark


```solidity
function totalAssets() public view override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total assets in the Ark, in token precision|


### _board

Boards tokens into the Morpho Vault


```solidity
function _board(uint256 amount, bytes calldata) internal override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of tokens to board|
|`<none>`|`bytes`||


### _disembark

Disembarks tokens from the Morpho Vault


```solidity
function _disembark(uint256 amount, bytes calldata) internal override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of tokens to disembark|
|`<none>`|`bytes`||


### _harvest

*Internal function to harvest rewards based on the provided claim data.
This function decodes the claim data, iterates through the rewards, and claims them
from the respective rewards distributors. The claimed rewards are then transferred
to the configured raft address.*


```solidity
function _harvest(bytes calldata _claimData)
    internal
    override
    returns (address[] memory rewardTokens, uint256[] memory rewardAmounts);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_claimData`|`bytes`|The encoded claim data containing information about the rewards to be claimed.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`rewardTokens`|`address[]`|An array of addresses of the reward tokens that were claimed.|
|`rewardAmounts`|`uint256[]`|An array of amounts of the reward tokens that were claimed. The claim data is expected to be in the following format: - claimData.urd: An array of addresses of the rewards distributors. - claimData.rewards: An array of addresses of the rewards tokens. - claimData.claimable: An array of amounts of the rewards to be claimed. - claimData.proofs: An array of Merkle proofs to claim the rewards. Emits an {ArkHarvested} event upon successful harvesting of rewards.|


### _validateBoardData

No-op for validateBoardData function

*Calls the `claim` function of the `IUniversalRewardsDistributorBase` contract to claim rewards.*

*MorphoArk does not require any validation for board data*


```solidity
function _validateBoardData(bytes calldata data) internal override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`bytes`||


### _validateDisembarkData

No-op for validateDisembarkData function

*MorphoArk does not require any validation for disembark data*


```solidity
function _validateDisembarkData(bytes calldata data) internal override;
```

## Structs
### RewardsData

```solidity
struct RewardsData {
    address[] urd;
    address[] rewards;
    uint256[] claimable;
    bytes32[][] proofs;
}
```

