# DecayFunctions
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/c6aec955808af03c05b24342f892f71facee60db/src/DecayFunctions.sol)

**Author:**
halaprix

This library provides functions to calculate price decay for Dutch auctions

*Implements both linear and exponential decay functions*


## Functions
### calculateDecay

Calculates the current price based on the specified decay type

*This function acts as a wrapper for the specific decay calculations in DutchAuctionMath*

*Calculation process:
1. Check if the auction has ended (timeElapsed >= totalDuration)
2. If the auction has ended, return the end price
3. If the auction is still active, calculate the current price using the specified decay function
4. For Linear decay, use DutchAuctionMath.linearDecay
5. For Exponential decay, use DutchAuctionMath.exponentialDecay*

*Note on precision:
- All price calculations are performed with high precision using the DutchAuctionMath library
- The input prices and result can have different decimal places, allowing for flexible token configurations*

*Usage:
- This function should be called periodically to get the current price of the auctioned item
- It can handle different token decimals for both input and output, making it versatile for various token pairs*


```solidity
function calculateDecay(
    DecayType decayType,
    uint256 startPrice,
    uint256 endPrice,
    uint256 timeElapsed,
    uint256 totalDuration,
    uint8 decimals,
    uint8 resultDecimals
)
    internal
    pure
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`decayType`|`DecayType`|The type of decay function to use (Linear or Exponential)|
|`startPrice`|`uint256`|The starting price of the auction (in token units)|
|`endPrice`|`uint256`|The ending price of the auction (in token units)|
|`timeElapsed`|`uint256`|The time elapsed since the start of the auction|
|`totalDuration`|`uint256`|The total duration of the auction|
|`decimals`|`uint8`|The number of decimals for the input prices|
|`resultDecimals`|`uint8`|The desired number of decimals for the result|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current price based on the specified decay function|


## Errors
### InvalidDecayType
Thrown when the decay type is invalid


```solidity
error InvalidDecayType();
```

## Enums
### DecayType
Enum representing the types of decay functions available

*Used to select between linear and exponential decay in calculations*


```solidity
enum DecayType {
    Linear,
    Exponential
}
```

