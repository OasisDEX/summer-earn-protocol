# PendleLPArk
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/02b633fc64591288020c32f3fcb6421ab62209d5/src/contracts/arks/PendleLPArk.sol)

**Inherits:**
[BasePendleArk](/src/contracts/arks/BasePendleArk.sol/abstract.BasePendleArk.md)

This contract manages a Pendle LP token strategy within the Ark system

*Inherits from BasePendleArk and implements LP-specific logic*


## Functions
### constructor

Constructor for PendleLPArk


```solidity
constructor(
    address _market,
    address _oracle,
    address _router,
    ArkParams memory _params
)
    BasePendleArk(_market, _oracle, _router, _params);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_market`|`address`|Address of the Pendle market|
|`_oracle`|`address`|Address of the Pendle oracle|
|`_router`|`address`|Address of the Pendle router|
|`_params`|`ArkParams`|ArkParams struct containing initialization parameters|


### _setupApprovals

Set up token approvals for Pendle interactions


```solidity
function _setupApprovals() internal override;
```

### _depositTokenForArkToken

Deposits tokens for LP

*Checks for market expiry, calculates minimum LP output with slippage, and adds liquidity
1. Check if the market has expired. If so, revert the transaction.
2. Calculate the minimum LP tokens to receive based on the input amount and slippage:
- We use the Pendle LP oracle to get the current LP to asset rate.
- We convert the input amount to LP tokens using this rate.
- We subtract the slippage percentage from this amount to set a minimum acceptable output.
3. Prepare the input token data for the Pendle router.
4. Call the Pendle router to add liquidity using a single token (our asset).
Slippage protection ensures we receive at least the calculated minimum LP tokens.
This guards against price movements between our calculation and the actual swap execution.
The use of a TWAP oracle helps mitigate the risk of short-term price manipulations.*


```solidity
function _depositTokenForArkToken(uint256 _amount) internal override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_amount`|`uint256`|Amount of tokens to deposit|


### _redeemTokens

Redeems LP tokens for underlying assets


```solidity
function _redeemTokens(uint256 amount, uint256 minTokenOut) internal override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of LP tokens to redeem|
|`minTokenOut`|`uint256`|Minimum amount of underlying tokens to receive|


### _redeemTokensPostExpiry

Redeems LP tokens for underlying assets after market expiry


```solidity
function _redeemTokensPostExpiry(uint256 amount, uint256 minTokenOut) internal override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of assets to redeem|
|`minTokenOut`|`uint256`|Minimum amount of underlying tokens to receive|


### _removeLiquidity

Internal function to remove liquidity from the Pendle market


```solidity
function _removeLiquidity(uint256 lpAmount, uint256 minTokenOut) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`lpAmount`|`uint256`|Amount of LP tokens to remove|
|`minTokenOut`|`uint256`|Minimum amount of underlying tokens to receive|


### _redeemAllTokensFromExpiredMarket

Redeems all LP tokens to underlying tokens


```solidity
function _redeemAllTokensFromExpiredMarket() internal override;
```

### nextMarket

Finds the next valid market

*TODO: Implement logic to find the next valid market*


```solidity
function nextMarket() public pure override returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Address of the next market|


### _fetchArkTokenToAssetRate

Fetches the LP to Asset rate from the PendlePYLpOracle contract


```solidity
function _fetchArkTokenToAssetRate() internal view override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The LP to Asset rate|


### _balanceOfArkTokens

Returns the balance of LP tokens held by the contract


```solidity
function _balanceOfArkTokens() internal view override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Balance of LP tokens|


### _validateBoardData


```solidity
function _validateBoardData(bytes calldata data) internal override;
```

### _validateDisembarkData


```solidity
function _validateDisembarkData(bytes calldata data) internal override;
```

