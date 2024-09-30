# MetaMorphoArk
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/contracts/arks/MetaMorphoArk.sol)

**Inherits:**
[Ark](/src/contracts/Ark.sol/abstract.Ark.md)

This contract manages a Morpho Vaulttoken strategy within the Ark system


## State Variables
### metaMorpho
The Morpho Vault address


```solidity
IMetaMorpho public immutable metaMorpho;
```


## Functions
### constructor

Constructor for MetaMorphoArk


```solidity
constructor(address _metaMorpho, ArkParams memory _params) Ark(_params);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_metaMorpho`|`address`|Address of the Morpho Vault|
|`_params`|`ArkParams`|ArkParams struct containing initialization parameters|


### totalAssets

Returns the current underlying balance of the Ark


```solidity
function totalAssets() public view override returns (uint256 assets);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|The total assets in the Ark, in token precision|


### _board

Boards into the MetaMorpho Vault


```solidity
function _board(uint256 amount, bytes calldata) internal override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of tokens to board|
|`<none>`|`bytes`||


### _disembark

Disembarks from the MetaMorpho Vault


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

Validates the board data

*Calls the `claim` function of the `IUniversalRewardsDistributorBase` contract to claim rewards.*

*MetaMorpho Ark does not require any validation for board data*


```solidity
function _validateBoardData(bytes calldata) internal override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`||


### _validateDisembarkData

Validates the disembark data

*MetaMorpho Ark does not require any validation for board or disembark data*


```solidity
function _validateDisembarkData(bytes calldata) internal override;
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

