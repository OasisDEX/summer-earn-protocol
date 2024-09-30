# IBuyAndBurnErrors
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/02b633fc64591288020c32f3fcb6421ab62209d5/src/errors/IBuyAndBurnErrors.sol)

These custom errors provide more gas-efficient and informative error handling
compared to traditional require statements with string messages.

*This file contains custom error definitions for the BuyAndBurn contract.*


## Errors
### BuyAndBurnAuctionAlreadyRunning
Thrown when attempting to start a new auction for a token that already has an ongoing auction.


```solidity
error BuyAndBurnAuctionAlreadyRunning(address tokenToAuction);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenToAuction`|`address`|The address of the token for which an auction is already running.|

