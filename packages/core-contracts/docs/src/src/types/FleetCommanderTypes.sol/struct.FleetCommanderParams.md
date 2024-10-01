# FleetCommanderParams
[Git Source](https://github.com/OasisDEX/summer-earn-protocol/blob/0276900cbe9b1188d82d1b9bcbb8c174e79a15a1/src/types/FleetCommanderTypes.sol)

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

