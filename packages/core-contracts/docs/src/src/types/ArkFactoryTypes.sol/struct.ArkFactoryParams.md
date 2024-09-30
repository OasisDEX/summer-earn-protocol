# ArkFactoryParams
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/types/ArkFactoryTypes.sol)

Configuration parameters for the ArkFactory contract

*Used to prevent stack too deep error*


```solidity
struct ArkFactoryParams {
    address governor;
    address raft;
    address aaveV3Pool;
}
```

