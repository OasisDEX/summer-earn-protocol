# BasePendleArk
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/0276900cbe9b1188d82d1b9bcbb8c174e79a15a1/src/contracts/arks/BasePendleArk.sol)

**Inherits:**
[Ark](/src/contracts/Ark.sol/abstract.Ark.md), [IPendleBaseArk](/src/interfaces/arks/IPendleBaseArk.sol/interface.IPendleBaseArk.md)

Base contract for Pendle-based Ark strategies

*This contract contains common functionality for Pendle LP and PT Arks*


## State Variables
### MAX_SLIPPAGE_PERCENTAGE
Maximum allowed slippage percentage


```solidity
Percentage public constant MAX_SLIPPAGE_PERCENTAGE = PERCENTAGE_100;
```


### MIN_ORACLE_DURATION
Minimum allowed oracle duration


```solidity
uint256 public constant MIN_ORACLE_DURATION = 15 minutes;
```


### market
Address of the current Pendle market


```solidity
address public market;
```


### router
Address of the Pendle router


```solidity
address public router;
```


### oracle
Address of the Pendle oracle


```solidity
address public immutable oracle;
```


### oracleDuration
Duration for the oracle to use when fetching rates


```solidity
uint32 public oracleDuration;
```


### SY
Standardized Yield token associated with the market


```solidity
IStandardizedYield public SY;
```


### PT
Principal Token associated with the market


```solidity
IPPrincipalToken public PT;
```


### YT
Yield Token associated with the market


```solidity
IPYieldToken public YT;
```


### slippagePercentage
Slippage tolerance for operations


```solidity
Percentage public slippagePercentage;
```


### marketExpiry
Expiry timestamp of the current market


```solidity
uint256 public marketExpiry;
```


### routerParams
Parameters for the Pendle router


```solidity
ApproxParams public routerParams;
```


### emptyLimitOrderData
Empty limit order data for Pendle operations


```solidity
LimitOrderData emptyLimitOrderData;
```


### emptySwap
Empty swap data for Pendle operations


```solidity
SwapData public emptySwap;
```


## Functions
### constructor

Constructor for BasePendleArk


```solidity
constructor(address _market, address _oracle, address _router, ArkParams memory _params) Ark(_params);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_market`|`address`|Address of the Pendle market|
|`_oracle`|`address`|Address of the Pendle oracle|
|`_router`|`address`|Address of the Pendle router|
|`_params`|`ArkParams`|ArkParams struct containing initialization parameters|


### setSlippagePercentage

Sets the slippage tolerance


```solidity
function setSlippagePercentage(Percentage _slippagePercentage) external onlyGovernor;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_slippagePercentage`|`Percentage`|New slippage tolerance|


### setOracleDuration

Sets the oracle duration


```solidity
function setOracleDuration(uint32 _oracleDuration) external onlyGovernor;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_oracleDuration`|`uint32`|New oracle duration|


### _board

Deposits assets into the Ark

*Rolls over to a new market if needed, then deposits tokens for Ark-specific tokens*


```solidity
function _board(uint256 amount, bytes calldata) internal override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of assets to deposit|
|`<none>`|`bytes`||


### _disembark

*This function handles redemption differently based on whether the market has expired:
1. If the market has expired:
- Use a 1:1 exchange ratio between PT / LP and asset (no slippage)
- Call _redeemTokensPostExpiry
2. If the market has not expired:
- Calculate PT / LP amount needed, accounting for slippage
- Call _redeemTokens
The slippage is applied differently in each case to protect the user from unfavorable price movements.*


```solidity
function _disembark(uint256 amount, bytes calldata) internal override;
```

### _harvest

Harvests rewards from the market


```solidity
function _harvest(bytes calldata)
    internal
    override
    returns (address[] memory rewardTokens, uint256[] memory rewardAmounts);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`rewardTokens`|`address[]`|The addresses of the reward tokens|
|`rewardAmounts`|`uint256[]`|The amounts of the reward tokens|


### _setupRouterParams

Internal function to set up router parameters


```solidity
function _setupRouterParams() internal;
```

### _updateMarketData

Updates the market data (expiry)


```solidity
function _updateMarketData() internal;
```

### _updateMarketAndTokens

Updates market and token addresses, and sets up new approvals


```solidity
function _updateMarketAndTokens(address newMarket) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newMarket`|`address`|Address of the new market|


### _rolloverIfNeeded

Rolls over to a new market if the current one has expired


```solidity
function _rolloverIfNeeded() internal;
```

### _assetToArkTokens

Converts asset amount to Ark-specific tokens (PT or LP)


```solidity
function _assetToArkTokens(uint256 amount) internal view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of asset|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Equivalent amount of Ark-specific tokens|


### _arkTokensToAsset

Converts Ark-specific tokens (PT or LP) to asset amount


```solidity
function _arkTokensToAsset(uint256 amount) internal view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of Ark-specific tokens|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Equivalent amount of asset|


### _isOracleReady

Checks if the Pendle oracle is ready for the given market


```solidity
function _isOracleReady(address _market) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_market`|`address`|The address of the Pendle market to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool Returns true if the oracle is ready, false otherwise|


### _redeemTokens

Abstract method to redeem tokens from the Ark from active market


```solidity
function _redeemTokens(uint256 amount, uint256 minTokenOut) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of Ark-specific tokens to redeem|
|`minTokenOut`|`uint256`|Minimum amount of underlying tokens to receive|


### _redeemTokensPostExpiry

Abstract method to redeem tokens after market expiry


```solidity
function _redeemTokensPostExpiry(uint256 amount, uint256 minTokenOut) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of Ark-specific tokens to redeem|
|`minTokenOut`|`uint256`|Minimum amount of underlying tokens to receive|


### _depositTokenForArkToken

Abstract method to deposit tokens for Ark-specific tokens


```solidity
function _depositTokenForArkToken(uint256 amount) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount of underlying tokens to deposit|


### _setupApprovals

Sets up token approvals


```solidity
function _setupApprovals() internal virtual;
```

### nextMarket

Finds the next valid market


```solidity
function nextMarket() public view virtual returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Address of the next market|


### _redeemAllTokensFromExpiredMarket

Redeems all tokens from the current position


```solidity
function _redeemAllTokensFromExpiredMarket() internal virtual;
```

### _balanceOfArkTokens

Abstract method to get the balance of Ark-specific tokens


```solidity
function _balanceOfArkTokens() internal view virtual returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Balance of Ark-specific tokens|


### _fetchArkTokenToAssetRate

Fetches the current exchange rate between Ark-specific tokens and assets


```solidity
function _fetchArkTokenToAssetRate() internal view virtual returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Current exchange rate|


### totalAssets

Calculates the total assets held by the Ark

*We handle this differently based on whether the market has expired:
1. If the market has expired: return the exact PT / LP balance (1:1 ratio)
2. If the market has not expired: subtract slippage from the calculated asset amount
By subtracting slippage from total assets when the market is active, we ensure that:
a) We provide a conservative estimate of the Ark's value
b) We can always fulfill withdrawal requests, even in volatile market conditions
c) Users might receive slightly more than expected, which is beneficial for them*


```solidity
function totalAssets() public view override returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total assets in underlying token|


