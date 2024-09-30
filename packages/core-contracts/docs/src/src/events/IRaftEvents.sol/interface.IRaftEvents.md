# IRaftEvents
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/02b633fc64591288020c32f3fcb6421ab62209d5/src/events/IRaftEvents.sol)

Interface defining events emitted by the Raft contract


## Events
### ArkRewardTokenAuctionStarted
Emitted when a new auction is started for an Ark's reward token


```solidity
event ArkRewardTokenAuctionStarted(uint256 auctionId, address ark, address rewardToken, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`auctionId`|`uint256`|The unique identifier of the auction|
|`ark`|`address`|The address of the Ark contract|
|`rewardToken`|`address`|The address of the reward token being auctioned|
|`amount`|`uint256`|The amount of tokens being auctioned|

### ArkHarvested
Emitted when rewards are harvested from an Ark


```solidity
event ArkHarvested(address indexed ark, address[] indexed rewardTokens, uint256[] indexed rewardAmounts);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ark`|`address`|The address of the Ark contract|
|`rewardTokens`|`address[]`|The addresses of the harvested reward tokens|
|`rewardAmounts`|`uint256[]`|The amounts of the harvested reward tokens|

### RewardBoarded
Emitted when auctioned rewards are boarded back into an Ark


```solidity
event RewardBoarded(
    address indexed ark, address indexed fromRewardToken, address indexed toFleetToken, uint256 amountReboarded
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ark`|`address`|The address of the Ark contract|
|`fromRewardToken`|`address`|The address of the original reward token|
|`toFleetToken`|`address`|The address of the token boarded into the Ark|
|`amountReboarded`|`uint256`|The amount of tokens reboarded|

