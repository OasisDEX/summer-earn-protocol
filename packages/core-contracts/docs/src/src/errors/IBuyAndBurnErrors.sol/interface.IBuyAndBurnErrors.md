# IBuyAndBurnErrors
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/errors/IBuyAndBurnErrors.sol)

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

