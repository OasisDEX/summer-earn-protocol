# BufferArk
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/0276900cbe9b1188d82d1b9bcbb8c174e79a15a1/src/contracts/arks/BufferArk.sol)

**Inherits:**
[Ark](/src/contracts/Ark.sol/abstract.Ark.md)

Specialized Ark for Buffer operations. Funds in buffer are not deployed and are not subject to any
yield-generating strategies.


## State Variables
### bufferPool
The Buffer pool address


```solidity
address public bufferPool;
```


## Functions
### constructor


```solidity
constructor(ArkParams memory _params) Ark(_params);
```

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

No-op for board function

*tokens are transferred using Ark.board()*


```solidity
function _board(uint256 amount, bytes calldata) internal override;
```

### _disembark

No-op for disembark function

*tokens are transferred using Ark.disembark()*


```solidity
function _disembark(uint256 amount, bytes calldata data) internal override;
```

### _harvest

No-op for harvest function

*BufferArk does not generate any rewards, so this function is not implemented*


```solidity
function _harvest(bytes calldata)
    internal
    override
    returns (address[] memory rewardTokens, uint256[] memory rewardAmounts);
```

### _validateBoardData

No-op for validateBoardData function

*BufferArk does not require any validation for board data*


```solidity
function _validateBoardData(bytes calldata data) internal override;
```

### _validateDisembarkData

No-op for validateDisembarkData function

*BufferArk does not require any validation for disembark data*


```solidity
function _validateDisembarkData(bytes calldata data) internal override;
```

