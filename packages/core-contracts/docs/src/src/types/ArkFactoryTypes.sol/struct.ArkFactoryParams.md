# ArkFactoryParams
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/02b633fc64591288020c32f3fcb6421ab62209d5/src/types/ArkFactoryTypes.sol)

Configuration parameters for the ArkFactory contract

*Used to prevent stack too deep error*


```solidity
struct ArkFactoryParams {
    address governor;
    address raft;
    address aaveV3Pool;
}
```

