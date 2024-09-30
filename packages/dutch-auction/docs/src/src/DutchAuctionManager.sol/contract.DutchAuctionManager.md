# DutchAuctionManager
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/c6aec955808af03c05b24342f892f71facee60db/src/DutchAuctionManager.sol)

**Inherits:**
ReentrancyGuard, [DutchAuctionErrors](/src/DutchAuctionErrors.sol/contract.DutchAuctionErrors.md), [DutchAuctionEvents](/src/DutchAuctionEvents.sol/contract.DutchAuctionEvents.md)

**Author:**
Your Name

This contract manages multiple Dutch auctions using the DutchAuctionLibrary

*This contract is responsible for creating and managing auctions, and acts as the interface for users to interact
with auctions*


## State Variables
### auctions

```solidity
mapping(uint256 => DutchAuctionLibrary.Auction) public auctions;
```


### auctionCounter

```solidity
uint256 public auctionCounter;
```


## Functions
### createAuction

Creates a new Dutch auction

*This function creates a new auction and returns its unique identifier*


```solidity
function createAuction(
    IERC20 _auctionToken,
    IERC20 _paymentToken,
    uint256 _duration,
    uint256 _startPrice,
    uint256 _endPrice,
    uint256 _totalTokens,
    Percentage _kickerRewardPercentage,
    address _unsoldTokensRecipient,
    DecayFunctions.DecayType _decayType
)
    external
    nonReentrant
    returns (uint256 auctionId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_auctionToken`|`IERC20`|The address of the token being auctioned|
|`_paymentToken`|`IERC20`|The address of the token used for payment|
|`_duration`|`uint256`|The duration of the auction in seconds|
|`_startPrice`|`uint256`|The starting price of the auctioned token|
|`_endPrice`|`uint256`|The ending price of the auctioned token|
|`_totalTokens`|`uint256`|The total number of tokens being auctioned|
|`_kickerRewardPercentage`|`Percentage`|The percentage of sold tokens to be given as reward to the auction kicker|
|`_unsoldTokensRecipient`|`address`|The address to receive any unsold tokens at the end of the auction|
|`_decayType`|`DecayFunctions.DecayType`|The type of price decay function to use for the auction|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`auctionId`|`uint256`|The unique identifier of the created auction|


### getCurrentPrice

Gets the current price of tokens in an ongoing auction

*This function returns the current price based on the auction's decay function and elapsed time*


```solidity
function getCurrentPrice(uint256 _auctionId) public view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_auctionId`|`uint256`|The unique identifier of the auction|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current price of tokens in the auction|


### buyTokens

Allows a user to purchase tokens from an ongoing auction

*This function handles the token purchase, including price calculation and token transfers*


```solidity
function buyTokens(uint256 _auctionId, uint256 _amount) external nonReentrant returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_auctionId`|`uint256`|The unique identifier of the auction|
|`_amount`|`uint256`|The number of tokens to purchase|


### finalizeAuction

Finalizes an auction after its end time has been reached

*This function can be called by anyone after the auction end time*


```solidity
function finalizeAuction(uint256 _auctionId) external nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_auctionId`|`uint256`|The unique identifier of the auction to be finalized|


