# ArkFactoryParams
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/0276900cbe9b1188d82d1b9bcbb8c174e79a15a1/src/types/ArkFactoryTypes.sol)

Configuration parameters for the ArkFactory contract

*Used to prevent stack too deep error*


```solidity
struct ArkFactoryParams {
    address governor;
    address raft;
    address aaveV3Pool;
}
```

