# ArkParams
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/02b633fc64591288020c32f3fcb6421ab62209d5/src/types/ArkTypes.sol)

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

