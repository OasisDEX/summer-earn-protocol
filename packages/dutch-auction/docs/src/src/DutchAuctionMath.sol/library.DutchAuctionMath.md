# DutchAuctionMath
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/c6aec955808af03c05b24342f892f71facee60db/src/DutchAuctionMath.sol)

**Author:**
halaprix

This library provides mathematical functions for Dutch auction calculations with support for various token
decimals

*Uses PRBMath library for precise calculations with fixed-point numbers and TokenLibrary for decimal conversions*


## Functions
### linearDecay

Calculates the current price based on linear decay

*The price decreases linearly from startPrice to endPrice over the duration*

*Process:
1. Convert start and end prices to 18 decimals for precise calculation
2. Calculate the price difference and decay amount using 18 decimal precision
3. Subtract the decay amount from the start price
4. Convert the result back to the desired number of decimals*


```solidity
function linearDecay(
    uint256 startPrice,
    uint256 endPrice,
    uint256 timeElapsed,
    uint256 totalDuration,
    uint8 priceDecimals,
    uint8 resultDecimals
)
    internal
    pure
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`startPrice`|`uint256`|The starting price of the auction|
|`endPrice`|`uint256`|The ending price of the auction|
|`timeElapsed`|`uint256`|The time elapsed since the start of the auction|
|`totalDuration`|`uint256`|The total duration of the auction|
|`priceDecimals`|`uint8`|The number of decimals for the price values|
|`resultDecimals`|`uint8`|The desired number of decimals for the result|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current price based on linear decay|


### exponentialDecay

Calculates the current price based on exponential decay

*The price decreases exponentially from startPrice to endPrice over the duration*

*Process:
1. Convert start and end prices to 18 decimals for precise calculation
2. Calculate the remaining time and its square
3. Calculate the decay amount using the formula: priceDifference * (remainingTime^2 / totalDuration^2)
4. Add the decay amount to the end price
5. Convert the result back to the desired number of decimals*


```solidity
function exponentialDecay(
    uint256 startPrice,
    uint256 endPrice,
    uint256 timeElapsed,
    uint256 totalDuration,
    uint8 priceDecimals,
    uint8 resultDecimals
)
    internal
    pure
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`startPrice`|`uint256`|The starting price of the auction|
|`endPrice`|`uint256`|The ending price of the auction|
|`timeElapsed`|`uint256`|The time elapsed since the start of the auction|
|`totalDuration`|`uint256`|The total duration of the auction|
|`priceDecimals`|`uint8`|The number of decimals for the price values|
|`resultDecimals`|`uint8`|The desired number of decimals for the result|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current price based on exponential decay|


### calculateTotalCost

Calculates the total cost for a given price and amount, considering different token decimals

*Converts values to 18 decimals using TokenLibrary, performs the calculation, and converts the result back*

*Process:
1. Convert both price and amount to 18 decimals for precise calculation
2. Multiply the converted price and amount using PRBMath's high-precision operations
3. Convert the result back to the desired number of decimals*

*Note: This function ensures high precision by performing all intermediate calculations
with 18 decimal places, regardless of the input or output decimal specifications.*


```solidity
function calculateTotalCost(
    uint256 price,
    uint256 amount,
    uint8 priceDecimals,
    uint8 amountDecimals,
    uint8 resultDecimals
)
    internal
    pure
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|The price per unit|
|`amount`|`uint256`|The number of units|
|`priceDecimals`|`uint8`|The number of decimals for the price token|
|`amountDecimals`|`uint8`|The number of decimals for the amount token|
|`resultDecimals`|`uint8`|The desired number of decimals for the result|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total cost|


