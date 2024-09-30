# ArkParams
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/0276900cbe9b1188d82d1b9bcbb8c174e79a15a1/src/types/ArkTypes.sol)

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

