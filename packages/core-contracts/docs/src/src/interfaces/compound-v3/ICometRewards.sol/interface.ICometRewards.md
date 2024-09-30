# ICometRewards
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/interfaces/compound-v3/ICometRewards.sol)


## Functions
### claim

Claim rewards of token type from a comet instance to owner address


```solidity
function claim(address comet, address src, bool shouldAccrue) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`comet`|`address`|The protocol instance|
|`src`|`address`|The owner to claim for|
|`shouldAccrue`|`bool`|Whether or not to call accrue first|


