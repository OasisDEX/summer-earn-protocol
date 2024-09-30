# ERC4626Ark
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/contracts/arks/ERC4626Ark.sol)

**Inherits:**
[Ark](/src/contracts/Ark.sol/abstract.Ark.md)

This contract allows the Fleet Commander to interact with any ERC4626 vault

*A generic Ark implementation for any ERC4626-compliant vault*


## State Variables
### vault
The ERC4626 vault this Ark interacts with


```solidity
IERC4626 public immutable vault;
```


## Functions
### constructor

*Constructor to set up the ERC4626Ark*


```solidity
constructor(address _vault, ArkParams memory _params) Ark(_params);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_vault`|`address`|Address of the ERC4626-compliant vault|
|`_params`|`ArkParams`|ArkParams struct containing necessary parameters for Ark initialization|


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

Internal function to deposit assets into the vault


```solidity
function _board(uint256 amount, bytes calldata) internal override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of assets to deposit|
|`<none>`|`bytes`||


### _disembark

Internal function to withdraw assets from the vault


```solidity
function _disembark(uint256 amount, bytes calldata) internal override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of assets to withdraw|
|`<none>`|`bytes`||


### _harvest

Internal function for harvesting rewards

*This function is a no-op for most ERC4626 vaults as they automatically accrue interest*


```solidity
function _harvest(bytes calldata)
    internal
    pure
    override
    returns (address[] memory rewardTokens, uint256[] memory rewardAmounts);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`rewardTokens`|`address[]`|The addresses of the reward tokens|
|`rewardAmounts`|`uint256[]`|The amounts of the reward tokens|


### _validateBoardData

No-op for validateBoardData function


```solidity
function _validateBoardData(bytes calldata) internal override;
```

### _validateDisembarkData

No-op for validateDisembarkData function


```solidity
function _validateDisembarkData(bytes calldata) internal override;
```

