# DutchAuctionEvents
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/c6aec955808af03c05b24342f892f71facee60db/src/DutchAuctionEvents.sol)


## Events
### AuctionCreated
*Emitted when a new auction is created*


```solidity
event AuctionCreated(
    uint256 indexed auctionId, address indexed auctionKicker, uint256 totalTokens, uint256 kickerRewardAmount
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`auctionId`|`uint256`|The unique identifier of the created auction|
|`auctionKicker`|`address`|The address of the account that initiated the auction|
|`totalTokens`|`uint256`|The total number of tokens being auctioned|
|`kickerRewardAmount`|`uint256`|The number of tokens reserved as a reward for the auction kicker|

### TokensPurchased
*Emitted when tokens are purchased in an auction*


```solidity
event TokensPurchased(uint256 indexed auctionId, address indexed buyer, uint256 amount, uint256 price);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`auctionId`|`uint256`|The unique identifier of the auction|
|`buyer`|`address`|The address of the account that purchased the tokens|
|`amount`|`uint256`|The number of tokens purchased|
|`price`|`uint256`|The price per token at the time of purchase|

### AuctionFinalized
*Emitted when an auction is finalized*


```solidity
event AuctionFinalized(uint256 indexed auctionId, uint256 soldTokens, uint256 unsoldTokens);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`auctionId`|`uint256`|The unique identifier of the finalized auction|
|`soldTokens`|`uint256`|The total number of tokens sold in the auction|
|`unsoldTokens`|`uint256`|The number of tokens that remained unsold|

### KickerRewardClaimed

```solidity
event KickerRewardClaimed(uint256 indexed auctionId, address indexed kicker, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`auctionId`|`uint256`|The unique identifier of the auction|
|`kicker`|`address`|The address of the account that initiated the auction|
|`amount`|`uint256`|The number of tokens claimed as a reward|

