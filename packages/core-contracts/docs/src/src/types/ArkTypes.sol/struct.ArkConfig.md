# ArkConfig
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/02b633fc64591288020c32f3fcb6421ab62209d5/src/types/ArkTypes.sol)

Configuration of the Ark contract

*This struct stores the current configuration of an Ark, which can be updated during its lifecycle*


```solidity
struct ArkConfig {
    address commander;
    address raft;
    IERC20 token;
    uint256 depositCap;
    uint256 maxRebalanceOutflow;
    uint256 maxRebalanceInflow;
    string name;
    bool requiresKeeperData;
}
```

