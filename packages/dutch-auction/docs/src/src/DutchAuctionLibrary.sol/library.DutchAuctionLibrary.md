# DutchAuctionLibrary
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/c6aec955808af03c05b24342f892f71facee60db/src/DutchAuctionLibrary.sol)

**Author:**
halaprix

This library implements core functionality for running Dutch auctions

*This library is designed to be used by a contract managing multiple auctions*

*Auction Mechanics:
1. Auction Lifecycle:
- Creation: An auction is created with specified parameters (tokens, duration, prices, etc.).
- Active Period: The auction is active from its start time until its end time or until all tokens are sold.
- Finalization: The auction is finalized either when all tokens are sold or after the end time is reached.
2. Price Movement:
- The price is calculated on-demand based on the current timestamp using a specified decay function.
- It's not updated per block, but rather computed when `getCurrentPrice` is called, using current timestamp.
- This ensures smooth price decay over time, independent of block creation.
3. Buying Limits:
- Users can buy any amount of tokens up to the remaining amount in the auction.
- There's no minimum purchase amount enforced by the contract.
4. Price Calculation and Rounding:
- The current price is calculated using the specified decay function (linear or exponential).
- Rounding is done towards zero (floor) to ensure the contract never overcharges.
- For utmost precision, all calculations use the PRBMath library for fixed-point arithmetic.
5. Token Handling:
- The auctioning contract must be pre-approved to spend the tokens used for payment.
- Tokens should be transferred to the auctioning contract before or during auction creation.
- The contract holds the tokens and transfers them to buyers upon successful purchases.
6. Kicker Reward:
- A portion of the auctioned tokens is set aside as a reward for the auction initiator (kicker).
- This reward is transferred to the kicker immediately upon auction creation.
7. Unsold Tokens:
- Any unsold tokens at the end of the auction are transferred to a specified recipient address.
- This transfer occurs during the finalization of the auction.*


## Functions
### createAuction

Creates a new Dutch auction

*This function initializes a new auction with the given parameters*


```solidity
function createAuction(AuctionParams memory params) external returns (Auction memory auction);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params`|`AuctionParams`|The parameters for the new auction|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`auction`|`Auction`|The created Auction struct|


### getCurrentPrice

Calculates the current price of tokens in an ongoing auction

*This function computes the price based on the elapsed time and decay function*


```solidity
function getCurrentPrice(Auction memory auction) public view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`auction`|`Auction`|The Auction struct|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current price of tokens in the auction|


### buyTokens

Allows a user to purchase tokens from an ongoing auction

*This function handles the token purchase, including price calculation and token transfers*


```solidity
function buyTokens(Auction storage auction, uint256 _amount) internal returns (uint256 totalCost);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`auction`|`Auction`|The storage pointer to the auction|
|`_amount`|`uint256`|The number of tokens to purchase|


### finalizeAuction

Finalizes an auction after its end time has been reached

*This function can be called by anyone after the auction end time*


```solidity
function finalizeAuction(Auction storage auction) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`auction`|`Auction`|The storage pointer to the auction to be finalized|


### _finalizeAuction

Internal function to handle auction finalization logic

*This function distributes unsold tokens and marks the auction as finalized*


```solidity
function _finalizeAuction(Auction storage auction) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`auction`|`Auction`|The storage pointer to the auction to be finalized|


### _claimKickerReward

Claims the kicker reward for the auction

*Transfers the kicker reward to the kicker's address immediately upon auction creation*


```solidity
function _claimKickerReward(Auction memory auction) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`auction`|`Auction`|The auction to claim the kicker reward from|


## Structs
### AuctionConfig
Struct representing the configuration of a Dutch auction

*This struct contains all the fixed parameters set at auction creation*


```solidity
struct AuctionConfig {
    IERC20 auctionToken;
    IERC20 paymentToken;
    uint40 startTime;
    uint40 endTime;
    uint8 auctionTokenDecimals;
    uint8 paymentTokenDecimals;
    address auctionKicker;
    address unsoldTokensRecipient;
    uint40 id;
    DecayFunctions.DecayType decayType;
    uint256 startPrice;
    uint256 endPrice;
    uint256 totalTokens;
    uint256 kickerRewardAmount;
}
```

### AuctionState
Struct representing the dynamic state of a Dutch auction

*This struct contains all the variables that change during the auction's lifecycle*


```solidity
struct AuctionState {
    uint256 remainingTokens;
    bool isFinalized;
}
```

### Auction
Struct representing a complete Dutch auction

*This struct combines the fixed configuration and dynamic state of an auction*


```solidity
struct Auction {
    AuctionConfig config;
    AuctionState state;
}
```

### AuctionParams
Struct containing parameters for creating a new auction

*This struct is used as an input to the createAuction function*


```solidity
struct AuctionParams {
    uint256 auctionId;
    IERC20 auctionToken;
    IERC20 paymentToken;
    uint40 duration;
    uint256 startPrice;
    uint256 endPrice;
    uint256 totalTokens;
    Percentage kickerRewardPercentage;
    address kicker;
    address unsoldTokensRecipient;
    DecayFunctions.DecayType decayType;
}
```

