# FleetCommanderParams
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/f5de2d90d66614e7bd59fd42a9d06b870fe474cd/src/types/FleetCommanderTypes.sol)

Configuration parameters for the FleetCommander contract


```solidity
struct FleetCommanderParams {
    string name;
    string symbol;
    address[] initialArks;
    address configurationManager;
    address accessManager;
    address asset;
    address bufferArk;
    uint256 initialMinimumBufferBalance;
    uint256 initialRebalanceCooldown;
    uint256 depositCap;
    Percentage initialTipRate;
}
```

