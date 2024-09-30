# IRewardsController
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/interfaces/aave-v3/IRewardsController.sol)

**Author:**
Aave

Defines the basic interface for a Rewards Controller.


## Functions
### claimRewardsToSelf

*Claims reward for msg.sender, on all the assets of the pool, accumulating the pending rewards*


```solidity
function claimRewardsToSelf(address[] calldata assets, uint256 amount, address reward) external returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`address[]`|The list of assets to check eligible distributions before claiming rewards|
|`amount`|`uint256`|The amount of rewards to claim|
|`reward`|`address`|The address of the reward token|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount of rewards claimed|


