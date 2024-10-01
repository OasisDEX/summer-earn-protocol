# ICometRewards
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/0276900cbe9b1188d82d1b9bcbb8c174e79a15a1/src/interfaces/compound-v3/ICometRewards.sol)


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


