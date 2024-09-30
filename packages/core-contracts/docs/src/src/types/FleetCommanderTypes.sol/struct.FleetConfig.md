# FleetConfig
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/types/FleetCommanderTypes.sol)

Configuration parameters for the FleetCommander contract

*This struct encapsulates the mutable configuration settings of a FleetCommander.
These parameters can be updated during the contract's lifecycle to adjust its behavior.*


```solidity
struct FleetConfig {
    IArk bufferArk;
    uint256 minimumBufferBalance;
    uint256 depositCap;
    uint256 maxRebalanceOperations;
}
```

