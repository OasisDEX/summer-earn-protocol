# ArkData
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/0276900cbe9b1188d82d1b9bcbb8c174e79a15a1/src/types/FleetCommanderTypes.sol)

*Struct to store information about an Ark.
This struct holds the address of the Ark and the total assets it holds.*

*used in the caching mechanism for the FleetCommander*


```solidity
struct ArkData {
    address arkAddress;
    uint256 totalAssets;
}
```

