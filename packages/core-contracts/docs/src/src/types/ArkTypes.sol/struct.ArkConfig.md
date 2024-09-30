# ArkConfig
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/types/ArkTypes.sol)

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

