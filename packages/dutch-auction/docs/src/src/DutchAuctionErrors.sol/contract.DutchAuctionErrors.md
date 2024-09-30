# DutchAuctionErrors
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/c6aec955808af03c05b24342f892f71facee60db/src/DutchAuctionErrors.sol)

This contract defines custom errors for the Dutch Auction system


## Errors
### InvalidDuration
Thrown when the auction duration is set to zero

*The auction duration must be greater than zero*


```solidity
error InvalidDuration();
```

### InvalidPrices
Thrown when the start price is not greater than the end price

*The start price must be strictly greater than the end price*


```solidity
error InvalidPrices();
```

### InvalidTokenAmount
Thrown when the total number of tokens for auction is zero

*The total token amount must be greater than zero*


```solidity
error InvalidTokenAmount();
```

### InvalidKickerRewardPercentage
Thrown when the kicker reward percentage is greater than 100%

*The kicker reward percentage must be between 0 and 100 inclusive*


```solidity
error InvalidKickerRewardPercentage();
```

### AuctionNotActive
Thrown when trying to buy tokens outside the active auction period

*This can occur if trying to buy after the auction has ended*


```solidity
error AuctionNotActive(uint256 auctionId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`auctionId`|`uint256`|The ID of the auction being interacted with|

### InsufficientTokensAvailable
Thrown when trying to buy more tokens than are available in the auction

*The requested purchase amount must not exceed the remaining tokens*


```solidity
error InsufficientTokensAvailable();
```

### AuctionNotEnded
Thrown when trying to finalize an auction before its end time

*The auction can only be finalized after its scheduled end time*


```solidity
error AuctionNotEnded(uint256 auctionId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`auctionId`|`uint256`|The ID of the auction being interacted with|

### AuctionAlreadyFinalized
Thrown when trying to interact with an auction that has already been finalized

*Once an auction is finalized, no further interactions should be possible*

*auction is finalized when either the end time is reached or all tokens are sold*


```solidity
error AuctionAlreadyFinalized(uint256 auctionId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`auctionId`|`uint256`|The ID of the auction being interacted with|

### InvalidAuctionToken
Thrown when the auction token is invalid


```solidity
error InvalidAuctionToken();
```

### InvalidPaymentToken
Thrown when the payment token is invalid


```solidity
error InvalidPaymentToken();
```

### AuctionNotFound
Thrown when the auction has not been found


```solidity
error AuctionNotFound();
```

