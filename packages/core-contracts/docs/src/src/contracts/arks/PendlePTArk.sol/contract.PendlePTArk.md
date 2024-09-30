# PendlePTArk
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/02b633fc64591288020c32f3fcb6421ab62209d5/src/contracts/arks/PendlePTArk.sol)

**Inherits:**
[BasePendleArk](/src/contracts/arks/BasePendleArk.sol/abstract.BasePendleArk.md)

This contract manages a Pendle Principal Token (PT) strategy within the Ark system

*Inherits from BasePendleArk and implements PT-specific logic*


## Functions
### constructor

Constructor for PendlePTArk


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

Deposits tokens and swaps them for Principal Tokens (PT)

*Checks for market expiry, calculates minimum PT output with slippage, and executes the swap*

*This function performs the following steps:
1. Check if the market has expired, revert if it has
2. Calculate the minimum PT output based on the current exchange rate and slippage
3. Prepare the input token data for the Pendle router
4. Execute the swap using Pendle's router
We use slippage protection here to ensure we receive at least the calculated minimum PT tokens.
This protects against sudden price movements between our calculation and the actual swap execution.*


```solidity
function _depositTokenForArkToken(uint256 _amount) internal override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_amount`|`uint256`|Amount of tokens to deposit|


### _redeemTokens

Redeems PT for underlying tokens before market expiry


```solidity
function _redeemTokens(uint256 amount, uint256 minTokenOut) internal override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of PT to redeem|
|`minTokenOut`|`uint256`|Minimum amount of underlying tokens to receive|


### _redeemTokensPostExpiry

Redeems PT for underlying tokens after market expiry


```solidity
function _redeemTokensPostExpiry(uint256 amount, uint256 minTokenOut) internal override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of PT to redeem|
|`minTokenOut`|`uint256`|Minimum amount of underlying tokens to receive|


### _redeemTokenFromPtPostExpiry

Redeems PT for underlying tokens after market expiry

*Redeems PT to SY using Pendle's router, then redeems SY to underlying token
1. Redeem PT to SY using Pendle's router
2. Redeem SY to underlying token
No slippage is applied as the exchange rate is fixed post-expiry*


```solidity
function _redeemTokenFromPtPostExpiry(uint256 ptAmount, uint256 minTokenOut) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ptAmount`|`uint256`|Amount of PT to redeem|
|`minTokenOut`|`uint256`|Minimum amount of underlying tokens to receive|


### _redeemTokenFromPtBeforeExpiry

Redeems PT for underlying tokens before market expiry

*Executes the swap using Pendle's router with slippage protection
1. Prepare the token output data for the swap
2. Execute the swap using Pendle's router
Slippage protection is applied to ensure the minimum token output*


```solidity
function _redeemTokenFromPtBeforeExpiry(uint256 ptAmount, uint256 minTokenOut) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ptAmount`|`uint256`|Amount of PT to redeem|
|`minTokenOut`|`uint256`|Minimum amount of underlying tokens to receive|


### _redeemAllTokensFromExpiredMarket

Redeems all PT for underlying tokens after market expiry


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

Fetches the PT to Asset rate from the PendlePYLpOracle contract


```solidity
function _fetchArkTokenToAssetRate() internal view override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The PT to Asset rate as a uint256 value|


### _balanceOfArkTokens

Returns the balance of PT held by the contract


```solidity
function _balanceOfArkTokens() internal view override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Balance of PT|


### _validateBoardData


```solidity
function _validateBoardData(bytes calldata data) internal override;
```

### _validateDisembarkData


```solidity
function _validateDisembarkData(bytes calldata data) internal override;
```

