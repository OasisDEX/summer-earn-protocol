# ArkData
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/types/FleetCommanderTypes.sol)

*Struct to store information about an Ark.
This struct holds the address of the Ark and the total assets it holds.*

*used in the caching mechanism for the FleetCommander*


```solidity
struct ArkData {
    address arkAddress;
    uint256 totalAssets;
}
```

