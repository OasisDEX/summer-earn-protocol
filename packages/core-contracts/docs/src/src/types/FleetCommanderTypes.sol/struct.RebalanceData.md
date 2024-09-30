# RebalanceData
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/types/FleetCommanderTypes.sol)

Data structure for the rebalance event

*if the `boardData` or `disembarkData` is not needed, it should be an empty byte array*


```solidity
struct RebalanceData {
    address fromArk;
    address toArk;
    uint256 amount;
    bytes boardData;
    bytes disembarkData;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`fromArk`|`address`|The address of the Ark from which assets are moved|
|`toArk`|`address`|The address of the Ark to which assets are moved|
|`amount`|`uint256`|The amount of assets being moved|
|`boardData`|`bytes`|The data to be passed to the `board` function of the `toArk`|
|`disembarkData`|`bytes`|The data to be passed to the `disembark` function of the `fromArk`|

