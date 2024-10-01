# IRaftErrors
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/0276900cbe9b1188d82d1b9bcbb8c174e79a15a1/src/errors/IRaftErrors.sol)

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

