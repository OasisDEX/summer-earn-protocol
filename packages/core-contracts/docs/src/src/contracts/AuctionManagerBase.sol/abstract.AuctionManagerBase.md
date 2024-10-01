# AuctionManagerBase
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/0276900cbe9b1188d82d1b9bcbb8c174e79a15a1/src/contracts/AuctionManagerBase.sol)

**Inherits:**
[IAuctionManagerBaseEvents](/src/events/IAuctionManagerBaseEvents.sol/interface.IAuctionManagerBaseEvents.md)

Base contract for managing Dutch auctions

*This abstract contract provides core functionality for creating and managing Dutch auctions*


## State Variables
### auctionDefaultParameters
Default parameters for all auctions


```solidity
AuctionDefaultParameters public auctionDefaultParameters;
```


### nextAuctionId
Counter for generating unique auction IDs - starts with 1


```solidity
uint256 public nextAuctionId;
```


## Functions
### constructor

Initializes the AuctionManagerBase with default parameters


```solidity
constructor(AuctionDefaultParameters memory _defaultParameters);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_defaultParameters`|`AuctionDefaultParameters`|The initial default parameters for auctions|


### _createAuction

Creates a new Dutch auction

*This function is internal and should be called by derived contracts*


```solidity
function _createAuction(
    IERC20 auctionToken,
    IERC20 paymentToken,
    uint256 totalTokens,
    address unsoldTokensRecipient
)
    internal
    returns (DutchAuctionLibrary.Auction memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`auctionToken`|`IERC20`|The token being auctioned|
|`paymentToken`|`IERC20`|The token used for payments|
|`totalTokens`|`uint256`|The total number of tokens to be auctioned|
|`unsoldTokensRecipient`|`address`|The address to receive any unsold tokens after the auction|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`DutchAuctionLibrary.Auction`|A new Auction struct|


### _updateAuctionDefaultParameters

Updates the default parameters for future auctions

*This function is internal and should be called by derived contracts*


```solidity
function _updateAuctionDefaultParameters(AuctionDefaultParameters calldata newParameters) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newParameters`|`AuctionDefaultParameters`|The new default parameters to set|


### _getCurrentPrice

Gets the current price of an ongoing auction

*This function is internal and should be called by derived contracts*


```solidity
function _getCurrentPrice(DutchAuctionLibrary.Auction storage auction) internal view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`auction`|`DutchAuctionLibrary.Auction`|The storage pointer to the auction|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current price of the auction in payment token decimals|


