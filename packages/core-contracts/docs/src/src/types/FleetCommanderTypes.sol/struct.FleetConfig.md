# FleetConfig
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/02b633fc64591288020c32f3fcb6421ab62209d5/src/types/FleetCommanderTypes.sol)

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

