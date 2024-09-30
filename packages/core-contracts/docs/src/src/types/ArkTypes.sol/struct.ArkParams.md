# ArkParams
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/types/ArkTypes.sol)

Constructor parameters for the Ark contract

*This struct is used to initialize an Ark contract with all necessary parameters*


```solidity
struct ArkParams {
    string name;
    address accessManager;
    address configurationManager;
    address token;
    uint256 depositCap;
    uint256 maxRebalanceOutflow;
    uint256 maxRebalanceInflow;
    bool requiresKeeperData;
}
```

