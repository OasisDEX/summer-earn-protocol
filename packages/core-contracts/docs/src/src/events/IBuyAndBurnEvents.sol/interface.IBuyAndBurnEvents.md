# IBuyAndBurnEvents
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/events/IBuyAndBurnEvents.sol)

Interface for events emitted by the BuyAndBurn contract

*This interface defines the events that are emitted during the BuyAndBurn process*


## Events
### BuyAndBurnAuctionStarted
Emitted when a new BuyAndBurn auction is started


```solidity
event BuyAndBurnAuctionStarted(uint256 indexed auctionId, address indexed tokenToAuction, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`auctionId`|`uint256`|The unique identifier of the auction|
|`tokenToAuction`|`address`|The address of the token being auctioned|
|`amount`|`uint256`|The total amount of tokens being put up for auction|

### SummerBurned
Emitted when SUMMER tokens are burned as part of the BuyAndBurn process


```solidity
event SummerBurned(uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of SUMMER tokens that were burned|

