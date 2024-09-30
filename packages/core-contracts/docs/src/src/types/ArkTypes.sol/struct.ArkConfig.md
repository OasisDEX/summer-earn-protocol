# ArkConfig
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/0276900cbe9b1188d82d1b9bcbb8c174e79a15a1/src/types/ArkTypes.sol)

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

