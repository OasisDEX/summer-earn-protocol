# IBuyAndBurn
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/0276900cbe9b1188d82d1b9bcbb8c174e79a15a1/src/interfaces/IBuyAndBurn.sol)

**Inherits:**
[IBuyAndBurnEvents](/src/events/IBuyAndBurnEvents.sol/interface.IBuyAndBurnEvents.md), [IBuyAndBurnErrors](/src/errors/IBuyAndBurnErrors.sol/interface.IBuyAndBurnErrors.md)

Interface for the BuyAndBurn contract, which manages token auctions and burns SUMMER tokens


## Functions
### startAuction

Starts a new auction for a specified token

*Only callable by the governor*

*Emits a BuyAndBurnAuctionStarted event*


```solidity
function startAuction(address tokenToAuction) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenToAuction`|`address`|The address of the token to be auctioned|


### buyTokens

Allows users to buy tokens from an ongoing auction

*Emits a TokensPurchased event*


```solidity
function buyTokens(uint256 auctionId, uint256 amount) external returns (uint256 summerAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`auctionId`|`uint256`|The ID of the auction|
|`amount`|`uint256`|The amount of tokens to buy|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`summerAmount`|`uint256`|The amount of SUMMER tokens required to purchase the specified amount of auction tokens|


### finalizeAuction

Finalizes an auction after its end time

*Only callable by the governor*

*Emits a SummerBurned event*


```solidity
function finalizeAuction(uint256 auctionId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`auctionId`|`uint256`|The ID of the auction to finalize|


### getAuctionInfo

Retrieves information about a specific auction


```solidity
function getAuctionInfo(uint256 auctionId) external view returns (DutchAuctionLibrary.Auction memory auction);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`auctionId`|`uint256`|The ID of the auction|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`auction`|`DutchAuctionLibrary.Auction`|The Auction struct containing auction details|


### getCurrentPrice

Gets the current price of tokens in an ongoing auction


```solidity
function getCurrentPrice(uint256 auctionId) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`auctionId`|`uint256`|The ID of the auction|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current price of tokens in the auction|


### updateAuctionDefaultParameters

Updates the default parameters for future auctions

*Only callable by the governor*

*Emits an AuctionDefaultParametersUpdated event*


```solidity
function updateAuctionDefaultParameters(AuctionDefaultParameters calldata newParameters) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newParameters`|`AuctionDefaultParameters`|The new default parameters|


