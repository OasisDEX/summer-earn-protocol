# ArkData
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/02b633fc64591288020c32f3fcb6421ab62209d5/src/types/FleetCommanderTypes.sol)

*Struct to store information about an Ark.
This struct holds the address of the Ark and the total assets it holds.*

*used in the caching mechanism for the FleetCommander*


```solidity
struct ArkData {
    address arkAddress;
    uint256 totalAssets;
}
```

