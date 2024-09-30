# FleetConfig
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/0276900cbe9b1188d82d1b9bcbb8c174e79a15a1/src/types/FleetCommanderTypes.sol)

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

