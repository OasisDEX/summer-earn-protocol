# IRaftErrors
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/02b633fc64591288020c32f3fcb6421ab62209d5/src/errors/IRaftErrors.sol)

These custom errors provide more gas-efficient and informative error handling
compared to traditional require statements with string messages.

*This file contains custom error definitions for the Raft contract.*


## Errors
### RaftAuctionAlreadyRunning
Thrown when attempting to start an auction for an Ark and reward token pair that already has an active
auction


```solidity
error RaftAuctionAlreadyRunning(address ark, address rewardToken);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ark`|`address`|The address of the Ark|
|`rewardToken`|`address`|The address of the reward token|

### RaftArkRequiresKeeperData
Thrown when attempting to board rewards to an Ark that does not require keeper data


```solidity
error RaftArkRequiresKeeperData(address ark);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ark`|`address`|The address of the Ark|

### RaftArkDoesntRequireKeeperData
Thrown when attempting to board rewards to an Ark that requires keeper data


```solidity
error RaftArkDoesntRequireKeeperData(address ark);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ark`|`address`|The address of the Ark|

